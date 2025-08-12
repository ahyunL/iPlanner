import 'env.dart'; 
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_token.dart';

final String _base = Env.baseUrl;

Future<Map<String, String>> _headers() async {
  final token = await loadAccessToken();
  if (token == null || token.isEmpty) {
    throw Exception('로그인이 필요합니다. (토큰 없음)');
  }
  return {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'};
}

/// 목록 조회
Future<List<Map<String, dynamic>>> fetchNotifications({
  int limit = 50,
  int offset = 0,
}) async {
  final h = await _headers();
  final uri = Uri.parse('$_base/notifications/?limit=$limit&offset=$offset');
  final res = await http.get(uri, headers: h);
  if (res.statusCode != 200) {
    throw Exception('GET 실패: ${res.statusCode} ${res.body}');
  }
  final List list = jsonDecode(res.body) as List;
  // 그대로 Map으로 반환 (notification_id / is_read 키 그대로 유지)
  return list.cast<Map<String, dynamic>>();
}

/// 생성
Future<Map<String, dynamic>> createNotification({
  required String title,
  required String body,
}) async {
  final h = await _headers();
  final uri = Uri.parse('$_base/notifications/');
  final res = await http.post(
    uri,
    headers: h,
    body: jsonEncode({'title': title, 'body': body}),
  );
  if (res.statusCode != 200 && res.statusCode != 201) {
    throw Exception('POST 실패: ${res.statusCode} ${res.body}');
  }
  return jsonDecode(res.body) as Map<String, dynamic>;
}

/// 선택 읽음 처리
Future<int> markRead(List<int> ids) async {
  final h = await _headers();
  final uri = Uri.parse('$_base/notifications/read');
  final res = await http.put(uri, headers: h, body: jsonEncode({'ids': ids}));
  if (res.statusCode != 200) {
    throw Exception('PUT(read) 실패: ${res.statusCode} ${res.body}');
  }
  final m = jsonDecode(res.body) as Map<String, dynamic>;
  return (m['updated'] as num).toInt();
}

/// 전체 읽음 처리
Future<int> markAllRead() async {
  final h = await _headers();
  final uri = Uri.parse('$_base/notifications/read-all');
  final res = await http.put(uri, headers: h);
  if (res.statusCode != 200) {
    throw Exception('PUT(read-all) 실패: ${res.statusCode} ${res.body}');
  }
  final m = jsonDecode(res.body) as Map<String, dynamic>;
  return (m['updated'] as num).toInt();
}

/// 삭제
Future<void> deleteNotification(int notificationId) async {
  final h = await _headers();
  final uri = Uri.parse('$_base/notifications/$notificationId');
  final res = await http.delete(uri, headers: h);
  if (res.statusCode != 200 && res.statusCode != 204) {
    throw Exception('DELETE 실패: ${res.statusCode} ${res.body}');
  }
}