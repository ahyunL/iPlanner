// // import 'dart:convert';
// // import 'package:flutter/material.dart';
// // import 'package:http/http.dart' as http;
// // import 'package:shared_preferences/shared_preferences.dart';


// // class EditProfilePage extends StatefulWidget {
// //   const EditProfilePage({super.key});

// //   @override
// //   State<EditProfilePage> createState() => _EditProfilePageState();
// // }

// // class _EditProfilePageState extends State<EditProfilePage> {
// //   final TextEditingController nameController = TextEditingController();
// //   final TextEditingController emailController = TextEditingController();
// //   final TextEditingController phoneController = TextEditingController();

// //   final TextEditingController newPwController = TextEditingController();
// //   final TextEditingController confirmPwController = TextEditingController();

// //   final List<String> days = ['월', '화', '수', '목', '금', '토', '일'];
// //   final Map<String, TextEditingController> preferredStudyTime = {
// //     '월': TextEditingController(),
// //     '화': TextEditingController(),
// //     '수': TextEditingController(),
// //     '목': TextEditingController(),
// //     '금': TextEditingController(),
// //     '토': TextEditingController(),
// //     '일': TextEditingController(),
// //   };

// //   bool isEditingName = false;
// //   bool isEditingEmail = false;
// //   bool isEditingPhone = false;

// //   @override
// //   void initState() {
// //     super.initState();
// //     fetchUserInfo();
// //   }


// //   Future<void> fetchUserInfo() async {
// //     try {
// //       final prefs = await SharedPreferences.getInstance();
// //       final accessToken = prefs.getString('accessToken');

// //       if (accessToken == null) {
// //         print('❗ accessToken 없음');
// //         return;
// //       }

// //       final response = await http.get(
// //         Uri.parse('http://192.168.35.189:8000/user/profile'),
// //         headers: {'Authorization': 'Bearer $accessToken',
// //         'Content-Type': 'application/json; charset=UTF-8',},
// //       );

// //       if (response.statusCode == 200) {
// //         final decodedBody = utf8.decode(response.bodyBytes);     // ✅ 한글 깨짐 방지
// //         final data = json.decode(decodedBody);   
// //         setState(() {
// //           nameController.text = data['profile']?['name'] ?? '';
// //           emailController.text = data['profile']?['email'] ?? '';

// //           phoneController.text = data['phone'] ?? '';

// //           preferredStudyTime['월']!.text = '${data['study_time_mon'] ?? ''}';
// //           preferredStudyTime['화']!.text = '${data['study_time_tue'] ?? ''}';
// //           preferredStudyTime['수']!.text = '${data['study_time_wed'] ?? ''}';
// //           preferredStudyTime['목']!.text = '${data['study_time_thu'] ?? ''}';
// //           preferredStudyTime['금']!.text = '${data['study_time_fri'] ?? ''}';
// //           preferredStudyTime['토']!.text = '${data['study_time_sat'] ?? ''}';
// //           preferredStudyTime['일']!.text = '${data['study_time_sun'] ?? ''}';
// //         });
// //       } else {
// //         print('❌ 사용자 정보 로드 실패: ${response.statusCode}, ${response.body}');
// //       }
// //     } catch (e) {
// //       print('❗ 사용자 정보 요청 중 오류 발생: $e');
// //     }
// //   }


