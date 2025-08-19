
//frontend/lib/mypage.dart
import 'env.dart'; 
import 'package:flutter/material.dart';
import 'password_check_page.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'timer_provider.dart';
import 'package:intl/intl.dart';
import 'study_type_page.dart'; // 아현추가코드
import 'open_notifications.dart';
import 'notification_service.dart'; // 공용 알림 서비스(배지/목록/읽음)

class MyPage extends StatefulWidget {
  const MyPage({super.key});

  @override
  State<MyPage> createState() => _MyPageState();
}

class _MyPageState extends State<MyPage> {
  String name = '';
  String loginId = '';
  String email = '';
  String phone = '';
  String password = '********';

  DateTime selectedWeek = DateTime.now();
  final List<String> days = ['월', '화', '수', '목', '금', '토', '일'];

  Map<String, String> weeklyStudyTime = {
    '월': '',
    '화': '',
    '수': '',
    '목': '',
    '금': '',
    '토': '',
    '일': '',
  };

  // ── 알림 팝오버 상태(홈과 동일 UX) ────────────────────────────────
  final LayerLink _bellLink = LayerLink();
  OverlayEntry? _notifOverlay;
  bool _isPopoverOpen = false;

  void _removeNotifPopover() {
    _notifOverlay?.remove();
    _notifOverlay = null;
  }

  void _toggleNotifPopover() {
    if (_isPopoverOpen) {
      _removeNotifPopover();
      setState(() => _isPopoverOpen = false);
      return;
    }
    _notifOverlay = _buildNotifPopover();
    Overlay.of(context).insert(_notifOverlay!);
    setState(() => _isPopoverOpen = true);

    // 열 때 최신화
    NotificationService.instance.fetchNotifications();
  }

  OverlayEntry _buildNotifPopover() {
    return OverlayEntry(
      builder: (_) => Stack(
        children: [
          // 바깥 클릭 시 닫기
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () {
                _removeNotifPopover();
                setState(() => _isPopoverOpen = false);
              },
            ),
          ),
          // 아이콘 기준 팝오버
          CompositedTransformFollower(
            link: _bellLink,
            showWhenUnlinked: false,
            offset: const Offset(-340, 44), // 위치 미세조정 가능
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 360,
                maxHeight: 560,
              ),
              child: Material(
                elevation: 12,
                borderRadius: BorderRadius.circular(16),
                clipBehavior: Clip.antiAlias,
                child: _MyPageNotificationsPopoverBody(
                  hostContext: context, // ✅ 페이지 컨텍스트 전달
                  onClose: (bool refresh) async {
                    _removeNotifPopover();
                    setState(() => _isPopoverOpen = false);
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
  }
  // ─────────────────────────────────────────────────────────

  // 외부에서 새로고침 호출 시 사용
  void refreshActualStudyTimeFromOutside() async {
    await fetchUserProfile();
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await fetchUserProfile(); // 계획된 공부시간
      await Provider.of<TimerProvider>(context, listen: false)
          .loadWeeklyStudyFromServer(); // 실제 공부시간
    });
  }

  /// ✅ 로그아웃 함수
  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('accessToken');

    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    }
  }

  // ── yeabi_sm 보조 함수 (레이아웃 계산/표시용) ─────────────────────
  DateTime _mondayOf(DateTime d) => d.subtract(Duration(days: d.weekday - 1));

  DateTime _dateOfDayInSelectedWeek(String day) {
    final idx = days.indexOf(day); // 0~6
    return _mondayOf(selectedWeek).add(Duration(days: idx));
  }

  String _fmtMinutes(int minutes) {
    if (minutes <= 0) return '-';
    final h = minutes ~/ 60, m = minutes % 60;
    if (h > 0 && m > 0) return '${h}h ${m}m';
    if (h > 0) return '${h}h';
    return '${m}m';
  }

