


import 'package:flutter/material.dart';
import 'password_check_page.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

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
      await fetchUserProfile();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
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
          const Text('이번주 공부시간', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
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
          )
        ],
      ),
    );
  }

  String formatMinutes(int minutes) {
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    return '${hours}h ${mins}m';
  }

  Future<void> fetchUserProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final accessToken = prefs.getString('accessToken');
      if (accessToken == null) return;

      final response = await http.get(
        Uri.parse('http://172.16.11.249:8000/user/profile'),
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