// //     @override
// //   Widget build(BuildContext context) {
// //     return Scaffold(
// //       backgroundColor: Colors.white,
// //       appBar: AppBar(
// //         title: const Text('회원정보 수정', style: TextStyle(color: Colors.black)),
// //         backgroundColor: Colors.white,
// //         iconTheme: const IconThemeData(color: Colors.black),
// //         elevation: 0,
// //       ),
// //       body: SingleChildScrollView(
// //         padding: const EdgeInsets.all(20),
// //         child: Column(
// //           children: [
// //             _buildInlineEditableRow(
// //               label: '이름',
// //               controller: nameController,
// //               isEditing: isEditingName,
// //               onEditToggle: () {
// //                 setState(() => isEditingName = !isEditingName);
// //               },
// //               onSubmitted: (val) {
// //                 setState(() => isEditingName = false);
// //               },
// //             ),
// //             _buildInlineEditableRow(
// //               label: '이메일',
// //               controller: emailController,
// //               isEditing: isEditingEmail,
// //               onEditToggle: () {
// //                 setState(() => isEditingEmail = !isEditingEmail);
// //               },
// //               onSubmitted: (val) {
// //                 setState(() => isEditingEmail = false);
// //               },
// //             ),
// //             _buildInlineEditableRow(
// //               label: '연락처',
// //               controller: phoneController,
// //               isEditing: isEditingPhone,
// //               onEditToggle: () {
// //                 setState(() => isEditingPhone = !isEditingPhone);
// //               },
// //               onSubmitted: (val) {
// //                 setState(() => isEditingPhone = false);
// //               },
// //             ),
// //             const Divider(height: 40),
// //             const Align(
// //               alignment: Alignment.centerLeft,
// //               child: Text('요일별 선호 공부시간 (분)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
// //             ),
// //             const SizedBox(height: 12),
// //             ...preferredStudyTime.keys.map((day) {
// //               return Padding(
// //                 padding: const EdgeInsets.symmetric(vertical: 6),
// //                 child: Row(
// //                   children: [
// //                     SizedBox(width: 60, child: Text(day)),
// //                     Expanded(
// //                       child: TextField(
// //                         controller: preferredStudyTime[day],
// //                         keyboardType: TextInputType.number,
// //                         decoration: const InputDecoration(
// //                           hintText: '분 단위 입력',
// //                           border: OutlineInputBorder(),
// //                           isDense: true,
// //                           contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
// //                         ),
// //                       ),
// //                     ),
// //                   ],
// //                 ),
// //               );
// //             }).toList(),
// //             const Divider(height: 40),
// //             const Align(
// //               alignment: Alignment.centerLeft,
// //               child: Text('비밀번호 변경', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
// //             ),
// //             const SizedBox(height: 12),
// //             _buildPasswordField(newPwController, '새로운 비밀번호를 입력하세요'),
// //             const SizedBox(height: 10),
// //             _buildPasswordField(confirmPwController, '새로운 비밀번호를 다시 입력하세요'),
// //             const SizedBox(height: 24),
// //             ElevatedButton(
// //               onPressed: () async {
// //                 final prefs = await SharedPreferences.getInstance();
// //                 final accessToken = prefs.getString('accessToken');

// //                 if (accessToken == null) {
// //                   print('❌ accessToken 없음. 로그인 먼저 필요');
// //                   return;
// //                 }

// //              // 🔹 1. 기본 정보 업데이트 (/user/update)
// //             final updatePayload = {
// //               'phone': phoneController.text,
// //               'study_time_mon': int.tryParse(preferredStudyTime['월']!.text) ?? 0,
// //               'study_time_tue': int.tryParse(preferredStudyTime['화']!.text) ?? 0,
// //               'study_time_wed': int.tryParse(preferredStudyTime['수']!.text) ?? 0,
// //               'study_time_thu': int.tryParse(preferredStudyTime['목']!.text) ?? 0,
// //               'study_time_fri': int.tryParse(preferredStudyTime['금']!.text) ?? 0,
// //               'study_time_sat': int.tryParse(preferredStudyTime['토']!.text) ?? 0,
// //               'study_time_sun': int.tryParse(preferredStudyTime['일']!.text) ?? 0,
// //             };
// //             print('📤 PATCH 요청 보낼 데이터: $updatePayload');
// //             print('📦 PATCH /user/update 보낼 body: ${jsonEncode(updatePayload)}');


// //             final basicResponse = await http.patch(
// //               Uri.parse('http://192.168.35.189:8000/user/update'),
// //               headers: {
// //                 'Authorization': 'Bearer $accessToken',
// //                 'Content-Type': 'application/json',
// //               },
// //               body: jsonEncode(updatePayload),
// //             );
// //                 if (basicResponse.statusCode == 200) {
// //                   print('✅ 기본 정보 업데이트 성공');
// //                 } else {
// //                   print('❌ 기본 정보 업데이트 실패: ${basicResponse.statusCode}, ${basicResponse.body}');
// //                 }

