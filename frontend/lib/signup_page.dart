import 'env.dart'; 
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'signup_studytime.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final Color cream = const Color(0xFFFBFCF7);
  final Color cobaltBlue = const Color(0xFF004377);

  final TextEditingController _idController = TextEditingController();
  final TextEditingController _pwController = TextEditingController();
  final TextEditingController _pwConfirmController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController(text: '010');
  final TextEditingController _birthdayController = TextEditingController();
  DateTime? _selectedBirthday;

  bool agreeAll = false;
  bool agreePrivacy = false;
  bool agreeMarketing = false;
  bool agreeAnalysis = false;

  @override
  void initState() {
    super.initState();
    _phoneController.addListener(_formatPhoneNumber);
  }

  @override
  void dispose() {
    _idController.dispose();
    _pwController.dispose();
    _pwConfirmController.dispose();
    _phoneController.dispose();
    _birthdayController.dispose();
    super.dispose();
  }

  void _formatPhoneNumber() {
    String digits = _phoneController.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length > 13) digits = digits.substring(0, 13);
    if (digits.length <= 3) {
      _phoneController.value = TextEditingValue(
        text: digits,
        selection: TextSelection.collapsed(offset: digits.length),
      );
    } else if (digits.length <= 7) {
      _phoneController.value = TextEditingValue(
        text: '${digits.substring(0, 3)}-${digits.substring(3)}',
        selection: TextSelection.collapsed(offset: '${digits.substring(0, 3)}-${digits.substring(3)}'.length),
      );
    } else {
      _phoneController.value = TextEditingValue(
        text: '${digits.substring(0, 3)}-${digits.substring(3, 7)}-${digits.substring(7)}',
        selection: TextSelection.collapsed(offset: '${digits.substring(0, 3)}-${digits.substring(3, 7)}-${digits.substring(7)}'.length),
      );
    }
  }

  Future<void> _pickBirthday() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000, 1, 1),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      helpText: '생년월일 선택',
      cancelText: '취소',
      confirmText: '선택',
      locale: const Locale('ko', 'KR'),
    );
    if (picked != null) {
      setState(() {
        _selectedBirthday = picked;
        _birthdayController.text = '${picked.year}.${picked.month.toString().padLeft(2, '0')}.${picked.day.toString().padLeft(2, '0')}';
      });
    }
  }

  Future<void> _signUp() async {
    if (_idController.text.trim().isEmpty ||
        _pwController.text.isEmpty ||
        _pwConfirmController.text.isEmpty ||
        _birthdayController.text.isEmpty ||
        _phoneController.text.isEmpty) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text("입력 누락"),
          content: const Text("모든 항목을 입력해주세요."),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("확인"))],
        ),
      );
      return;
    }

    if (!agreePrivacy || !agreeMarketing || !agreeAnalysis) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text("약관 미동의"),
          content: const Text("모든 약관에 동의해야 회원가입이 가능합니다."),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("확인"))],
        ),
      );
      return;
    }

    if (_pwController.text != _pwConfirmController.text) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text("비밀번호 불일치"),
          content: const Text("비밀번호와 비밀번호 확인이 일치하지 않습니다."),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("확인"))],
        ),
      );
      return;
    }

    final url = Uri.parse('${Env.baseUrl}/user/signup');
    final Map<String, dynamic> signupData = {
      "login_id": _idController.text.trim(),
      "password": _pwController.text.trim(),
      "birthday": _selectedBirthday != null
          ? "${_selectedBirthday!.year}-${_selectedBirthday!.month.toString().padLeft(2, '0')}-${_selectedBirthday!.day.toString().padLeft(2, '0')}"
          : '',
      "phone": _phoneController.text.replaceAll(RegExp(r'[^0-9]'), ''),
    };

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(signupData),
      );

      final resBody = jsonDecode(response.body);

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('회원가입 성공!')),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => StudyPreferencePage(
              loginId: _idController.text.trim(),
            ),
          ),
        );
      } else {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("회원가입 실패"),
            content: Text(resBody is Map<String, dynamic> && resBody.containsKey("detail") ? resBody["detail"] : "서버 오류 또는 알 수 없는 오류가 발생했습니다."),
            actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("확인"))],
          ),
        );
      }
    } catch (e) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text("오류"),
          content: Text("회원가입 중 오류가 발생했습니다: $e"),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("확인"))],
        ),
      );
    }
  }
