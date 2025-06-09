import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'mypage.dart'; // MyPageState 접근을 위해
import 'main.dart';
import 'package:provider/provider.dart'; 

class TimerProvider extends ChangeNotifier {
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _timer;
  Duration _elapsed = Duration.zero;
  Duration _lastElapsed = Duration.zero;

  TimerProvider() {
    restoreTimerState();
  }

  bool get isRunning => _stopwatch.isRunning;
  Duration get elapsed => _elapsed;

  String get formattedTime {
    final h = _elapsed.inHours.toString().padLeft(2, '0');
    final m = (_elapsed.inMinutes % 60).toString().padLeft(2, '0');
    final s = (_elapsed.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  void start() async {
    if (_stopwatch.isRunning) return;

    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    prefs.setString('sessionStart', now.toIso8601String());
    prefs.setInt('elapsedBefore', _lastElapsed.inMinutes);
    prefs.setString('sessionDate', now.toIso8601String().split('T')[0]);

    _stopwatch.start();
    print('타이머 시작됨: ${_stopwatch.elapsed}'); // 타이머 시작 직후 출력

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _elapsed = _stopwatch.elapsed + _lastElapsed;
      print('진행 시간: $_elapsed'); // 매 초마다 출력
      notifyListeners();
    });

    notifyListeners();
  }

  Future<void> restoreTimerState() async {
    final prefs = await SharedPreferences.getInstance();
    final sessionStartStr = prefs.getString('sessionStart');
    final sessionDate = prefs.getString('sessionDate');
    final elapsedBefore = prefs.getInt('elapsedBefore') ?? 0;

    final todayStr = DateTime.now().toIso8601String().split('T')[0];

    if (sessionDate != null && sessionDate != todayStr) {
      print('🗕️ 날짜 변경 감지! 전날 공백시간 저장 및 리셋');

      await saveStudyTimeToServer(
        DateTime.parse(sessionDate),
        elapsedBefore,
      );
      reset();
      prefs.remove('sessionStart');
      prefs.remove('sessionDate');
      prefs.remove('elapsedBefore');
      return;
    }

    if (sessionStartStr != null) {
      final startTime = DateTime.parse(sessionStartStr);
      final now = DateTime.now();
      final diff = now.difference(startTime);

      _lastElapsed = Duration(minutes: elapsedBefore);
      _elapsed = _lastElapsed; 

      notifyListeners();
      print('이전 타이머 복원됨 (멈춘 상태): $_elapsed');
    }
  }

  Map<String, Duration> weeklyStudy = {
    '월': Duration.zero,
    '화': Duration.zero,
    '수': Duration.zero,
    '목': Duration.zero,
    '금': Duration.zero,
    '토': Duration.zero,
    '일': Duration.zero,
  };

  Future<void> pause() async {
    print('pause 함수 진입');
    _stopwatch.stop();
    _timer?.cancel();

    final now = DateTime.now();
    final today = ['월', '화', '수', '목', '금', '토', '일'][now.weekday - 1];

    // stopwatch 리셋 전에 누적 먼저 처리
    weeklyStudy[today] = (weeklyStudy[today] ?? Duration.zero) + _stopwatch.elapsed;

    _lastElapsed += _stopwatch.elapsed;
    _stopwatch.reset(); // 이 시점에 리셋해야 누적 계산이 정확
    _elapsed = _lastElapsed;

    final totalSeconds = weeklyStudy[today]!.inSeconds;
    final roundedMinutes = (totalSeconds / 60).round();

    print('청 누적 초: $totalSeconds');
    print('저장할 분(반올림): $roundedMinutes');

    await saveStudyTimeToServer(now, roundedMinutes);

    final prefs = await SharedPreferences.getInstance();
    prefs.setInt('elapsedBefore', _lastElapsed.inMinutes);  // _elapsed 말고 _lastElapsed 저장

    BuildContext? context = navigatorKey.currentContext;
    if (context != null) {
      final homeState = context.findAncestorStateOfType<HomePageState>();
      homeState?.refreshTodayStudyTime();

      final myPageState = context.findAncestorStateOfType<MyPageState>();
      myPageState?.refreshActualStudyTimeFromOutside();

      // 도넛 그래프용 TimerProvider 값도 갱신
      final timerProvider = Provider.of<TimerProvider>(context, listen: false);
      await timerProvider.loadWeeklyStudyFromServer();
    }

    notifyListeners();
  }



  Future<void> saveStudyTimeToServer(DateTime studyDate, int totalMinutes) async {
    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString('accessToken');
    if (accessToken == null) {
      print('저장 실패: accessToken 없음');
      return;
    }

    final studyDateStr = studyDate.toIso8601String().split('T')[0];
    print('서버로 보낼 데이터: $studyDateStr, $totalMinutes');

    final response = await http.post(
      Uri.parse('http://localhost:8000/timer/'),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'study_date': studyDateStr,
        'total_minutes': totalMinutes,
      }),
    );

    print('서버 응답 상태: ${response.statusCode}');
    print('응답 내용: ${response.body}');
  }




  Future<void> loadWeeklyStudyFromServer({int weekOffset = 0}) async {
    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString('accessToken');
    if (accessToken == null) return;

    final url = Uri.parse('http://localhost:8000/timer/weekly-by-day?week_offset=$weekOffset');

    final response = await http.get(
      url,
      headers: {
        'Authorization': 'Bearer $accessToken',
      },
    );

    if (response.statusCode == 200) {
      final decodedBody = utf8.decode(response.bodyBytes);
      final data = jsonDecode(decodedBody);
      print("서버 응답 데이터: $data");

      final dayMap = {
        'mon': '월',
        'tue': '화',
        'wed': '수',
        'thu': '목',
        'fri': '금',
        'sat': '토',
        'sun': '일',
        '월': '월',
        '화': '화',
        '수': '수',
        '목': '목',
        '금': '금',
        '토': '토',
        '일': '일',
      };

      weeklyStudy.clear();
      for (final entry in data.entries) {
        final day = dayMap[entry.key.toLowerCase()];
        if (day != null) {
          weeklyStudy[day] = Duration(minutes: entry.value);
        }
      }

      notifyListeners();
    } else {
      print('서버에서 실제 공백시간 불러오기 실패: ${response.body}');
    }
  }

  void reset() {
    _stopwatch.reset();
    _elapsed = Duration.zero;
    _lastElapsed = Duration.zero;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _stopwatch.stop();
    super.dispose();
  }
}