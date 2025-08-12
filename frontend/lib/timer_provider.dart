
import 'env.dart'; 
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'mypage.dart';
import 'main.dart';
import 'package:provider/provider.dart'; 
import 'package:capstone_edu_app/study_session.dart';

class TimerProvider extends ChangeNotifier {
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _timer;

  List<Map<String, dynamic>> _studySessions = [];
  List<StudySession> _sessionList = [];
  List<StudySession> get sessionList => _sessionList;

  DateTime? _sessionStartTime;
  DateTime? _sessionEndTime;
  Duration _elapsed = Duration.zero;
  Duration _lastElapsed = Duration.zero;
  bool _hasPaused = false;

  Map<String, Duration> weeklyStudy = {
    '월': Duration.zero, '화': Duration.zero, '수': Duration.zero,
    '목': Duration.zero, '금': Duration.zero, '토': Duration.zero, '일': Duration.zero,
  };

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
    final now = DateTime.now().toLocal();

    // ✅ 첫 시작일 때만 _lastElapsed 초기화
    if (!_hasPaused) {
      _lastElapsed = Duration.zero;
      _sessionStartTime = now;
      prefs.setString('sessionStart', now.toIso8601String());
      prefs.setInt('elapsedBefore', _lastElapsed.inMinutes);
      prefs.setString('sessionDate', now.toIso8601String().split('T')[0]);
    }

    _hasPaused = false;

