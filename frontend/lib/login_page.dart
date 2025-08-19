import 'env.dart'; 
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'signup_page.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController idController = TextEditingController();
  final TextEditingController pwController = TextEditingController();

  // 8월 13일 인코딩 오류때문에 추가. JSON 파싱 보조: JSON이 아니면 안전하게 fallback
  Map<String, dynamic> _safeJsonDecode(String s) {
    try {
      final decoded = jsonDecode(s);
      if (decoded is Map<String, dynamic>) return decoded;
      return {'detail': s}; // 배열 또는 다른 형식이면 본문 문자열을 detail에 담음
    } catch (_) {
      return {'detail': s}; // JSON 아님 → 원문을 보여줌
    }
  }

  //8월 13일 민경 함수 교체.
  Future<void> login(BuildContext context) async {
    final loginId = idController.text.trim();
    final password = pwController.text.trim();

    if (loginId.isEmpty || password.isEmpty) {
      _showErrorDialog(context, 'ID와 비밀번호를 입력하세요.');
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('${Env.baseUrl}/auth/login'),
        headers: const {
          'Content-Type': 'application/json', // 요청은 그대로
          // 'Accept': 'application/json'  // 선택: 서버가 에러도 JSON으로 주도록 힌트
        },
        body: jsonEncode({'login_id': loginId, 'password': password}),
      );

      // ✅ 항상 bodyBytes를 UTF-8로 디코딩한 뒤 JSON 파싱
      String text = utf8.decode(response.bodyBytes);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = _safeJsonDecode(text);
        final accessToken = data['access_token']?.toString();
        if (accessToken == null || accessToken.isEmpty) {
          _showErrorDialog(context, '로그인 응답에 토큰이 없습니다.');
          return;
        }

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('accessToken', accessToken);
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        // 실패 응답도 동일하게 처리 (한글 깨짐 방지)
        final Map<String, dynamic> err = _safeJsonDecode(text);
        final msg = (err['detail']?.toString() ?? err['message']?.toString() ?? '로그인 실패')
            .replaceAll(RegExp(r'^\s+|\s+$'), '');
        _showErrorDialog(context, '로그인 실패: $msg');
      }
    } catch (e) {
      _showErrorDialog(context, '서버 연결 실패: $e');
    }
  }

  void _showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('오류'),
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
    const cobaltBlue = Color(0xFF004377);
    final isTablet = MediaQuery.of(context).size.width >= 600;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: isTablet ? 120 : 24,
            vertical: 24,
          ),
          child: Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset('assets/logo.png', height: 100),
                  const SizedBox(height: 24),
                  _InputField(label: '아이디 (ID)', controller: idController),
                  _InputField(
                    label: '비밀번호 (Password)',
                    controller: pwController,
                    obscure: true,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: cobaltBlue,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () => login(context),
                      child: const Text(
                        '로그인',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const SignUpPage(),
                            ),
                          );
                        },
                        child: const Text(
                          '* 회원가입',
                          style: TextStyle(color: cobaltBlue),
                        ),
                      ),
                      const SizedBox(width: 12),
                      TextButton(
                        onPressed: () {
                          // TODO: 비밀번호 찾기 로직 추가 예정
                        },
                        child: const Text(
                          '* 비밀번호 찾기',
                          style: TextStyle(color: cobaltBlue),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  final String label;
  final bool obscure;
  final TextEditingController controller;

  const _InputField({
    required this.label,
    required this.controller,
    this.obscure = false,
  });

  @override
  Widget build(BuildContext context) {
    const cobaltBlue = Color(0xFF004377);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: cobaltBlue),
          enabledBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: cobaltBlue),
          ),
          focusedBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: cobaltBlue, width: 2),
          ),
          filled: true,
          fillColor: Colors.white,
        ),
        cursorColor: cobaltBlue,
        style: const TextStyle(color: Colors.black),
      ),
    );
  }
}

Future<void> saveAccessToken(String token) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('accessToken', token);
}