  DateTime _strip(DateTime d) => DateTime(d.year, d.month, d.day);
  bool _isFutureDate(DateTime d) => _strip(d).isAfter(_strip(DateTime.now()));
  // ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F8),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProfileCard(), // 회원정보 + 이번주(계획) 공부시간
            const SizedBox(height: 16),
            _buildActualStudySection(), // 실제 공부시간(칩 그리드 + 합계 + 분석 버튼)
          ],
        ),
      ),
    );
  }

  /// 회원정보 + ‘이번주 공부시간(계획)’ 테이블 (yeabi_sm 스타일로 정리)
  Widget _buildProfileCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더: 좌측 타이틀, 우측 2단 버튼(회원정보 수정 / 로그아웃)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '회원정보',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const PasswordCheckPage(),
                        ),
                      );
                      if (result == true) {
                        await fetchUserProfile();
                      }
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      foregroundColor: Colors.blue,
                    ),
                    child: const Text('회원정보 수정 ＞',
                        style: TextStyle(fontSize: 16)),
                  ),
                  const SizedBox(height: 2),
                  TextButton(
                    onPressed: _logout,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      foregroundColor: Colors.redAccent,
                    ),
                    child:
                        const Text('로그아웃 ＞', style: TextStyle(fontSize: 16)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),

          // 기본 정보
          _buildInfoRow('이름', name),
          _buildInfoRow('아이디', loginId),
          _buildInfoRow('비밀번호', password),
          _buildInfoRow('이메일', email),
          _buildInfoRow('연락처', phone),

          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 12),

          const Text('이번주 공부시간',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),

          // 이번주(설정된) 공부시간 표
          Table(
            border: TableBorder.symmetric(
              inside: BorderSide(color: Colors.grey.shade300),
            ),
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: [
              TableRow(
                children: days
                    .map(
                      (day) => Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          day,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    )
                    .toList(),
              ),
              TableRow(
                children: days
                    .map(
                      (day) {
                        final raw = weeklyStudyTime[day];
                        final minutes =
                            int.tryParse(raw?.replaceAll('분', '') ?? '');
                        final text = (minutes == null || minutes == 0)
                            ? '-'
                            : formatMinutes(minutes);
                        return Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(text, textAlign: TextAlign.center),
                        );
                      },
                    )
                    .toList(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(label, style: const TextStyle(color: Colors.grey)),
          ),
          Expanded(
            child: Text(
              value.isNotEmpty ? value : '-',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  /// 실제 공부시간(주차 이동 + 칩 그리드 + 주간 합계 + 분석 버튼)
  Widget _buildActualStudySection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('실제 공부시간',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),

          // 주차 이동 (표 위)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: () async {
                  setState(() =>
                      selectedWeek = selectedWeek.subtract(const Duration(days: 7)));
                  final offset = _calculateWeekOffsetFromToday(selectedWeek);
                  await Provider.of<TimerProvider>(context, listen: false)
                      .loadWeeklyStudyFromServer(weekOffset: offset);
                },
                child: const Text('＜ 이전주'),
              ),
              Builder(builder: (_) {
                final monday = _mondayOf(selectedWeek);
                final mondayText =
                    '${monday.year}년 ${monday.month}월 ${monday.day}일 기준';
                return Text(mondayText,
                    style: const TextStyle(fontWeight: FontWeight.bold));
              }),
              TextButton(
                onPressed: () async {
                  setState(() =>
                      selectedWeek = selectedWeek.add(const Duration(days: 7)));
                  final offset = _calculateWeekOffsetFromToday(selectedWeek);
                await Provider.of<TimerProvider>(context, listen: false)
                      .loadWeeklyStudyFromServer(weekOffset: offset);
                },
                child: const Text('다음주 ＞'),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // 예쁜 그리드 (yeabi_sm 스타일)
          Consumer<TimerProvider>(
            builder: (context, timerProvider, child) {
              // 주간 합계(미래 날짜 제외)
              final totalMinutes = days.fold<int>(0, (sum, d) {
                final cellDate = _dateOfDayInSelectedWeek(d);
                if (_isFutureDate(cellDate)) return sum;
                final minutes =
                    (timerProvider.weeklyStudy[d] ?? Duration.zero).inMinutes;
                return sum + minutes;
              });

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 요일 헤더
                  Row(
                    children: days
                        .map(
                          (d) => Expanded(
                            child: Center(
                              child: Text(d,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600)),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 8),

                  // 값 칩들
                  Row(
                    children: days.map((d) {
                      final cellDate = _dateOfDayInSelectedWeek(d);
                      final isToday = _strip(cellDate) == _strip(DateTime.now());
                      final isFuture = _isFutureDate(cellDate);

                      final minutes = (timerProvider.weeklyStudy[d] ??
                              Duration.zero)
                          .inMinutes;
                      final text = isFuture ? '-' : _fmtMinutes(minutes);

                      return Expanded(
                        child: Container(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 4),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: isToday
                                ? Colors.blue.withOpacity(0.08)
                                : const Color(0xFFF7F9FC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isToday
                                  ? Colors.blue.shade200
                                  : Colors.grey.shade300,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              text,
                              style: TextStyle(
                                fontWeight:
                                    isToday ? FontWeight.w700 : FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 10),

                  // 주간 합계
                  Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5FF),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Text('합계: ${_fmtMinutes(totalMinutes)}',
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 24),

          // 학습 유형 분석하기 버튼 (원본 기능 유지)
          Center(
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const StudyTypePage()),
                );
              },
              icon: const Icon(Icons.analytics),
              label: const Text('학습 유형 분석하기'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigoAccent,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String formatMinutes(int minutes) {
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    return '${hours}h ${mins}m';
  }

  int _calculateWeekOffsetFromToday(DateTime selected) {
    final today = DateTime.now();
    final startOfTodayWeek = today.subtract(Duration(days: today.weekday - 1));
    final startOfSelectedWeek =
        selected.subtract(Duration(days: selected.weekday - 1));
    return startOfSelectedWeek.difference(startOfTodayWeek).inDays ~/ 7;
  }

  Future<void> fetchUserProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final accessToken = prefs.getString('accessToken');
      if (accessToken == null) return;

      final response = await http.get(
        Uri.parse('${Env.baseUrl}/user/profile'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json; charset=UTF-8',
        },
      );

      if (response.statusCode == 200) {
        final decodedBody = utf8.decode(response.bodyBytes);
        final data = json.decode(decodedBody);
        setState(() {
          name = data['profile']?['name'] ?? '';
          email = data['profile']?['email'] ?? '';
          loginId = data['login_id'] ?? '';
          phone = data['phone'] ?? '';
          weeklyStudyTime = {
            '월': '${data['study_time_mon'] ?? 0}분',
            '화': '${data['study_time_tue'] ?? 0}분',
            '수': '${data['study_time_wed'] ?? 0}분',
            '목': '${data['study_time_thu'] ?? 0}분',
            '금': '${data['study_time_fri'] ?? 0}분',
            '토': '${data['study_time_sat'] ?? 0}분',
            '일': '${data['study_time_sun'] ?? 0}분',
          };
        });
      } else {
        print('프로필 불러오기 실패: ${response.statusCode}, ${response.body}');
      }
    } catch (e) {
      print('예외 발생: $e');
    }
  }
}

typedef MyPageState = _MyPageState;

/// ─────────────────────────────────────────────────────────────
/// 팝오버 본문 (마이페이지) — 전체보기 시 호스트 컨텍스트 사용
/// ─────────────────────────────────────────────────────────────
class _MyPageNotificationsPopoverBody extends StatelessWidget {
  final void Function(bool refresh) onClose;
  final BuildContext hostContext; // 페이지 컨텍스트

  const _MyPageNotificationsPopoverBody({
    super.key,
    required this.onClose,
    required this.hostContext,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<AppNotification>>(
      future: NotificationService.instance.fetchNotifications(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox(
            width: 360,
            height: 520,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return SizedBox(
            width: 360,
            height: 520,
            child: Center(child: Text('불러오기 실패: ${snapshot.error}')),
          );
        }

        final list = (snapshot.data ?? <AppNotification>[]);
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt)); // 최신순

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
                        await NotificationService.instance.markAllAsRead();
                        onClose(true);
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
                child: list.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('알림이 없어요.'),
                        ),
                      )
                    : ListView.separated(
                        padding: EdgeInsets.zero,
                        itemCount: list.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1),
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
                              color: n.isRead
                                  ? Colors.grey
                                  : const Color(0xFF004377),
                            ),
                            title: Text(
                              n.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: n.isRead
                                    ? FontWeight.w500
                                    : FontWeight.w800,
                              ),
                            ),
                            subtitle: Text(
                              n.body,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: n.isRead
                                ? null
                                : const Icon(
                                    Icons.brightness_1,
                                    size: 8,
                                    color: Colors.redAccent,
                                  ),
                            onTap: () async {
                              if (!n.isRead) {
                                await NotificationService.instance
                                    .markAsRead(n.id);
                              }
                              onClose(true); // 닫으면서 배지 갱신
                            },
                          );
                        },
                      ),
              ),

              // 하단 "전체 보기" — 팝오버 닫힌 다음 프레임에 페이지 컨텍스트로 이동
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(
                      right: 8, left: 8, top: 6, bottom: 8),
                  child: TextButton.icon(
                    onPressed: () async {
                      onClose(false); // 먼저 팝오버 닫기
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
