
import 'package:flutter/material.dart';
import 'password_check_page.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'timer_provider.dart';
import 'package:intl/intl.dart';

class MyPage extends StatefulWidget {
  const MyPage({super.key});

  @override
  State<MyPage> createState() => _MyPageState();
}

class _MyPageState extends State<MyPage> {
  String name = '';
  String loginId = '';
  String email = '';
  String phone = '';
  String password = '********';

  void refreshActualStudyTimeFromOutside() async {
    print("✅ 마이페이지 새로고침 호출됨");
    await fetchUserProfile();         // 서버에서 계획 시간 다시 불러오기
    setState(() {});                  // UI 다시 그림
  }

  DateTime selectedWeek = DateTime.now();

  final List<String> days = ['월', '화', '수', '목', '금', '토', '일'];

  Map<String, String> weeklyStudyTime = {
    '월': '',
    '화': '',
    '수': '',
    '목': '',
    '금': '',
    '토': '',
    '일': '',
  };


  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await fetchUserProfile();      // 계획된 공부시간
      await Provider.of<TimerProvider>(context, listen: false).loadWeeklyStudyFromServer(); // 실제 공부시간
    });
  } 

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F8),
      appBar: AppBar(
        title: const Text('마이 페이지', style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProfileCard(),
            const SizedBox(height: 16),
            _buildStudyTimeSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('회원정보', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              TextButton(
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const PasswordCheckPage()),
                  );
                  if (result == true) {
                    await fetchUserProfile();
                  }
                },
                child: const Text('회원정보 수정 ＞', style: TextStyle(fontSize: 16, color: Colors.blue)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildInfoRow('이름', name),
          _buildInfoRow('아이디', loginId),
          _buildInfoRow('비밀번호', password),
          _buildInfoRow('이메일', email),
          _buildInfoRow('연락처', phone),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(width: 80, child: Text(label, style: const TextStyle(color: Colors.grey))),
          Expanded(
            child: Text(value.isNotEmpty ? value : '-',
                style: const TextStyle(fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

Widget _buildStudyTimeSection() {
  return Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6)],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ✅ 주차 이동 버튼
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              onPressed: () async {
                setState(() {
                  selectedWeek = selectedWeek.subtract(const Duration(days: 7));
                });

                int offset = _calculateWeekOffsetFromToday(selectedWeek);
                await Provider.of<TimerProvider>(context, listen: false)
                    .loadWeeklyStudyFromServer(weekOffset: offset);
              },
              child: const Text('＜ 이전주'),
            ),
             Builder(builder: (_) {
                final monday = selectedWeek.subtract(Duration(days: selectedWeek.weekday - 1));
                final mondayText = '${monday.year}년 ${monday.month}월 ${monday.day}일 기준';
                return Text(
                  mondayText,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                );
              }),
            TextButton(
              onPressed: () async {
                setState(() {
                  selectedWeek = selectedWeek.add(const Duration(days: 7));
                });

                int offset = _calculateWeekOffsetFromToday(selectedWeek);
                  await Provider.of<TimerProvider>(context, listen: false)
                      .loadWeeklyStudyFromServer(weekOffset: offset);


              },
              child: const Text('다음주 ＞'),
            ),
          ],
        ),
        const SizedBox(height: 12),

        const Text('이번주 공부시간', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 12),

        // ✅ 목표 공부시간 테이블
        Table(
          border: TableBorder.symmetric(inside: BorderSide(color: Colors.grey.shade300)),
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: [
            TableRow(
              children: days.map((day) {
                return Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(day,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                );
              }).toList(),
            ),
            TableRow(
              children: days.map((day) {
                final raw = weeklyStudyTime[day];
                final minutes = int.tryParse(raw?.replaceAll('분', '') ?? '');
                final text = (minutes == null || minutes == 0)
                    ? '-'
                    : formatMinutes(minutes);
                return Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(text, textAlign: TextAlign.center),
                );
              }).toList(),
            ),
          ],
        ),

        const SizedBox(height: 24),

        const Text('실제 공부시간', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 12),

        // ✅ 실제 공부시간 테이블
        Consumer<TimerProvider>(
          builder: (context, timerProvider, child) {
            final studyMap = timerProvider.weeklyStudy;

            return Table(
              border: TableBorder.symmetric(inside: BorderSide(color: Colors.grey.shade300)),
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              children: [
                TableRow(
                  children: days.map((day) {
                    return Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(day,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                    );
                  }).toList(),
                ),
                TableRow(
                  children: days.map((day) {
                    final duration = studyMap[day] ?? Duration.zero;
                    final minutes = duration.inMinutes;
                    final text = (minutes == 0)
                        ? '-'
                        : '${minutes ~/ 60}h ${minutes % 60}m';
                    return Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(text, textAlign: TextAlign.center),
                    );
                  }).toList(),
                ),
              ],
            );
          },
        ),
      ],
    ),
  );
}


  String formatMinutes(int minutes) {
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    return '${hours}h ${mins}m';
  }
  
  int _calculateWeekOffsetFromToday(DateTime selected) {
  final today = DateTime.now();
  final startOfTodayWeek = today.subtract(Duration(days: today.weekday - 1));
  final startOfSelectedWeek = selected.subtract(Duration(days: selected.weekday - 1));

  return startOfSelectedWeek.difference(startOfTodayWeek).inDays ~/ 7;
}

  Future<void> fetchUserProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final accessToken = prefs.getString('accessToken');
      if (accessToken == null) return;

      final response = await http.get(
        Uri.parse('http://192.168.35.189:8000/user/profile'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json; charset=UTF-8',
        },
      );


      if (response.statusCode == 200) {
        final decodedBody = utf8.decode(response.bodyBytes);
        final data = json.decode(decodedBody);
        setState(() {
          name = data['profile']?['name'] ?? '';
          email = data['profile']?['email'] ?? '';
          loginId = data['login_id'] ?? '';
          phone = data['phone'] ?? '';
          weeklyStudyTime = {
            '월': '${data['study_time_mon'] ?? 0}분',
            '화': '${data['study_time_tue'] ?? 0}분',
            '수': '${data['study_time_wed'] ?? 0}분',
            '목': '${data['study_time_thu'] ?? 0}분',
            '금': '${data['study_time_fri'] ?? 0}분',
            '토': '${data['study_time_sat'] ?? 0}분',
            '일': '${data['study_time_sun'] ?? 0}분',
          };
        });
      } else {
        print('❌ 프로필 불러오기 실패: ${response.statusCode}, ${response.body}');
      }
    } catch (e) {
      print('❗ 예외 발생: $e');
    }
  }
}
typedef MyPageState = _MyPageState;