// //                 // 🔹 2. 이름/이메일 업데이트 (/user/profile-update)
// //                 final profileResponse = await http.patch(
// //                   Uri.parse('http://192.168.35.189:8000/user/profile-update'),
// //                   headers: {
// //                     'Authorization': 'Bearer $accessToken',
// //                     'Content-Type': 'application/json',
// //                   },
// //                   body: utf8.encode(jsonEncode({
// //                     'name': nameController.text,
// //                     'email': emailController.text,
// //                   })),
// //                 );

// //                 if (profileResponse.statusCode == 200) {
// //                   print('✅ 프로필 정보 업데이트 성공');
// //                 } else {
// //                   print('❌ 프로필 정보 업데이트 실패: ${profileResponse.statusCode}, ${profileResponse.body}');
// //                 }

// //                 // 🔹 3. 비밀번호 변경 요청 (입력값이 있을 때만)
// //                 final newPassword = newPwController.text.trim();
// //                 final confirmPassword = confirmPwController.text.trim();

// //                 if (newPassword.isNotEmpty && confirmPassword.isNotEmpty) {
// //                   if (newPassword != confirmPassword) {
// //                     showDialog(
// //                       context: context,
// //                       builder: (_) => AlertDialog(
// //                         title: const Text('오류'),
// //                         content: const Text('비밀번호가 일치하지 않습니다.'),
// //                         actions: [
// //                           TextButton(onPressed: () => Navigator.pop(context), child: const Text('확인')),
// //                         ],
// //                       ),
// //                     );
// //                     return;
// //                   }

// //                   final pwResponse = await http.patch(
// //                     Uri.parse('http://192.168.35.189:8000/user/change-password'),
// //                     headers: {
// //                       'Authorization': 'Bearer $accessToken',
// //                       'Content-Type': 'application/json',
// //                     },
// //                     body: jsonEncode({
// //                       "current_password": confirmPassword,
// //                       "new_password": newPassword,
// //                     }),
// //                   );

// //                   if (pwResponse.statusCode == 200) {
// //                     print('✅ 비밀번호 변경 성공');
// //                   } else {
// //                     print('❌ 비밀번호 변경 실패: ${pwResponse.statusCode}, ${pwResponse.body}');
// //                   }
// //                 }

// //                 // (선택) 완료 알림
// //                 showDialog(
// //                   context: context,
// //                   builder: (_) => AlertDialog(
// //                     title: const Text('저장 완료'),
// //                     content: const Text('회원 정보가 성공적으로 저장되었습니다.'),
// //                     actions: [
// //                       TextButton(
// //                         onPressed: () {
// //                           Navigator.pop(context); // 팝업 닫기
// //                           Navigator.pop(context, true); // 마이페이지로 이동 + 성공 여부 전달
// //                         },
// //                         child: const Text('확인'),
// //                       ),
// //                     ],
// //                   ),
// //                 );
// //               },
// //               style: ElevatedButton.styleFrom(
// //                 backgroundColor: const Color(0xFF004377),
// //                 padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
// //               ),
// //               child: const Text('저장', style: TextStyle(fontSize: 16)),
// //             )
// //           ],
// //         ),
// //       ),
// //     );
// //   }


// //   Widget _buildInlineEditableRow({
// //     required String label,
// //     required TextEditingController controller,
// //     required bool isEditing,
// //     required VoidCallback onEditToggle,
// //     required Function(String) onSubmitted,
// //   }) {
// //     return Padding(
// //       padding: const EdgeInsets.symmetric(vertical: 12),
// //       child: Row(
// //         children: [
// //           SizedBox(width: 80, child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold))),
// //           Expanded(
// //             child: isEditing
// //                 ? TextField(
// //                     controller: controller,
// //                     autofocus: true,
// //                     onSubmitted: onSubmitted,
// //                     decoration: const InputDecoration(isDense: true),
// //                   )
// //                 : Text(controller.text),
// //           ),
// //           TextButton(
// //             onPressed: onEditToggle,
// //             style: TextButton.styleFrom(
// //               side: const BorderSide(color: Color(0xFF004377)),
// //               minimumSize: const Size(48, 32),
// //               padding: const EdgeInsets.symmetric(horizontal: 12),
// //             ),
// //             child: const Text('수정', style: TextStyle(color: Color(0xFF004377))),
// //           )
// //         ],
// //       ),
// //     );
// //   }

