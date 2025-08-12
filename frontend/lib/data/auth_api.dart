// lib/data/auth_api.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'env.dart';        // ← env.dart 위치에 맞춰 수정
import 'token_store.dart';

class AuthApi {
  // static 메서드에서 쓰기 위해 static getter로 변경
  static String get _base => Env.baseUrl;

  /// 로그인 후 access_token 저장하고 토큰 문자열 반환
  static Future<String> login({
    required String idOrEmail,
    required String password,
  }) async {
    // ✅ FastAPI 스키마에 맞춤: login_id + password
    final body = jsonEncode({
      'login_id': idOrEmail,
      'password': password,
    });

    final uri = Uri.parse('$_base/auth/login');
    final res = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: body,
    );

    if (res.statusCode != 200) {
      throw Exception('Login failed: ${res.statusCode} ${res.body}');
    }

    final Map<String, dynamic> data = jsonDecode(res.body);
    final token = data['access_token'] as String?;
    if (token == null || token.isEmpty) {
      throw Exception('No access_token in response');
    }

    await TokenStore.save(token);
    return token;
  }
}
