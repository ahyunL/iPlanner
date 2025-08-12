// lib/notification_service.dart
import 'env.dart'; 
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// 에뮬레이터/웹 동시 대응
final String _baseUrl =
    kIsWeb ? '${Env.baseUrl}' : '${Env.baseUrl}';

class AppNotification {
  final int id;
  final String title;
  final String body;
  final DateTime createdAt;
  final bool isRead;

  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.isRead,
  });

  // [MOD] 표시용 문구 정규화(더 공격적으로 적용)
  factory AppNotification.fromJson(Map<String, dynamic> j) {
    final isReadRaw = j['is_read'] ?? j['isRead'] ?? false;

    final rawTitle = (j['title'] ?? '').toString();
    final rawBody = (j['body'] ?? j['message'] ?? '').toString();

    String title = rawTitle.trim();
    String body = rawBody.trim();

    // 1) "오늘 할당: XXX" 패턴이면 무조건 변환 + 제목도 통일
    final alloc = RegExp(r'^\s*오늘\s*할당:\s*(.+)$');
    final m = alloc.firstMatch(body);
    if (m != null) {
      final chunk = m.group(1)!.trim();
      title = '오늘 학습 계획'; // [MOD]
      body = '오늘은 $chunk 하는 날이에요!'; // [MOD]
    } else {
      // 2) 제목이 오늘 계획 계열이면 제목 통일 + 부드럽게 보정
      final looksLikeTodayPlan =
          title.contains('오늘 학습 계획') || title.contains('오늘 계획');
      if (looksLikeTodayPlan) {
        title = '오늘 학습 계획'; // [MOD]
        if (!body.startsWith('오늘은')) {
          body = '오늘은 $body';
        }
      }
    }

    return AppNotification(
      id: (j['notification_id'] ?? j['id']) as int,
      title: title,
      body: body,
      createdAt:
          DateTime.tryParse((j['created_at'] ?? j['createdAt']).toString()) ??
          DateTime.now(),
      isRead: (isReadRaw == true || isReadRaw == 1),
    );
  }
}

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  /// 상단 배지
  final ValueNotifier<int> unreadCount = ValueNotifier<int>(0);

  Future<Map<String, String>> _headers() async {
    final sp = await SharedPreferences.getInstance();
    final token = sp.getString('accessToken') ?? '';
    if (token.isEmpty) {
      throw Exception('No JWT token');
    }
    return {
      'Content-Type': 'application/json; charset=UTF-8',
      'Authorization': 'Bearer $token',
    };
  }

  /// 알림 목록 조회
  Future<List<AppNotification>> fetchNotifications({
    int limit = 50,
    int offset = 0,
  }) async {
    final res = await http.get(
      // 슬래시 붙여서 307 회피
      Uri.parse('$_baseUrl/notifications/?limit=$limit&offset=$offset'),
      headers: await _headers(),
    );
    if (res.statusCode != 200) {
      throw Exception('알림 조회 실패: ${res.statusCode} ${res.body}');
    }

    final raw = jsonDecode(utf8.decode(res.bodyBytes));
    final List<AppNotification> list;
    if (raw is List) {
      list =
          raw
              .whereType<Map>()
              .map((e) => AppNotification.fromJson(e.cast<String, dynamic>()))
              .toList();
    } else if (raw is Map && raw['results'] is List) {
      list =
          (raw['results'] as List)
              .whereType<Map>()
              .map((e) => AppNotification.fromJson(e.cast<String, dynamic>()))
              .toList();
    } else {
      list = const <AppNotification>[];
    }

    unreadCount.value = list.where((n) => !n.isRead).length;
    return list;
  }

  /// 미읽음 개수 조회 (/notifications/unread-count)
  Future<int> fetchUnreadCount() async {
    final res = await http.get(
      Uri.parse('$_baseUrl/notifications/unread-count'),
      headers: await _headers(),
    );
    if (res.statusCode != 200) {
      // 실패하면 목록으로 보정
      await fetchNotifications();
      return unreadCount.value;
    }
    final data = json.decode(utf8.decode(res.bodyBytes));
    final c = (data is Map) ? (data['unread'] ?? data['count'] ?? 0) : 0;
    final cnt = c is int ? c : int.tryParse(c.toString()) ?? 0;
    unreadCount.value = cnt;
    return cnt;
  }

  /// 개별 읽음 처리 (백엔드: PUT /notifications/read  body: {"ids":[id]})
  Future<void> markAsRead(int id) async {
    final res = await http.put(
      Uri.parse('$_baseUrl/notifications/read'),
      headers: await _headers(),
      body: jsonEncode({
        'ids': [id],
      }),
    );
    if (res.statusCode != 200) {
      throw Exception('읽음 처리 실패: ${res.statusCode} ${res.body}');
    }
    // 서버 재조회 없이 배지 즉시 감소
    unreadCount.value = (unreadCount.value - 1).clamp(0, 9999);
  }

  /// 전체 읽음 처리 (백엔드: PUT /notifications/read-all)
  Future<void> markAllAsRead() async {
    final res = await http.put(
      Uri.parse('$_baseUrl/notifications/read-all'),
      headers: await _headers(),
    );
    if (res.statusCode != 200) {
      throw Exception('전체 읽음 처리 실패: ${res.statusCode} ${res.body}');
    }
    unreadCount.value = 0;
  }

  // ─────────────────────────────────────────────────────────
  // 알림 생성: POST /notifications/  (필드: title, body)
  // ─────────────────────────────────────────────────────────
  Future<void> createNotification({
    required String title,
    required String body,
  }) async {
    final headers = await _headers();
    final uri = Uri.parse('$_baseUrl/notifications/'); // 슬래시 포함

    final res = await http.post(
      uri,
      headers: headers,
      body: jsonEncode({'title': title, 'body': body}),
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      debugPrint('알림 생성 실패: ${res.statusCode} ${res.body}');
      return; // 실패해도 앱 흐름은 막지 않음
    }
  }

  // (옵션) 바로 원하는 문구로 생성하는 헬퍼
  Future<void> createPlanCreatedNotificationForChunk(String chunk) async {
    await createNotification(title: '오늘 학습 계획', body: '오늘은 $chunk 하는 날이에요!');
  }
}