// import 'package:flutter/material.dart';
// import 'signup_page.dart';
// import 'package:http/http.dart' as http;

// import 'dart:convert';

// class LoginPage extends StatefulWidget {
//   const LoginPage({super.key});

//   @override
//   State<LoginPage> createState() => _LoginPageState();
// }

// class _LoginPageState extends State<LoginPage> {
//   final TextEditingController idController = TextEditingController();
//   final TextEditingController pwController = TextEditingController();

//   Future<void> login(BuildContext context) async {
//     final loginId = idController.text.trim();
//     final password = pwController.text.trim();

//     if (loginId.isEmpty || password.isEmpty) {
//       _showErrorDialog(context, 'ID와 비밀번호를 입력하세요.');
//       return;
//     }
//     // **여기서 데이터를 확인할 수 있어** (loginId와 password가 잘 전달되는지)
//     print('login_id: $loginId, password: $password'); // 이 줄을 추가해!

//     try {
//       final response = await http.post(
//         Uri.parse(
//           'http://localhost:8000/auth/login',
//         ), // ✅ 서버 IP:PORT + /auth/login 경로로 수정
//         headers: {'Content-Type': 'application/json'},
//         body: jsonEncode({'login_id': loginId, 'password': password}),
//       );

//       if (response.statusCode == 200) {
//         final responseData = jsonDecode(response.body);
//         final accessToken = responseData['access_token'];

//         // TODO: 나중에 access_token을 저장하고 관리할 수 있음
//         print('✅ 로그인 성공. AccessToken: $accessToken');

//         Navigator.pushReplacementNamed(context, '/folder'); // 로그인 성공 시 이동
//       } else {
//         final errorData = jsonDecode(response.body);
//         _showErrorDialog(context, '로그인 실패: ${errorData['detail']}');
//       }
//     } catch (e) {
//       _showErrorDialog(context, '서버 연결 실패: $e');
//     }
//   }

//   void _showErrorDialog(BuildContext context, String message) {
//     showDialog(
//       context: context,
//       builder:
//           (_) => AlertDialog(
//             title: const Text('오류'),
//             content: Text(message),
//             actions: [
//               TextButton(
//                 onPressed: () => Navigator.pop(context),
//                 child: const Text('확인'),
//               ),
//             ],
//           ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     const cobaltBlue = Color(0xFF004377);

//     return Scaffold(
//       backgroundColor: Colors.white,
//       body: Center(
//         child: SingleChildScrollView(
//           padding: const EdgeInsets.all(24),
//           child: Column(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [
//               Image.asset('assets/logo.png', height: 120),
//               const SizedBox(height: 12),
//               const SizedBox(height: 32),
//               _InputField(label: 'ID', controller: idController),
//               _InputField(
//                 label: 'Password',
//                 controller: pwController,
//                 obscure: true,
//               ),
//               const SizedBox(height: 24),
//               SizedBox(
//                 width: double.infinity,
//                 height: 56,
//                 child: ElevatedButton(
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: cobaltBlue,
//                     shape: RoundedRectangleBorder(
//                       borderRadius: BorderRadius.circular(8),
//                     ),
//                     elevation: 6,
//                   ),
//                   onPressed: () => login(context),
//                   child: const Text(
//                     '로그인',
//                     style: TextStyle(color: Colors.white),
//                   ),
//                 ),
//               ),
//               const SizedBox(height: 20),
//               TextButton(
//                 onPressed: () {
//                   Navigator.push(
//                     context,
//                     MaterialPageRoute(builder: (_) => const SignUpPage()),
//                   );
//                 },
//                 child: const Text(
//                   '* 회원가입',
//                   style: TextStyle(color: Color(0xFF004377)),
//                 ),
//               ),
//               TextButton(
//                 onPressed: () {
//                   // TODO: 비밀번호 찾기 로직 추가 예정
//                 },
//                 child: const Text(
//                   '* 비밀번호를 잊어버리셨나요?',
//                   style: TextStyle(color: Color(0xFF004377)),
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }

// class _InputField extends StatelessWidget {
//   final String label;
//   final bool obscure;
//   final TextEditingController controller;

//   const _InputField({
//     required this.label,
//     required this.controller,
//     this.obscure = false,
//   });

//   @override
//   Widget build(BuildContext context) {
//     const cobaltBlue = Color(0xFF004377);

//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 8),
//       child: TextField(
//         controller: controller,
//         obscureText: obscure,
//         decoration: InputDecoration(
//           labelText: label,
//           labelStyle: TextStyle(color: cobaltBlue),
//           enabledBorder: OutlineInputBorder(
//             borderSide: BorderSide(color: cobaltBlue),
//           ),
//           focusedBorder: OutlineInputBorder(
//             borderSide: BorderSide(color: cobaltBlue, width: 2),
//           ),
//           filled: true,
//           fillColor: Colors.white,
//         ),
//         cursorColor: cobaltBlue,
//         style: const TextStyle(color: Colors.black),
//       ),
//     );
//   }
// }

import 'package:flutter/material.dart';
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

  Future<void> login(BuildContext context) async {
    final loginId = idController.text.trim();
    final password = pwController.text.trim();

    if (loginId.isEmpty || password.isEmpty) {
      _showErrorDialog(context, 'ID와 비밀번호를 입력하세요.');
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('http://localhost:8000/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'login_id': loginId, 'password': password}),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final accessToken = responseData['access_token'];
        Navigator.pushReplacementNamed(context, '/folder');
      } else {
        final errorData = jsonDecode(response.body);
        _showErrorDialog(context, '로그인 실패: ${errorData['detail']}');
      }
    } catch (e) {
      _showErrorDialog(context, '서버 연결 실패: $e');
    }
  }

  void _showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
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
