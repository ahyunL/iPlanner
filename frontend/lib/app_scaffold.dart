// lib/app_scaffold.dart
import 'env.dart'; 
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'app_tabs.dart';
import 'global_drawer.dart';
import 'submain.dart';
import 'timer.dart';
import 'folder_home_page.dart';
import 'mypage.dart';
import 'main.dart' show HomePage;

// 알림 공용
import 'notification_service.dart';
import 'data/notification_api.dart';
import 'open_notifications.dart';

class AppScaffold extends StatefulWidget {
  const AppScaffold({super.key});
  @override
  State<AppScaffold> createState() => _AppScaffoldState();
}

class _AppScaffoldState extends State<AppScaffold> {
  AppTab _currentTab = AppTab.home;
  void _setCurrentTab(AppTab t) => setState(() => _currentTab = t);

  Widget _buildBody() {
    switch (_currentTab) {
      case AppTab.home:   return const HomePage();
      case AppTab.plan:   return const SubMainPage();
      case AppTab.timer:  return const TimerPage();
      case AppTab.folder: return FolderHomePage();
      case AppTab.my:     return const MyPage();
    }
  }

  String _titleForTab(AppTab t) {
    switch (t) {
      case AppTab.home:   return '홈';
      case AppTab.plan:   return 'AI 학습플래너';
      case AppTab.timer:  return '타이머';
      case AppTab.folder: return '폴더';
      case AppTab.my:     return '마이 페이지';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titleForTab(_currentTab)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF004377)),
        titleTextStyle: const TextStyle(
          color: Color(0xFF004377),
          fontSize: 20,
          fontWeight: FontWeight.normal,
        ),
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        actions: [
          _AppBarBell(hostContext: context), // ← 종 + 팝오버 중앙화
          const SizedBox(width: 8),
        ],
      ),

      drawerEnableOpenDragGesture: true,
      drawer: GlobalDrawer(
        onTapTab: _setCurrentTab,
        currentTab: _currentTab,
      ),

      body: _buildBody(),

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentTab.index,
        onTap: (i) => _setCurrentTab(AppTab.values[i]),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: '홈'),
          BottomNavigationBarItem(icon: Icon(Icons.auto_awesome), label: '계획'),
          BottomNavigationBarItem(icon: Icon(Icons.access_time), label: '타이머'),
          BottomNavigationBarItem(icon: Icon(Icons.folder), label: '폴더'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: '마이'),
        ],
      ),
    );
  }
}

/// 상단 종 + 배지 + 팝오버(오버레이) — 모든 페이지 공용
class _AppBarBell extends StatefulWidget {
  const _AppBarBell({required this.hostContext});
  final BuildContext hostContext; // 전체보기로 이동할 때 사용
  @override
  State<_AppBarBell> createState() => _AppBarBellState();
}

class _AppBarBellState extends State<_AppBarBell> {
  final LayerLink _link = LayerLink();
  OverlayEntry? _entry;
  bool _open = false;

  int get _unread => NotificationService.instance.unreadCount.value;

  void _showPopover() {
    _entry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          // 바깥 클릭시 닫기
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _hidePopover,
            ),
          ),
          CompositedTransformFollower(
            link: _link,
            showWhenUnlinked: false,
            offset: const Offset(-340, 44),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360, maxHeight: 560),
              child: Material(
                elevation: 12,
                borderRadius: BorderRadius.circular(16),
                clipBehavior: Clip.antiAlias,
                child: _NotificationsPopoverBody(
                  hostContext: widget.hostContext,
                  onClose: (refresh) async {
                    _hidePopover();
                    if (refresh) {
                      await NotificationService.instance.fetchUnreadCount();
                    }
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
    Overlay.of(context, rootOverlay: true).insert(_entry!);
    setState(() => _open = true);
    // 내용 미리 로딩
    NotificationService.instance.fetchNotifications();
  }

  void _hidePopover() {
    _entry?.remove();
    _entry = null;
    if (mounted) setState(() => _open = false);
  }

  void _toggle() => _open ? _hidePopover() : _showPopover();

  @override
  void initState() {
    super.initState();
    // 최초 뱃지 로딩 + 변경 구독
    NotificationService.instance.fetchUnreadCount();
    NotificationService.instance.unreadCount.addListener(_onUnreadChanged);
  }

  void _onUnreadChanged() {
    if (!mounted) return;
    setState(() {}); // 배지 갱신
  }

  @override
  void dispose() {
    NotificationService.instance.unreadCount.removeListener(_onUnreadChanged);
    _hidePopover();
    super.dispose();
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
              color: const Color(0xFF004377),
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
                  color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
          ),
      ],
    );
  }
}

/// 팝오버 본문 — 기존 HomePage의 _NotificationsPopoverBody 그대로 이동
class _NotificationsPopoverBody extends StatelessWidget {
  final void Function(bool refresh) onClose;
  final BuildContext hostContext;
  const _NotificationsPopoverBody({
    required this.onClose,
    required this.hostContext,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: NotificationService.instance.fetchNotifications(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox(
            width: 360, height: 520,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return SizedBox(
            width: 360, height: 520,
            child: Center(child: Text('불러오기 실패: ${snapshot.error}')),
          );
        }

        final list = (snapshot.data ?? <AppNotification>[]) as List<AppNotification>;
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));

        return SizedBox(
          width: 360,
          height: 520,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                child: Row(
                  children: [
                    const Text('알림', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () async {
                        try {
                          await NotificationService.instance.markAllAsRead();
                        } finally {
                          onClose(true);
                        }
                      },
                      icon: const Icon(Icons.done_all, size: 18),
                      label: const Text('모두 읽음'),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              Expanded(
                child: list.isEmpty
                    ? const Center(child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('알림이 없어요.'),
                      ))
                    : ListView.separated(
                        padding: EdgeInsets.zero,
                        itemCount: list.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final n = list[i];
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            leading: Icon(
                              n.isRead ? Icons.notifications_none : Icons.notifications,
                              color: n.isRead ? Colors.grey : const Color(0xFF004377),
                            ),
                            title: Text(
                              n.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: n.isRead ? FontWeight.w500 : FontWeight.w800,
                              ),
                            ),
                            subtitle: Text(n.body, maxLines: 2, overflow: TextOverflow.ellipsis),
                            trailing: n.isRead ? null : const Icon(Icons.brightness_1, size: 8, color: Colors.redAccent),
                            onTap: () async {
                              if (!n.isRead) {
                                try { await NotificationService.instance.markAsRead(n.id); } catch (_) {}
                              }
                              onClose(true);
                            },
                          );
                        },
                      ),
              ),

              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 8, left: 8, top: 6, bottom: 8),
                  child: TextButton.icon(
                    onPressed: () async {
                      onClose(false);
                      WidgetsBinding.instance.addPostFrameCallback((_) async {
                        await openNotifications(hostContext);
                        await NotificationService.instance.fetchUnreadCount();
                      });
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
