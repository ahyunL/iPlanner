// StudySession 클래스 정의 추가
class StudySession {
  final DateTime studyDate;
  final int totalMinutes;
  final DateTime startTime;
  final DateTime endTime;

  StudySession({
    required this.studyDate,
    required this.totalMinutes,
    required this.startTime,
    required this.endTime,
  });

  factory StudySession.fromJson(Map<String, dynamic> json) {
    return StudySession(
      studyDate: DateTime.parse(json['study_date']),
      totalMinutes: json['total_minutes'],
      startTime: DateTime.parse(json['start_time']),
      endTime: DateTime.parse(json['end_time']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'study_date': studyDate.toIso8601String().split('T')[0],
      'total_minutes': totalMinutes,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime.toIso8601String(),
    };
  }
}