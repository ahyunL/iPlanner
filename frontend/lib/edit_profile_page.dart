
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
        Uri.parse('http://localhost:8000/user/profile'),
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
          preferredStudyTime['월']!.text = '${data['study_time_mon'] ?? ''}';
          preferredStudyTime['화']!.text = '${data['study_time_tue'] ?? ''}';
          preferredStudyTime['수']!.text = '${data['study_time_wed'] ?? ''}';
          preferredStudyTime['목']!.text = '${data['study_time_thu'] ?? ''}';
          preferredStudyTime['금']!.text = '${data['study_time_fri'] ?? ''}';
          preferredStudyTime['토']!.text = '${data['study_time_sat'] ?? ''}';
          preferredStudyTime['일']!.text = '${data['study_time_sun'] ?? ''}';
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
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: days.map((day) => Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text('$day', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w500)),
            ),
          )).toList(),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: days.map((day) => Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: TextField(
                controller: preferredStudyTime[day],
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          )).toList(),
        ),
      ],
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
      'study_time_mon': int.tryParse(preferredStudyTime['월']!.text) ?? 0,
      'study_time_tue': int.tryParse(preferredStudyTime['화']!.text) ?? 0,
      'study_time_wed': int.tryParse(preferredStudyTime['수']!.text) ?? 0,
      'study_time_thu': int.tryParse(preferredStudyTime['목']!.text) ?? 0,
      'study_time_fri': int.tryParse(preferredStudyTime['금']!.text) ?? 0,
      'study_time_sat': int.tryParse(preferredStudyTime['토']!.text) ?? 0,
      'study_time_sun': int.tryParse(preferredStudyTime['일']!.text) ?? 0,
    };

    await http.patch(
      Uri.parse('http://localhost:8000/user/update'),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(updatePayload),
    );

    await http.patch(
      Uri.parse('http://localhost:8000/user/profile-update'),
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
        Uri.parse('http://localhost:8000/user/change-password'),
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
