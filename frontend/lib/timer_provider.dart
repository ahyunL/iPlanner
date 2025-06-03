import 'dart:async';
import 'package:flutter/material.dart';

class TimerProvider extends ChangeNotifier {
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _timer;
  Duration _elapsed = Duration.zero;
  Duration _lastElapsed = Duration.zero; // ✅ 이전 누적 시간 저장

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

  void pause() {
    _stopwatch.stop();
    _timer?.cancel();
    
    final now = DateTime.now();
    final today = ['월', '화', '수', '목', '금', '토', '일'][now.weekday - 1];
    
    final sessionDuration = _stopwatch.elapsed - _lastElapsed; // ✅ 이번 세션 시간만
    weeklyStudy[today] = (weeklyStudy[today] ?? Duration.zero) + sessionDuration;

    _lastElapsed = _stopwatch.elapsed; // ✅ 다음 pause 때 기준이 됨

    notifyListeners();
  }

  void reset() {
    _stopwatch.reset();
    _elapsed = Duration.zero;
    _lastElapsed = Duration.zero; // ✅ 초기화
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _stopwatch.stop();
    super.dispose();
  }
}

