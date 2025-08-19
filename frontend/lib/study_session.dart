
import 'env.dart'; 

class StudySession {
  final int id; // timer_id
  final DateTime startTime;
  final DateTime endTime;
  final int totalMinutes;

  StudySession({
    required this.id,
    required this.startTime,
    required this.endTime,
    required this.totalMinutes,
  });

  factory StudySession.fromJson(Map<String, dynamic> json) {
    // id 키 호환: timer_id 우선, 없으면 id
    final rawId = json['timer_id'] ?? json['id'];
    final parsedId = rawId is int ? rawId : int.parse(rawId.toString());

    // 시간은 로컬로 변환 (타임테이블 10분 슬롯 계산이 로컬 기준)
    final start = DateTime.parse(json['start_time'].toString()).toLocal();
    final end = DateTime.parse(json['end_time'].toString()).toLocal();

    // total_minutes가 double/문자열이어도 안전하게 int로
    final tm = json['total_minutes'];
    final minutes = tm is int ? tm : (tm is double ? tm.round() : int.parse(tm.toString()));

    return StudySession(
      id: parsedId,
      startTime: start,
      endTime: end,
      totalMinutes: minutes,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'timer_id': id,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime.toIso8601String(),
      'total_minutes': totalMinutes,
    };
  }
}
