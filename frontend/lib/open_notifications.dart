import 'env.dart'; 
import 'package:flutter/material.dart';
import '../data/notification_api.dart';
import 'notifications_page.dart'; // 너의 NotificationsPage 경로로 맞춰줘

/// 알림 목록을 백엔드에서 불러와서 NotificationsPage에 전달하고,
/// 사용자가 읽음 처리한 항목을 백엔드에 반영한다.
Future<void> openNotifications(BuildContext context) async {
  // 1) 백엔드에서 가져오기
  final raw = await fetchNotifications(limit: 50, offset: 0);
  // raw: [{"notification_id":1, "title":"...", "body":"...", "is_read":false, ...}, ...]

  // 2) 네 페이지가 기대하는 형태로 변환 (read 키 생성, id 보존)
  final adapted =
      raw.map((m) {
        return {
          'id': m['notification_id'] as int,
          'title': m['title'] ?? '',
          'body': m['body'] ?? '',
          'read': (m['is_read'] as bool?) ?? false,
        };
      }).toList();

  // 3) 페이지 열기 → 사용자가 읽음 처리한 인덱스 결과 받기
  final result = await Navigator.push<NotificationsResult>(
    context,
    MaterialPageRoute(builder: (_) => NotificationsPage(items: adapted)),
  );

  // 사용자가 뒤로가기를 누르지 않고 정상 반환했을 때만 처리
  if (result == null) return;

  // 4) 인덱스를 id로 바꿔서 백엔드에 읽음 반영
  final readIds = <int>[];
  for (final idx in result.readIndexes) {
    if (idx >= 0 && idx < adapted.length) {
      readIds.add(adapted[idx]['id'] as int);
    }
  }
  if (readIds.isNotEmpty) {
    await markRead(readIds); // 백엔드: PUT /notifications/read
  }
}