// //   Widget _buildPasswordField(TextEditingController controller, String hint) {
// //     return TextField(
// //       controller: controller,
// //       obscureText: true,
// //       decoration: InputDecoration(
// //         hintText: hint,
// //         border: const OutlineInputBorder(),
// //         isDense: true,
// //         contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
// //       ),
// //     );
// //   }
// // }


// import 'dart:convert';
// import 'package:flutter/material.dart';
// import 'package:http/http.dart' as http;
// import 'package:shared_preferences/shared_preferences.dart';

// class EditProfilePage extends StatefulWidget {
//   const EditProfilePage({super.key});

//   @override
//   State<EditProfilePage> createState() => _EditProfilePageState();
// }

// class _EditProfilePageState extends State<EditProfilePage> {
//   final TextEditingController nameController = TextEditingController();
//   final TextEditingController emailController = TextEditingController();
//   final TextEditingController phoneController = TextEditingController();
//   final TextEditingController newPwController = TextEditingController();
//   final TextEditingController confirmPwController = TextEditingController();

//   final List<String> days = ['월', '화', '수', '목', '금', '토', '일'];
//   final Map<String, TextEditingController> preferredStudyTime = {
//     '월': TextEditingController(),
//     '화': TextEditingController(),
//     '수': TextEditingController(),
//     '목': TextEditingController(),
//     '금': TextEditingController(),
//     '토': TextEditingController(),
//     '일': TextEditingController(),
//   };

//   @override
//   void initState() {
//     super.initState();
//     fetchUserInfo();
//   }

//   Future<void> fetchUserInfo() async {
//     try {
//       final prefs = await SharedPreferences.getInstance();
//       final accessToken = prefs.getString('accessToken');
//       if (accessToken == null) return;

//       final response = await http.get(
//         Uri.parse('http://192.168.35.189:8000/user/profile'),
//         headers: {
//           'Authorization': 'Bearer $accessToken',
//           'Content-Type': 'application/json; charset=UTF-8',
//         },
//       );

//       if (response.statusCode == 200) {
//         final decodedBody = utf8.decode(response.bodyBytes);
//         final data = json.decode(decodedBody);
//         setState(() {
//           nameController.text = data['profile']?['name'] ?? '';
//           emailController.text = data['profile']?['email'] ?? '';
//           phoneController.text = data['phone'] ?? '';
//           preferredStudyTime['월']!.text = '${data['study_time_mon'] ?? ''}';
//           preferredStudyTime['화']!.text = '${data['study_time_tue'] ?? ''}';
//           preferredStudyTime['수']!.text = '${data['study_time_wed'] ?? ''}';
//           preferredStudyTime['목']!.text = '${data['study_time_thu'] ?? ''}';
//           preferredStudyTime['금']!.text = '${data['study_time_fri'] ?? ''}';
//           preferredStudyTime['토']!.text = '${data['study_time_sat'] ?? ''}';
//           preferredStudyTime['일']!.text = '${data['study_time_sun'] ?? ''}';
//         });
//       }
//     } catch (e) {
//       print('❗ 오류 발생: $e');
//     }
//   }

