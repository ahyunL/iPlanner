import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'mypage.dart'; // MyPageState 접근을 위해
import 'main.dart';

class TimerProvider extends ChangeNotifier {
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _timer;
  Duration _elapsed = Duration.zero;
  Duration _lastElapsed = Duration.zero;

  bool get isRunning => _stopwatch.isRunning;
  Duration get elapsed => _elapsed;

  String get formattedTime {
    final h = _elapsed.inHours.toString().padLeft(2, '0');
    final m = (_elapsed.inMinutes % 60).toString().padLeft(2, '0');
    final s = (_elapsed.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  void start() {
    if (_stopwatch.isRunning) return;

    _stopwatch.start();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _elapsed = _stopwatch.elapsed;
      notifyListeners();
    });
    notifyListeners();
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
    _stopwatch.stop();
    _timer?.cancel();

    final now = DateTime.now();
    final today = ['월', '화', '수', '목', '금', '토', '일'][now.weekday - 1];

    final sessionDuration = _stopwatch.elapsed - _lastElapsed;
    weeklyStudy[today] = (weeklyStudy[today] ?? Duration.zero) + sessionDuration;
    _lastElapsed = _stopwatch.elapsed;

    final totalSeconds = weeklyStudy[today]!.inSeconds;
    final roundedMinutes = (totalSeconds / 60).round();

    print('⏱️ 총 누적 초: $totalSeconds');
    print('📊 저장할 분(반올림): $roundedMinutes');

    await saveStudyTimeToServer(now, roundedMinutes);

    BuildContext? context = navigatorKey.currentContext;
    if (context != null) {
      final homeState = context.findAncestorStateOfType<HomePageState>();
      homeState?.refreshTodayStudyTime();

      final myPageState = context.findAncestorStateOfType<MyPageState>();
      myPageState?.refreshActualStudyTimeFromOutside();
    }

    notifyListeners();
  }

  Future<void> saveStudyTimeToServer(DateTime studyDate, int totalMinutes) async {
    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString('accessToken');
    if (accessToken == null) return;

    final response = await http.post(
      Uri.parse('http://192.168.35.189:8000/timer/'),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'study_date': studyDate.toIso8601String().split('T')[0],
        'total_minutes': totalMinutes,
      }),
    );

    if (response.statusCode == 200) {
      print('✅ 공부 시간 저장 성공');
    } else {
      print('❌ 공부 시간 저장 실패: ${response.body}');
    }
  }

  Future<void> loadWeeklyStudyFromServer({int weekOffset = 0}) async {
  final prefs = await SharedPreferences.getInstance();
  final accessToken = prefs.getString('accessToken');
  if (accessToken == null) return;

  final url = Uri.parse('http://192.168.35.189:8000/timer/weekly-by-day?week_offset=$weekOffset');

  final response = await http.get(
    url,
    headers: {
      'Authorization': 'Bearer $accessToken',
    },
  );

  if (response.statusCode == 200) {
  final decodedBody = utf8.decode(response.bodyBytes);
  final data = jsonDecode(decodedBody);
  print("🔥 서버 응답 데이터: $data");

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
}
else {
    print('❌ 서버에서 실제 공부시간 불러오기 실패: ${response.body}');
  }
}


  void reset() {
    _stopwatch.reset();
    _elapsed = Duration.zero;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _stopwatch.stop();
    super.dispose();
  }
}
