// global_drawer.dart
import 'env.dart'; 
import 'package:flutter/material.dart';
import 'app_scaffold.dart'; // AppTab enum 가져오기
import 'app_tabs.dart'; // ← 추가 (중요)

class GlobalDrawer extends StatelessWidget {
  final void Function(AppTab)? onTapTab; // ← 탭 전환 콜백
  final AppTab? currentTab;              // ← 선택 표시(옵션)

  const GlobalDrawer({super.key, this.onTapTab, this.currentTab});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const DrawerHeader(
            child: Text(
              '메뉴',
              style: TextStyle(fontSize: 20, color: Color(0xFF004377)),
            ),
          ),

          // ✅ pushNamed 전부 제거 → 콜백으로 탭만 바꿈
          ListTile(
            title: Text('홈',
              style: TextStyle(
                fontWeight: currentTab == AppTab.home ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            onTap: () {
              onTapTab?.call(AppTab.home);
              Navigator.pop(context);
            },
          ),
                    // ▼▼ AI 학습 계획 (기본은 닫힘) ▼▼
          ExpansionTile(
            initiallyExpanded: false, // 기본 닫힘
            title: Text(
              'AI 학습 계획',
              style: TextStyle(
                fontWeight: currentTab == AppTab.plan ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            childrenPadding: const EdgeInsets.only(left: 12),
            children: [
              // 플래너 홈(탭 전환)
              ListTile(
                title: const Text('플래너 홈'),
                onTap: () {
                  onTapTab?.call(AppTab.plan); // 탭만 전환
                  Navigator.pop(context);      // 드로어 닫기
                },
              ),
              // 계획세우기(개별 페이지로 이동)
              ListTile(
                title: const Text('계획세우기'),
                onTap: () {
                  Navigator.pop(context);                 // 드로어 닫고
                  Navigator.of(context).pushNamed('/studyplan'); // 라우트 이동
                },
              ),
            ],
          ),
          ListTile(
            title: Text('타이머',
              style: TextStyle(
                fontWeight: currentTab == AppTab.timer ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            onTap: () {
              onTapTab?.call(AppTab.timer);
              Navigator.pop(context);
            },
          ),
          ListTile(
            title: Text('폴더',
              style: TextStyle(
                fontWeight: currentTab == AppTab.folder ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            onTap: () {
              onTapTab?.call(AppTab.folder);
              Navigator.pop(context);
            },
          ),
          ListTile(
            title: Text('마이페이지',
              style: TextStyle(
                fontWeight: currentTab == AppTab.my ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            onTap: () {
              onTapTab?.call(AppTab.my);
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}