@override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width >= 600;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: cream,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
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
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Column(
                  children: [
                    Image.asset('assets/logo.png', height: 80),
                    const SizedBox(height: 24),
                  ],
                ),
                _buildTextField(_birthdayController, '생년월일 *',
                  readOnly: false,
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.calendar_today, color: Color(0xFF004377)),
                    onPressed: _pickBirthday,
                  ),
                ),
                _buildTextField(_idController, '아이디 (로그인 ID)'),
                _buildTextField(_pwController, '비밀번호', obscure: true),
                _buildTextField(_pwConfirmController, '비밀번호 확인', obscure: true),
                _buildTextField(_phoneController, '휴대폰 번호'),
                const SizedBox(height: 16),
                _buildAgreementCheckboxes(),
                const SizedBox(height: 32),
                const Divider(thickness: 1),
                const Text("모든 항목을 확인한 후 회원가입을 눌러주세요", style: TextStyle(fontSize: 13, color: Colors.grey)),
                const SizedBox(height: 12),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: cobaltBlue,
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    if (agreePrivacy) {
                      _signUp();
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('필수 약관에 동의해주세요')),
                      );
                    }
                  },
                  child: const Text('회원가입', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label, {
    bool obscure = false,
    bool readOnly = false,
    Widget? suffixIcon,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        readOnly: readOnly,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Color(0xFF004377)),
          enabledBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: Color(0xFF004377)),
          ),
          focusedBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: Color(0xFF004377), width: 2),
          ),
          filled: true,
          fillColor: Colors.white,
          suffixIcon: suffixIcon,
        ),
        cursorColor: cobaltBlue,
        keyboardType: label.contains('휴대폰') ? TextInputType.phone : TextInputType.text,
        inputFormatters: label.contains('휴대폰') ? [LengthLimitingTextInputFormatter(13)] : null,
      ),
    );
  }

  Widget _buildAgreementCheckboxes() {
    return Card(
      color: const Color(0xFFF5F5F5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          children: [
            CheckboxListTile(
              value: agreeAll,
              onChanged: (val) {
                setState(() {
                  agreeAll = val ?? false;
                  agreePrivacy = val ?? false;
                  agreeMarketing = val ?? false;
                  agreeAnalysis = val ?? false;
                });
              },
              title: const Text('약관에 전체 동의'),
              controlAffinity: ListTileControlAffinity.leading,
              activeColor: cobaltBlue,
            ),
            CheckboxListTile(
              value: agreePrivacy,
              onChanged: (val) {
                setState(() {
                  agreePrivacy = val ?? false;
                  agreeAll = agreePrivacy && agreeMarketing && agreeAnalysis;
                });
              },
              title: const Text('[필수] 개인정보 수집 및 이용 동의'),
              controlAffinity: ListTileControlAffinity.leading,
              activeColor: cobaltBlue,
            ),
            CheckboxListTile(
              value: agreeMarketing,
              onChanged: (val) {
                setState(() {
                  agreeMarketing = val ?? false;
                  agreeAll = agreePrivacy && agreeMarketing && agreeAnalysis;
                });
              },
              title: const Text('[선택] 마케팅 정보 수신 동의'),
              controlAffinity: ListTileControlAffinity.leading,
              activeColor: cobaltBlue,
            ),
            CheckboxListTile(
              value: agreeAnalysis,
              onChanged: (val) {
                setState(() {
                  agreeAnalysis = val ?? false;
                  agreeAll = agreePrivacy && agreeMarketing && agreeAnalysis;
                });
              },
              title: const Text('[선택] 학습 이력 분석 동의'),
              controlAffinity: ListTileControlAffinity.leading,
              activeColor: cobaltBlue,
            ),
          ],
        ),
      ),
    );
  }
}