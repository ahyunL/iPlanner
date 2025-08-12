// frontend/lib/notification_bell.dart
import 'env.dart'; 
import 'package:flutter/material.dart';
import 'notification_service.dart';
import 'open_notifications.dart'; // 전체 보기 화면으로 이동하는 헬퍼(이미 프로젝트에 있음)

class NotificationBell extends StatefulWidget {
  const NotificationBell({super.key, this.iconColor = const Color(0xFF004377)});
  final Color iconColor;

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  final LayerLink _link = LayerLink();
  OverlayEntry? _overlay;
  bool _open = false;
  int _unread = 0;

  @override
  void initState() {
    super.initState();
    // 초기 싱크
    NotificationService.instance.fetchUnreadCount();
    _unread = NotificationService.instance.unreadCount.value;
    NotificationService.instance.unreadCount.addListener(_onUnreadChange);
  }

  void _onUnreadChange() {
    if (!mounted) return;
    setState(() => _unread = NotificationService.instance.unreadCount.value);
  }

  @override
  void dispose() {
    NotificationService.instance.unreadCount.removeListener(_onUnreadChange);
    _removeOverlay();
    super.dispose();
  }

  void _removeOverlay() {
    _overlay?.remove();
    _overlay = null;
  }

  void _toggle() {
    if (_open) {
      _removeOverlay();
      setState(() => _open = false);
    } else {
      _overlay = _buildPopover();
      Overlay.of(context).insert(_overlay!);
      setState(() => _open = true);
    }
  }

  OverlayEntry _buildPopover() {
    return OverlayEntry(
      builder: (context) {
        return Stack(
          children: [
            // 배경 탭 시 닫힘
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _toggle,
              ),
            ),
            CompositedTransformFollower(
              link: _link,
              showWhenUnlinked: false,
              offset: const Offset(-340, 44), // 종 아이콘 기준 위치 조정
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 360,
                  maxHeight: 560,
                ),
                child: Material(
                  elevation: 12,
                  borderRadius: BorderRadius.circular(16),
                  clipBehavior: Clip.antiAlias,
                  child: _NotificationsPopoverBody(
                    onClose: (refresh) async {
                      _toggle();
                      if (refresh) {
                        await NotificationService.instance.fetchUnreadCount();
                      }
                    },
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        CompositedTransformTarget(
          link: _link,
          child: IconButton(
            tooltip: '알림',
            icon: Icon(
              _unread > 0 ? Icons.notifications : Icons.notifications_none,
              color: widget.iconColor,
            ),
            onPressed: _toggle,
          ),
        ),
        if (_unread > 0)
          Positioned(
            right: 6,
            top: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.redAccent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                _unread > 99 ? '99+' : '$_unread',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _NotificationsPopoverBody extends StatefulWidget {
  const _NotificationsPopoverBody({required this.onClose});
  final void Function(bool refresh) onClose;

  @override
  State<_NotificationsPopoverBody> createState() =>
      _NotificationsPopoverBodyState();
}

class _NotificationsPopoverBodyState extends State<_NotificationsPopoverBody> {
  late Future<List<AppNotification>> _future;

  @override
  void initState() {
    super.initState();
    _future = NotificationService.instance.fetchNotifications();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<AppNotification>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const SizedBox(
            width: 360,
            height: 520,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snap.hasError) {
          return SizedBox(
            width: 360,
            height: 520,
            child: Center(child: Text('불러오기 실패: ${snap.error}')),
          );
        }

        final list =
            (snap.data ?? <AppNotification>[]).toList()
              ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

        return SizedBox(
          width: 360,
          height: 520,
          child: Column(
            children: [
              // 헤더
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                child: Row(
                  children: [
                    const Text(
                      '알림',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () async {
                        try {
                          await NotificationService.instance.markAllAsRead();
                          // 로컬 리스트도 즉시 반영
                          for (var i = 0; i < list.length; i++) {
                            list[i] = AppNotification(
                              id: list[i].id,
                              title: list[i].title,
                              body: list[i].body,
                              createdAt: list[i].createdAt,
                              isRead: true,
                            );
                          }
                          setState(() {});
                        } catch (e) {
                          debugPrint('모두 읽음 실패: $e');
                        } finally {
                          widget.onClose(true);
                        }
                      },
                      icon: const Icon(Icons.done_all, size: 18),
                      label: const Text('모두 읽음'),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // 목록
              Expanded(
                child:
                    list.isEmpty
                        ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Text('알림이 없어요.'),
                          ),
                        )
                        : ListView.separated(
                          padding: EdgeInsets.zero,
                          itemCount: list.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, i) {
                            final n = list[i];
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 6,
                              ),
                              leading: Icon(
                                n.isRead
                                    ? Icons.notifications_none
                                    : Icons.notifications,
                                color:
                                    n.isRead
                                        ? Colors.grey
                                        : const Color(0xFF004377),
                              ),
                              title: Text(
                                n.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight:
                                      n.isRead
                                          ? FontWeight.w500
                                          : FontWeight.w800,
                                ),
                              ),
                              subtitle: Text(
                                n.body,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing:
                                  n.isRead
                                      ? null
                                      : const Icon(
                                        Icons.brightness_1,
                                        size: 8,
                                        color: Colors.redAccent,
                                      ),
                              onTap: () async {
                                if (!n.isRead) {
                                  try {
                                    await NotificationService.instance
                                        .markAsRead(n.id);
                                    // 로컬 표시도 즉시 읽음으로
                                    list[i] = AppNotification(
                                      id: n.id,
                                      title: n.title,
                                      body: n.body,
                                      createdAt: n.createdAt,
                                      isRead: true,
                                    );
                                    setState(() {});
                                  } catch (e) {
                                    debugPrint('읽음 처리 실패: $e');
                                  }
                                }
                                widget.onClose(true);
                              },
                            );
                          },
                        ),
              ),

              // 전체 보기
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(
                    right: 8,
                    left: 8,
                    top: 6,
                    bottom: 8,
                  ),
                  child: TextButton.icon(
                    onPressed: () async {
                      widget.onClose(false);
                      // ignore: use_build_context_synchronously
                      await openNotifications(context);
                      await NotificationService.instance.fetchUnreadCount();
                    },
                    icon: const Icon(Icons.arrow_forward, size: 18),
                    label: const Text('전체 보기'),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}