import 'env.dart'; 
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController newPwController = TextEditingController();
  final TextEditingController confirmPwController = TextEditingController();


  // ① 드롭다운 옵션(분 단위)
final List<int> _timeMinutes = [
  // 기본: 5~50분
  5, 10, 20, 30, 40, 50,
  // 1시간~2시간(120분)까지는 10분 간격 그대로
  ...List<int>.generate(7, (i) => 60 + i * 10), // 60,70,80,90,100,110,120
  // 2시간(120분) 이후~8시간(480분)까지는 30분 간격
  ...List<int>.generate(((480 - 150) ~/ 30) + 1, (i) => 150 + i * 30), // 150..480
];

// ② 요일별 선택값 저장 (분) — 기본값 60분
final Map<String, int> _selectedStudyTime = {
  '월': 60, '화': 60, '수': 60, '목': 60, '금': 60, '토': 60, '일': 60,
};

// ③ 라벨 포맷터: 5분 / 1시간 / 1시간 30분
String _formatMinutes(int m) {
  if (m < 60) return '$m분';
  final h = m ~/ 60;
  final mm = m % 60;
  return mm == 0 ? '${h}시간' : '${h}시간 ${mm}분';
}

// ④ 안전 변환(서버가 int/num/string 섞여 올 때 대비)
int _toInt(dynamic v, {int fallback = 60}) {
  if (v == null) return fallback;
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? fallback;
  return fallback;
}