    _stopwatch.start();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _elapsed = _stopwatch.elapsed + _lastElapsed;
      notifyListeners();
    });

    notifyListeners();
  }

  void pause() {
    if (!_stopwatch.isRunning) return;

    _stopwatch.stop();
    _timer?.cancel();

    _lastElapsed += _stopwatch.elapsed;
    _elapsed = _lastElapsed;
    _stopwatch.reset();

    _hasPaused = true;
    notifyListeners();
  }

  void stopAndSave() async {
    final now = DateTime.now().toLocal();
    _sessionEndTime = now;

    if (_stopwatch.isRunning) {
      _stopwatch.stop();
      _timer?.cancel();
      _lastElapsed += _stopwatch.elapsed;
    }

    final totalDuration = _hasPaused ? _elapsed : _stopwatch.elapsed + _lastElapsed;
    final sessionMinutes = (totalDuration.inSeconds / 60).round();

    if (totalDuration.inSeconds < 5) {
      reset();
      return;
    }

    final today = ['월', '화', '수', '목', '금', '토', '일'][now.weekday - 1];
    weeklyStudy[today] = (weeklyStudy[today] ?? Duration.zero) + totalDuration;

    _studySessions.add({
      'study_date': now.toIso8601String().split('T')[0],
      'total_minutes': sessionMinutes,
      'start_time': _sessionStartTime?.toIso8601String(),
      'end_time': _sessionEndTime?.toIso8601String(),
    });

    await saveStudySessionsToServer();
    await fetchSessionsByDate(now);

    final prefs = await SharedPreferences.getInstance();
    prefs.setInt('elapsedBefore', _lastElapsed.inMinutes);

    reset();
    notifyListeners();
  }

  void reset() {
    _stopwatch.reset();
    _elapsed = Duration.zero;
    _lastElapsed = Duration.zero;
    _hasPaused = false;
    notifyListeners();
  }

  Future<void> restoreTimerState() async {
    final prefs = await SharedPreferences.getInstance();
    final sessionDate = prefs.getString('sessionDate');
    final elapsedBefore = prefs.getInt('elapsedBefore') ?? 0;
    final todayStr = DateTime.now().toLocal().toIso8601String().split('T')[0];

    if (sessionDate != null && sessionDate != todayStr) {
      _studySessions.add({
        'study_date': sessionDate,
        'total_minutes': elapsedBefore,
        'start_time': DateTime.parse(sessionDate).toIso8601String(),
        'end_time': DateTime.parse(sessionDate).toIso8601String(),
      });

      await saveStudySessionsToServer();
      reset();
      prefs.remove('sessionStart');
      prefs.remove('sessionDate');
      prefs.remove('elapsedBefore');
    }
  }

  Future<void> saveStudySessionsToServer() async {
    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString('accessToken');
    if (accessToken == null) return;

    for (var session in _studySessions) {
      await http.post(
        Uri.parse('${Env.baseUrl}/timer/'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(session),
      );
    }
    _studySessions.clear();
  }

  Future<void> fetchSessionsByDate(DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString('accessToken');
    if (accessToken == null) return;

    final dateStr = date.toIso8601String().split('T')[0];

    final response = await http.get(
      Uri.parse('${Env.baseUrl}/timer/sessions/$dateStr'),
      headers: {
        'Authorization': 'Bearer $accessToken',
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
      _sessionList = data.map((e) => StudySession.fromJson(e)).toList();
      notifyListeners();
    }
  }

  Future<void> loadWeeklyStudyFromServer({int weekOffset = 0}) async {
    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString('accessToken');
    if (accessToken == null) return;

    final url = Uri.parse('${Env.baseUrl}/timer/weekly-by-day?week_offset=$weekOffset');

    final response = await http.get(url, headers: {
      'Authorization': 'Bearer $accessToken',
    });

    if (response.statusCode == 200) {
      final decodedBody = utf8.decode(response.bodyBytes);
      final data = jsonDecode(decodedBody);

      final dayMap = {
        'mon': '월', 'tue': '화', 'wed': '수', 'thu': '목',
        'fri': '금', 'sat': '토', 'sun': '일',
        '월': '월', '화': '화', '수': '수', '목': '목',
        '금': '금', '토': '토', '일': '일',
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
  }

  void removeSessionAt(int index) {
    final removed = _sessionList.removeAt(index);
    notifyListeners();
    deleteSessionFromServer(removed.id);
  }

  Future<void> deleteSessionFromServer(int timerId) async {
    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString('accessToken');
    if (accessToken == null) return;

    final response = await http.delete(
      Uri.parse('${Env.baseUrl}/timer/$timerId'),
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    if (response.statusCode == 200) {
      print('✅ 서버 세션 삭제 완료 (id=$timerId)');
    } else {
      print('❌ 서버 세션 삭제 실패: ${response.statusCode} - ${response.body}');
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _stopwatch.stop();
    super.dispose();
  }
}



// import 'dart:async';
// import 'package:flutter/material.dart';
// import 'package:http/http.dart' as http;
// import 'package:shared_preferences/shared_preferences.dart';
// import 'dart:convert';
// import 'mypage.dart'; // MyPageState 접근을 위해
// import 'main.dart';
// import 'package:provider/provider.dart'; 
// import 'package:capstone_edu_app/study_session.dart';


// class TimerProvider extends ChangeNotifier {
//   final Stopwatch _stopwatch = Stopwatch();
//   Timer? _timer;
//   List<Map<String, dynamic>> _studySessions = [];//25.7.3 공부 타임 세션 여러개 저장을 위해 추가.

//   List<StudySession> _sessionList = []; //_studySessions는 로컬 저장할 세션, _sessionList는 서버에서 불러온 날짜별 기록
//   List<StudySession> get sessionList => _sessionList;


//   DateTime? _sessionStartTime; //25.7.2. 타이머 시작 시간대 저장 위해서 추가.
//   DateTime? _sessionEndTime; //25.7.2. 타이머 종료 시간대 저장 위해서 추가.
//   Duration _elapsed = Duration.zero;
//   Duration _lastElapsed = Duration.zero;

//   TimerProvider() {
//     restoreTimerState();
//   }

//   bool get isRunning => _stopwatch.isRunning;
//   Duration get elapsed => _elapsed;

//   String get formattedTime {
//     final h = _elapsed.inHours.toString().padLeft(2, '0');
//     final m = (_elapsed.inMinutes % 60).toString().padLeft(2, '0');
//     final s = (_elapsed.inSeconds % 60).toString().padLeft(2, '0');
//     return '$h:$m:$s';
//   }



//   void start() async {
//     if (_stopwatch.isRunning) return;

//     final prefs = await SharedPreferences.getInstance();
//     final now = DateTime.now().toLocal();;

//     _sessionStartTime = now;

//     prefs.setString('sessionStart', now.toLocal().toIso8601String());
//     prefs.setInt('elapsedBefore', _lastElapsed.inMinutes);
//     prefs.setString('sessionDate', now.toLocal().toIso8601String().split('T')[0]);

//     _stopwatch.start();
//     print('타이머 시작됨: ${_stopwatch.elapsed}');

//     _timer = Timer.periodic(const Duration(seconds: 1), (_) {
//       _elapsed = _stopwatch.elapsed + _lastElapsed;
//       print('진행 시간: $_elapsed');
//       notifyListeners();
//     });

//     notifyListeners();
//   }


// // 프론트엔드에서 전의 공부시간 안 불러오는 문제.
//   Future<void> restoreTimerState() async {
//     final prefs = await SharedPreferences.getInstance();
//     final sessionStartStr = prefs.getString('sessionStart');
//     final sessionDate = prefs.getString('sessionDate');
//     final elapsedBefore = prefs.getInt('elapsedBefore') ?? 0;

//     final todayStr = DateTime.now().toLocal().toIso8601String().split('T')[0];

//     // 1. 날짜 변경 시 서버 저장 후 초기화
//     if (sessionDate != null && sessionDate != todayStr) {
//       print('🗕️ 날짜 변경 감지! 전날 공백시간 저장 및 리셋');

//       _studySessions.add({
//         'study_date': sessionDate,
//         'total_minutes': elapsedBefore,
//         'start_time': DateTime.parse(sessionDate).toIso8601String(),
//         'end_time': DateTime.parse(sessionDate).toIso8601String(),
//       });

//       await saveStudySessionsToServer();

//       reset();
//       prefs.remove('sessionStart');
//       prefs.remove('sessionDate');
//       prefs.remove('elapsedBefore');
//       return;
//     }

//     // 2. 오늘의 누적 시간 서버에서 불러오기
//     final accessToken = prefs.getString('accessToken');
//     if (accessToken != null) {
//       final response = await http.get(
//         Uri.parse('${Env.baseUrl}/timer/today'),
//         headers: {
//           'Authorization': 'Bearer $accessToken',
//         },
//       );

//       if (response.statusCode == 200) {
//         final data = json.decode(utf8.decode(response.bodyBytes));
//         final todayMinutes = data['today_minutes'] ?? 0;
//         _lastElapsed = Duration(minutes: todayMinutes);
//         _elapsed = _lastElapsed;
//         print('서버에서 누적 시간 로드됨: $_lastElapsed');
//       } else {
//         print('서버 누적 시간 로딩 실패: ${response.body}');
//       }
//     }

//     // 3. 세션 기록이 있으면 복원 (정지 상태 유지)
//     if (sessionStartStr != null) {
//       final startTime = DateTime.parse(sessionStartStr);
//       final now = DateTime.now().toLocal();
//       final diff = now.difference(startTime);

//       _elapsed = _lastElapsed;  // 이 시점에서 elapsed는 DB+로컬 값
//       notifyListeners();
//       print('이전 타이머 복원됨 (멈춘 상태): $_elapsed');
//     }

//     notifyListeners();
//   }


//   Map<String, Duration> weeklyStudy = {
//     '월': Duration.zero,
//     '화': Duration.zero,
//     '수': Duration.zero,
//     '목': Duration.zero,
//     '금': Duration.zero,
//     '토': Duration.zero,
//     '일': Duration.zero,
//   };


//   void pause() async {
//     print('pause 함수 진입');
//     _stopwatch.stop();

//     _sessionEndTime = DateTime.now().toLocal();
//     _timer?.cancel();

//     final now = DateTime.now().toLocal();
//     final today = ['월', '화', '수', '목', '금', '토', '일'][now.weekday - 1];

//     weeklyStudy[today] =
//         (weeklyStudy[today] ?? Duration.zero) + _stopwatch.elapsed;

//     _lastElapsed += _stopwatch.elapsed;
//     _stopwatch.reset();
//     _elapsed = _lastElapsed;

//     // 세션 길이 계산 후 리스트에 추가
//     if (_sessionStartTime != null && _sessionEndTime != null) {
//       final sessionMinutes =
//           ((_sessionEndTime!.difference(_sessionStartTime!).inSeconds) / 60).round();

//       _studySessions.add({
//         'study_date': now.toIso8601String().split('T')[0],
//         'total_minutes': sessionMinutes,
//         'start_time': _sessionStartTime!.toLocal().toIso8601String(),
//         'end_time': _sessionEndTime!.toLocal().toIso8601String(),
//       });

//       print('세션 추가됨: ${_studySessions.last}');
//     }

//     // 기존 누적 시간 저장 및 서버 동기화
//     await saveStudySessionsToServer(); // 수정 예정

//     final prefs = await SharedPreferences.getInstance();
//     prefs.setInt('elapsedBefore', _lastElapsed.inMinutes);

//     BuildContext? context = navigatorKey.currentContext;
//     if (context != null) {
//       final homeState = context.findAncestorStateOfType<HomePageState>();
//       homeState?.refreshTodayStudyTime();

//       final myPageState = context.findAncestorStateOfType<MyPageState>();
//       myPageState?.refreshActualStudyTimeFromOutside();

//       final timerProvider = Provider.of<TimerProvider>(context, listen: false);
//       await timerProvider.loadWeeklyStudyFromServer();
      
//     }

//     await fetchSessionsByDate(DateTime.now());

//     notifyListeners();
//   }



//   Future<void> saveStudySessionsToServer() async {
//     final prefs = await SharedPreferences.getInstance();
//     final accessToken = prefs.getString('accessToken');
//     if (accessToken == null) {
//       print('저장 실패: accessToken 없음');
//       return;
//     }

//     for (var session in _studySessions) {
//       print('서버로 보낼 세션: $session');

//       final response = await http.post(
//         Uri.parse('${Env.baseUrl}/timer/'),
//         headers: {
//           'Authorization': 'Bearer $accessToken',
//           'Content-Type': 'application/json',
//         },
//         body: jsonEncode(session),
//       );

//       print('서버 응답 상태: ${response.statusCode}');
//       print('응답 내용: ${response.body}');
//     }

//     // 전송 후 리스트 비우기
//     _studySessions.clear();
//   }



//   Future<void> loadWeeklyStudyFromServer({int weekOffset = 0}) async {
//     final prefs = await SharedPreferences.getInstance();
//     final accessToken = prefs.getString('accessToken');
//     if (accessToken == null) return;

//     final url = Uri.parse('${Env.baseUrl}/timer/weekly-by-day?week_offset=$weekOffset');

//     final response = await http.get(
//       url,
//       headers: {
//         'Authorization': 'Bearer $accessToken',
//       },
//     );

//     if (response.statusCode == 200) {
//       final decodedBody = utf8.decode(response.bodyBytes);
//       final data = jsonDecode(decodedBody);
//       print("서버 응답 데이터: $data");

//       final dayMap = {
//         'mon': '월',
//         'tue': '화',
//         'wed': '수',
//         'thu': '목',
//         'fri': '금',
//         'sat': '토',
//         'sun': '일',
//         '월': '월',
//         '화': '화',
//         '수': '수',
//         '목': '목',
//         '금': '금',
//         '토': '토',
//         '일': '일',
//       };

//       weeklyStudy.clear();
//       for (final entry in data.entries) {
//         final day = dayMap[entry.key.toLowerCase()];
//         if (day != null) {
//           weeklyStudy[day] = Duration(minutes: entry.value);
//         }
//       }

//       notifyListeners();
//     } else {
//       print('서버에서 실제 공백시간 불러오기 실패: ${response.body}');
//     }
//   }

//   // 날짜를 기준으로 모든 세션을 백엔드에서 불러와 _sessionList에 저장
//   Future<void> fetchSessionsByDate(DateTime date) async {
//     final prefs = await SharedPreferences.getInstance();
//     final accessToken = prefs.getString('accessToken');
//     if (accessToken == null) return;

//     final dateStr = date.toIso8601String().split('T')[0];

//     final response = await http.get(
//       Uri.parse('${Env.baseUrl}/timer/sessions/$dateStr'),
//       headers: {
//         'Authorization': 'Bearer $accessToken',
//       },
//     );

//     if (response.statusCode == 200) {
//       final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
//       _sessionList = data.map((e) => StudySession.fromJson(e)).toList();
//       print('$dateStr 세션 불러오기 완료: ${_sessionList.length}개');
//       notifyListeners();
//     } else {
//       print('세션 불러오기 실패: ${response.body}');
//     }
//   }

//   void reset() {
//     _stopwatch.reset();
//     _elapsed = Duration.zero;
//     _lastElapsed = Duration.zero;
//     notifyListeners();
//   }

//   @override
//   void dispose() {
//     _timer?.cancel();
//     _stopwatch.stop();
//     super.dispose();
//   }
// }