//   Widget _buildSectionCard({required IconData icon, required String title, required List<Widget> children}) {
//     return Container(
//       padding: const EdgeInsets.all(16),
//       margin: const EdgeInsets.only(bottom: 20),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(12),
//         boxShadow: [BoxShadow(color: Colors.grey.shade200, blurRadius: 4)],
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Row(
//             children: [
//               Icon(icon, color: Colors.blue),
//               const SizedBox(width: 8),
//               Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
//             ],
//           ),
//           const SizedBox(height: 12),
//           ...children,
//         ],
//       ),
//     );
//   }

//   Widget _buildTextField(String label, TextEditingController controller, {bool obscure = false}) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 6),
//       child: TextField(
//         controller: controller,
//         obscureText: obscure,
//         decoration: InputDecoration(
//           labelText: label,
//           border: const OutlineInputBorder(),
//           isDense: true,
//           contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
//         ),
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: const Color(0xFFF9F9F9),
//       appBar: AppBar(
//         title: const Text('회원정보 수정', style: TextStyle(color: Colors.black)),
//         backgroundColor: Colors.white,
//         iconTheme: const IconThemeData(color: Colors.black),
//         elevation: 0,
//       ),
//       body: SingleChildScrollView(
//         padding: const EdgeInsets.all(20),
//         child: Column(
//           children: [
//             _buildSectionCard(
//               icon: Icons.person,
//               title: '기본 정보',
//               children: [
//                 _buildTextField('이름', nameController),
//                 _buildTextField('이메일', emailController),
//                 _buildTextField('연락처', phoneController),
//               ],
//             ),
//             _buildSectionCard(
//               icon: Icons.schedule,
//               title: '선호 공부시간 (분)',
//               children: [
//                 GridView.count(
//                   crossAxisCount: 2,
//                   shrinkWrap: true,
//                   physics: const NeverScrollableScrollPhysics(),
//                   childAspectRatio: 3.5,
//                   children: days.map((day) => Padding(
//                     padding: const EdgeInsets.all(4),
//                     child: _buildTextField('$day요일', preferredStudyTime[day]!),
//                   )).toList(),
//                 ),
//               ],
//             ),
//             _buildSectionCard(
//               icon: Icons.lock,
//               title: '비밀번호 변경',
//               children: [
//                 _buildTextField('새 비밀번호', newPwController, obscure: true),
//                 _buildTextField('비밀번호 확인', confirmPwController, obscure: true),
//               ],
//             ),
//             ElevatedButton(
//               onPressed: _submit,
//               style: ElevatedButton.styleFrom(
//                 backgroundColor: const Color(0xFF004377),
//                 padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
//               ),
//               child: const Text('저장', style: TextStyle(fontSize: 16)),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Future<void> _submit() async {
//     final prefs = await SharedPreferences.getInstance();
//     final accessToken = prefs.getString('accessToken');
//     if (accessToken == null) return;

//     final updatePayload = {
//       'phone': phoneController.text,
//       'study_time_mon': int.tryParse(preferredStudyTime['월']!.text) ?? 0,
//       'study_time_tue': int.tryParse(preferredStudyTime['화']!.text) ?? 0,
//       'study_time_wed': int.tryParse(preferredStudyTime['수']!.text) ?? 0,
//       'study_time_thu': int.tryParse(preferredStudyTime['목']!.text) ?? 0,
//       'study_time_fri': int.tryParse(preferredStudyTime['금']!.text) ?? 0,
//       'study_time_sat': int.tryParse(preferredStudyTime['토']!.text) ?? 0,
//       'study_time_sun': int.tryParse(preferredStudyTime['일']!.text) ?? 0,
//     };

//     await http.patch(
//       Uri.parse('http://192.168.35.189:8000/user/update'),
//       headers: {
//         'Authorization': 'Bearer $accessToken',
//         'Content-Type': 'application/json',
//       },
//       body: jsonEncode(updatePayload),
//     );

//     await http.patch(
//       Uri.parse('http://192.168.35.189:8000/user/profile-update'),
//       headers: {
//         'Authorization': 'Bearer $accessToken',
//         'Content-Type': 'application/json',
//       },
//       body: utf8.encode(jsonEncode({
//         'name': nameController.text,
//         'email': emailController.text,
//       })),
//     );

//     final newPassword = newPwController.text.trim();
//     final confirmPassword = confirmPwController.text.trim();
//     if (newPassword.isNotEmpty && confirmPassword.isNotEmpty && newPassword == confirmPassword) {
//       await http.patch(
//         Uri.parse('http://192.168.35.189:8000/user/change-password'),
//         headers: {
//           'Authorization': 'Bearer $accessToken',
//           'Content-Type': 'application/json',
//         },
//         body: jsonEncode({
//           'current_password': confirmPassword,
//           'new_password': newPassword,
//         }),
//       );
//     }

//     showDialog(
//       context: context,
//       builder: (_) => AlertDialog(
//         title: const Text('저장 완료'),
//         content: const Text('회원 정보가 성공적으로 저장되었습니다.'),
//         actions: [
//           TextButton(
//             onPressed: () {
//               Navigator.pop(context);
//               Navigator.pop(context, true);
//             },
//             child: const Text('확인'),
//           ),
//         ],
//       ),
//     );
//   }
// }


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
      Uri.parse('http://192.168.35.189:8000/user/update'),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(updatePayload),
    );

    await http.patch(
      Uri.parse('http://192.168.35.189:8000/user/profile-update'),
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
        Uri.parse('http://192.168.35.189:8000/user/change-password'),
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