// 서버가 45 같은 '옵션에 없는 값'을 줄 때를 대비해 가장 가까운 값으로 스냅
int _snapToClosest(int m) {
  if (_timeMinutes.contains(m)) return m;
  int best = _timeMinutes.first;
  int bestDiff = (m - best).abs();
  for (final v in _timeMinutes) {
    final d = (m - v).abs();
    if (d < bestDiff) { best = v; bestDiff = d; }
  }
  return best;
}





  final List<String> days = ['월', '화', '수', '목', '금', '토', '일'];
  final Map<String, TextEditingController> preferredStudyTime = {
    '월': TextEditingController(),
    '화': TextEditingController(),
    '수': TextEditingController(),
    '목': TextEditingController(),
    '금': TextEditingController(),
    '토': TextEditingController(),
    '일': TextEditingController(),
  };

  @override
  void initState() {
    super.initState();
    fetchUserInfo();
  }

  Future<void> fetchUserInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final accessToken = prefs.getString('accessToken');
      if (accessToken == null) return;

      final response = await http.get(
        Uri.parse('${Env.baseUrl}/user/profile'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json; charset=UTF-8',
        },
      );

      if (response.statusCode == 200) {
        final decodedBody = utf8.decode(response.bodyBytes);
        final data = json.decode(decodedBody);
        setState(() {
          nameController.text = data['profile']?['name'] ?? '';
          emailController.text = data['profile']?['email'] ?? '';
          phoneController.text = data['phone'] ?? '';

          // ⬇︎ 드롭다운 값 채우기 (분)
          _selectedStudyTime['월'] = _snapToClosest(_toInt(data['study_time_mon']));
          _selectedStudyTime['화'] = _snapToClosest(_toInt(data['study_time_tue']));
          _selectedStudyTime['수'] = _snapToClosest(_toInt(data['study_time_wed']));
          _selectedStudyTime['목'] = _snapToClosest(_toInt(data['study_time_thu']));
          _selectedStudyTime['금'] = _snapToClosest(_toInt(data['study_time_fri']));
          _selectedStudyTime['토'] = _snapToClosest(_toInt(data['study_time_sat']));
          _selectedStudyTime['일'] = _snapToClosest(_toInt(data['study_time_sun']));

        });
      }
    } catch (e) {
      print('❗ 오류 발생: $e');
    }
  }

  Widget _buildSectionCard({required IconData icon, required String title, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.blue, size: 24),
              const SizedBox(width: 12),
              Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildTextField(String hint, TextEditingController controller, {bool obscure = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        decoration: InputDecoration(
          hintText: hint,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        ),
      ),
    );
  }

 Widget _buildStudyTimeTable() {
    return Column(
      children: [
        // 요일 헤더
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: days.map((day) => Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                day,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          )).toList(),
        ),
        const SizedBox(height: 8),

        // 드롭다운 줄
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: days.map((day) => Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: DropdownButtonFormField<int>(
                value: _selectedStudyTime[day],
                isExpanded: true,
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                items: _timeMinutes
                    .map((m) => DropdownMenuItem<int>(
                          value: m,
                          child: Text(_formatMinutes(m)),
                        ))
                    .toList(),
                onChanged: (val) {
                  if (val == null) return;
                  setState(() => _selectedStudyTime[day] = val);
                },
              ),
            ),
          )).toList(),
        ),
      ],
    );
  }

  Future<void> _deleteAccount() async {
    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString('accessToken');

    if (accessToken == null) {
      _showDialog('오류', '로그인 정보가 없습니다.');
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('회원 탈퇴'),
        content: const Text('정말 탈퇴하시겠습니까? 이 작업은 되돌릴 수 없습니다.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('탈퇴하기', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final response = await http.delete(
        Uri.parse('${Env.baseUrl}/user/delete'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        await prefs.remove('accessToken');
        if (mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
        }
      } else {
        _showDialog('실패', '회원 탈퇴에 실패했습니다: ${response.statusCode}');
      }
    } catch (e) {
      _showDialog('오류', '서버 요청 중 문제가 발생했습니다: $e');
    }
  }

  void _showDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F8),
      appBar: AppBar(
        title: const Text('회원정보 수정', style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black),
        elevation: 1,
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8)],
        ),
        child: ElevatedButton(
          onPressed: _submit,
          style: ElevatedButton.styleFrom(
            minimumSize: const Size.fromHeight(50),
            backgroundColor: const Color(0xFF004377),
          ),
          child: const Text('저장', style: TextStyle(fontSize: 16)),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
        child: Column(
          children: [
            _buildSectionCard(
              icon: Icons.person,
              title: '기본 정보',
              children: [
                _buildTextField('이름', nameController),
                _buildTextField('이메일', emailController),
                _buildTextField('연락처', phoneController),
              ],
            ),
            _buildSectionCard(
              icon: Icons.schedule,
              title: '선호 공부시간 (분)',
              children: [
                _buildStudyTimeTable(),
              ],
            ),
            _buildSectionCard(
              icon: Icons.lock,
              title: '비밀번호 변경',
              children: [
                _buildTextField('새 비밀번호', newPwController, obscure: true),
                _buildTextField('비밀번호 확인', confirmPwController, obscure: true),
              ],
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: _deleteAccount,
              child: const Text(
                '회원 탈퇴',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString('accessToken');
    if (accessToken == null) return;

    final updatePayload = {
      'phone': phoneController.text,
      'study_time_mon': _selectedStudyTime['월'] ?? 0,
      'study_time_tue': _selectedStudyTime['화'] ?? 0,
      'study_time_wed': _selectedStudyTime['수'] ?? 0,
      'study_time_thu': _selectedStudyTime['목'] ?? 0,
      'study_time_fri': _selectedStudyTime['금'] ?? 0,
      'study_time_sat': _selectedStudyTime['토'] ?? 0,
      'study_time_sun': _selectedStudyTime['일'] ?? 0,
    };


    await http.patch(
      Uri.parse('${Env.baseUrl}/user/update'),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(updatePayload),
    );

    await http.patch(
      Uri.parse('${Env.baseUrl}/user/profile-update'),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
      body: utf8.encode(jsonEncode({
        'name': nameController.text,
        'email': emailController.text,
      })),
    );

    final newPassword = newPwController.text.trim();
    final confirmPassword = confirmPwController.text.trim();
    if (newPassword.isNotEmpty && confirmPassword.isNotEmpty && newPassword == confirmPassword) {
      await http.patch(
        Uri.parse('${Env.baseUrl}/user/change-password'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'current_password': confirmPassword,
          'new_password': newPassword,
        }),
      );
    }

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('저장 완료'),
        content: const Text('회원 정보가 성공적으로 저장되었습니다.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context, true);
            },
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }
}