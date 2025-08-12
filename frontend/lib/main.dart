import 'env.dart'; 
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:percent_indicator/percent_indicator.dart';
import 'submain.dart';
import 'studyplan.dart';
import 'login_page.dart';
import 'folder_home_page.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
// import 'todo_provider_main.dart';
import 'todo_provider.dart';
import 'mypage.dart'; 
import 'timer.dart'; 
import 'timer_provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'study_type_page.dart'; //아현 임포트 추가 
import 'data/notification_api.dart'; // 경로 맞게
import 'package:flutter/foundation.dart'; // ← 추가
// 알림 공용 서비스 & 전체보기 라우트
import 'notification_service.dart';
import 'open_notifications.dart';
import 'app_scaffold.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'env.dart'; 

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // .env 불러오기
  await dotenv.load(fileName: 'assets/.env');

  runApp(
    // 변경 후
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => TodoProvider()),
        ChangeNotifierProvider(create: (_) => TimerProvider()), // 추가됨
        // ChangeNotifierProvider(create: (_) => TodoProviderMain()),  // main.dart에서 사용
      ],
      child: const StudyApp(),
    ),
  );
}


class StudyApp extends StatelessWidget {
  const StudyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      initialRoute: '/',
      routes: {
        // '/': (context) => const LoginPage(),
        // '/folder': (context) => FolderHomePage(),
        // // '/home': (context) => const PageViewContainer(), 수민언니거 병합
        // '/home': (context) => const AppScaffold(),
        // '/studyplan': (context) => const StudyPlanPage(),

        // '/submain': (context) => const SubMainPage(), // 서브메인
        // '/mypage': (context) => const MyPage(),       // 마이페이지
        // '/timer': (context) => const TimerPage(),     // 타이머
        // '/login': (context) => const LoginPage(),  // 로그인 페이지 등록
        '/': (context) => const LoginPage(),
        '/home': (context) => const AppScaffold(),
        '/studyplan': (context) => const StudyPlanPage(), // 세부 화면만 남겨둠
        '/login': (context) => const LoginPage(),
      },
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ko', 'KR'),
        Locale('en', 'US'),
      ],
      theme: ThemeData(
        fontFamily: GoogleFonts.notoSansKr().fontFamily,
        scaffoldBackgroundColor: const Color(0xFFF5F5F5),
        primaryColor: const Color(0xFF004377),
        colorScheme: ColorScheme.fromSwatch().copyWith(
          primary: const Color(0xFF004377),
          secondary: const Color(0xFF004377),
        ),
        checkboxTheme: CheckboxThemeData(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          fillColor: MaterialStateProperty.resolveWith((states) {
            if (states.contains(MaterialState.selected)) {
              return const Color(0xFF7BA7C4); // 선택 시 테두리 색
            }
            return const Color(0xFFB0BEC5);   // 미선택 회색 테두리
          }),
          checkColor: MaterialStateProperty.all(Colors.white),
          side: const BorderSide(color: Color(0xFFB0BEC5), width: 1.5),
        ),


        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF004377),
            foregroundColor: Colors.white,
          ),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          labelStyle: TextStyle(color: Color(0xFF004377)),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Color(0xFF004377), width: 2),
          ),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Color(0xFF004377)),
          ),
        ),
      ),
    );
  }
}


class PageViewContainer extends StatefulWidget {
  const PageViewContainer({super.key});

  @override
  State<PageViewContainer> createState() => _PageViewContainerState();
}

class _PageViewContainerState extends State<PageViewContainer> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    HomePage(),
    SubMainPage(),
    TimerPage(),
    FolderHomePage(),
    MyPage(), // 
  ];

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
      _pageController.jumpToPage(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: _pages,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
        type: BottomNavigationBarType.fixed, // 아이콘 크기 변화 막기
        selectedItemColor: const Color(0xFF004377),
        unselectedItemColor: Colors.grey,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal),
        selectedIconTheme: const IconThemeData(size: 24), // 고정된 사이즈
        unselectedIconTheme: const IconThemeData(size: 24),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: '홈',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.auto_awesome),
            label: '계획',
          ),
           BottomNavigationBarItem(
            icon: Icon(Icons.access_time), // ⏱ 시계 아이콘
            label: '타이머',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.folder),
            label: '폴더',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: '마이',
          ),
        ],
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => HomePageState();
}

class HomePageState extends State<HomePage> {

 @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    Provider.of<TodoProvider>(context, listen: false).fetchTodosFromDB();
    Provider.of<TodoProvider>(context, listen: false).fetchTodayTodosGrouped();
  }
  Map<String, List<Map<String, dynamic>>> subjectGroups = {};

  List<Map<String, dynamic>> todayTodos = [];
  Map<String, List<Map<String, dynamic>>> weeklyTodos = {};
  Map<String, List<bool>> todoChecked = {};
  Map<DateTime, List<String>> _events = {};
   Map<DateTime, List<Map<String, dynamic>>> _eventDataMap = {};
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();

  int todayMinutes = 0;
  int weeklyMinutes = 0;
  Map<String, int> userStudyTime = {};

  final String baseUrl = '${Env.baseUrl}';

  // ───────── 알림(팝오버+배지) 상태 ─────────
  int _unreadCount = 0;
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

    NotificationService.instance.fetchNotifications();
  }

  OverlayEntry _buildNotifPopover() {
    return OverlayEntry(
      builder: (context) {
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () {
                  _removeNotifPopover();
                  setState(() => _isPopoverOpen = false);
                },
              ),
            ),
            CompositedTransformFollower(
              link: _bellLink,
              showWhenUnlinked: false,
              offset: const Offset(-340, 44),
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
        );
      },
    );
  }


  @override
  void initState() {
    super.initState();
    fetchAllData();

    NotificationService.instance.fetchUnreadCount();
    _unreadCount = NotificationService.instance.unreadCount.value;
    NotificationService.instance.unreadCount.addListener(_onUnreadChanged);

    Future.microtask(() {
      Provider.of<TodoProvider>(
        context,
        listen: false,
      ).fetchTodayTodosGrouped();
      Provider.of<TimerProvider>(
        context,
        listen: false,
      ).loadWeeklyStudyFromServer();
    });
  }


  void _onUnreadChanged() {
    if (!mounted) return;
    setState(() {
      _unreadCount = NotificationService.instance.unreadCount.value;
    });
  }

  @override
  void dispose() {
    NotificationService.instance.unreadCount.removeListener(_onUnreadChanged);
    _removeNotifPopover();
    super.dispose();
  }


  void _showAddPersonalScheduleDialog() {
    final TextEditingController titleController = TextEditingController();
    DateTime selectedDate = _focusedDay;
    Color selectedColor = Colors.blue;
    if (!mounted) return;  // ✅ 안전성 확보

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('개인 일정 추가'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: '일정 이름'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('날짜:'),
                  const SizedBox(width: 10),
                  TextButton(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime.now().subtract(const Duration(days: 365)),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) {
                        setState(() {
                          selectedDate = picked;
                        });
                      }
                    },
                    child: Text(DateFormat('yyyy-MM-dd').format(selectedDate)),
                  )
                ],
              ),
              Row(
                children: [
                  const Text('색상:'),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () {
                      // 나중에 색상 선택 팝업으로 확장 가능
                      setState(() {
                        selectedColor = Colors.purple; // 예시
                      });
                    },
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: selectedColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              )
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () {
                _submitPersonalSchedule(
                  titleController.text,
                  selectedDate,
                  selectedColor,
                );
                Navigator.pop(context);
              },
              child: const Text('추가'),
            ),
          ],
        );
      },
    );
  }


  Future<void> _submitPersonalSchedule(String title, DateTime date, Color color) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken');
    if (token == null) return;

    final res = await http.post(
      Uri.parse('$baseUrl/personal-schedule/'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode({
        'title': title,
        'date': DateFormat('yyyy-MM-dd').format(date),
        'color': '#${color.value.toRadixString(16).padLeft(8, '0').substring(2)}',  // ARGB → RGB hex
      }),
    );

    if (res.statusCode == 200 || res.statusCode == 201) {
      await fetchCalendarEvents(); // 캘린더 갱신
      await fetchTodayTodos();     // 오늘 할 일도 갱신
      setState(() {});
    } else {
      //print("일정 저장 실패: ${res.statusCode}");
    }
  }

  Future<void> refreshTodayStudyTime() async {
    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString('accessToken');
    if (accessToken == null) return;

    final response = await http.get(
      // 변경
      Uri.parse('$baseUrl/timer/today'),
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      setState(() {
        todayMinutes = data['today_minutes'];
      });
    }
  }



  Future<Map<String, String>> _headers() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken');
    if (token == null || token.isEmpty) {
      //print('accessToken 없음!');
      return {
        'Content-Type': 'application/json',
      };
    }
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<void> fetchAllData() async {
    await fetchTodayTodos();
    await fetchWeeklyTodos();
    await fetchTimers();
    await fetchUserStudyTime();
    await fetchCalendarEvents();
    await refreshTodayStudyTime();
  }

Future<void> fetchTodayTodos() async {
  final headers = await _headers();
  final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
  print('[TODAY] $today');

  // 1. 학습 계획 불러오기
  final planRes = await http.get(Uri.parse('$baseUrl/plan/today?date=$today'), headers: headers);
  List<Map<String, dynamic>> plans = [];

  print('[Plan StatusCode] ${planRes.statusCode}');
  if (planRes.statusCode == 200) {
    final decoded = utf8.decode(planRes.bodyBytes);
    final List data = json.decode(decoded);
    plans = data.map((e) => e as Map<String, dynamic>).toList();
    print('[Plan Data] ${plans.length}건: $plans');
  } else {
    print('[Plan Error] ${planRes.body}');
  }

  // 2. 개인 일정 불러오기
  final personalRes = await http.get(Uri.parse('$baseUrl/personal-schedule/today'), headers: headers);
  List<Map<String, dynamic>> personals = [];

  print('[Personal StatusCode] ${personalRes.statusCode}');
  if (personalRes.statusCode == 200) {
    final decoded = utf8.decode(personalRes.bodyBytes);
    final List data = json.decode(decoded);
    print('[Raw Personal Data] $data');

    personals = data.map((e) => {
      'plan_name': e['title'],
      'plan_id': null,
      'complete': false,
      'plan_time': 0,
      'subject': '📌 개인 일정',
    }).toList();

    print('[Personal Todos] ${personals.length}건: $personals');
  } else {
    print('[Personal Error] ${personalRes.body}');
  }

  // 3. 병합 및 subject 확인

// ✅ 병합된 all 리스트 기준으로 그룹핑
// 1. 개인 일정은 리스트 형태로 보관
final personalTodos = [...personals]; // subject: '📌 개인 일정'

// 2. 플랜은 과목별 그룹핑
final groupedPlans = <String, List<Map<String, dynamic>>>{};

for (var plan in plans) {
final subject = plan['subject'] ?? plan['subject_name'] ?? '기타';
  groupedPlans.putIfAbsent(subject, () => []).add(plan);
}

// 3. 전체 todayTodos는 개인 + 플랜을 시간순으로 정렬하거나 단순 병합
final all = [...personalTodos, ...plans]; // 필요 시 전체 순서도 관리 가능

// ✅ 상태 반영
setState(() {
  todayTodos = all;                  // 도넛 계산용 (flat list)
  subjectGroups = groupedPlans;     // UI 출력용 (과목별 그룹핑만)
});

}


    Future<void> fetchWeeklyTodos() async {
      final headers = await _headers();
      final now = DateTime.now();
      final start = now;
      final end = now.add(const Duration(days: 6));
      final res = await http.get(
        Uri.parse(
          '$baseUrl/plan/weekly?start=${DateFormat('yyyy-MM-dd').format(start)}&end=${DateFormat('yyyy-MM-dd').format(end)}',
        ),
        headers: headers,
      );
      if (res.statusCode == 200) {
        final decoded = utf8.decode(res.bodyBytes);
        final List data = json.decode(decoded);
        final Map<String, List<Map<String, dynamic>>> grouped = {};
        for (var item in data) {
          final subject = item['subject'] ?? '기타';
          grouped.putIfAbsent(subject, () => []).add(item);
        }
        setState(() {
          weeklyTodos = grouped;
          todoChecked = {
            for (var entry in grouped.entries)
              entry.key: List<bool>.generate(
                entry.value.length,
                (i) => entry.value[i]['complete'] ?? false,
              ),
          };
        });
      }
    }

  Future<void> markComplete(int planId) async {
    final headers = await _headers();
    await http.patch(
      Uri.parse('$baseUrl/plan/$planId/complete'),
      headers: headers,
    );
    await fetchWeeklyTodos();
    await fetchTodayTodos();
  }



  Future<void> toggleComplete(int planId, bool newValue) async {
    print('✅ toggleComplete 진입: planId=$planId, newValue=$newValue');
    final headers = await _headers();

    final res = await http.patch(
      Uri.parse('$baseUrl/plan/$planId/complete'),
      headers: headers,
      body: json.encode({"complete": newValue}),
    );

    print('🔄 PATCH 응답 상태코드: ${res.statusCode}');

    if (res.statusCode == 200) {
      print('✅ PATCH 성공, 상태 업데이트 중...');
      await Provider.of<TodoProvider>(navigatorKey.currentContext!, listen: false).fetchTodayTodosGrouped();
      await fetchTodayTodos();
      await fetchWeeklyTodos();
      await fetchCalendarEvents();
      setState(() {});
      print('📌 상태 갱신 완료');

      await createDailySummaryIfAbsent(); // 요약 먼저 생성
      await Future.delayed(const Duration(seconds: 1));

      final percent = _calculateTodayPercent();
      print('🎯 계산된 오늘 달성률: ${(percent * 100).toStringAsFixed(1)}%');

      await saveDailyAchievement(percent); // 덮어쓰기 방식 저장
      print('📡 saveDailyAchievement 호출 완료');
    } else {
      print('❌ complete 변경 실패: ${res.statusCode}');
    }
  }


  Future<void> fetchTimers() async {
    final headers = await _headers();
    final todayRes = await http.get(
      Uri.parse('$baseUrl/timer/today'),
      headers: headers,
    );
    final weeklyRes = await http.get(
      Uri.parse('$baseUrl/timer/weekly'),
      headers: headers,
    );

    if (todayRes.statusCode == 200 && weeklyRes.statusCode == 200) {
      final todayDecoded = json.decode(utf8.decode(todayRes.bodyBytes));
      final weeklyDecoded = json.decode(utf8.decode(weeklyRes.bodyBytes));

      setState(() {
        todayMinutes = todayDecoded['today_minutes'] ?? 0;
        weeklyMinutes = weeklyDecoded['weekly_minutes'] ?? 0;
      });
    }
  }

  Future<void> fetchUserStudyTime() async {
    final headers = await _headers();
    final res = await http.get(
      Uri.parse('$baseUrl/user/study-time'),
      headers: headers,
    );
    if (res.statusCode == 200) {
      final decoded = utf8.decode(res.bodyBytes);
      setState(() {
        userStudyTime = Map<String, int>.from(json.decode(decoded));
      });
    }
  }




  Future<void> fetchCalendarEvents() async {
    final headers = await _headers();
    final formatter = DateFormat('yyyy-MM-dd');

    final year = _focusedDay.year;
    final month = _focusedDay.month;
    final lastDay = DateTime(year, month + 1, 0);

    final List<DateTime> allDatesInMonth = List.generate(
      lastDay.day,
      (i) => DateTime.utc(year, month, i + 1),
    );

    Map<DateTime, List<String>> events = {};
    Map<DateTime, List<Map<String, dynamic>>> eventDataMap = {};

    for (var date in allDatesInMonth) {
      final formattedDate = formatter.format(date);
      final res = await http.get(
        Uri.parse('$baseUrl/plan/by-date-with-subject?date=$formattedDate'),
        headers: headers,
      );

      if (res.statusCode == 200) {
        final decoded = utf8.decode(res.bodyBytes);
        final List<dynamic> data = json.decode(decoded);
        final todos = data.cast<Map<String, dynamic>>();

        if (todos.isNotEmpty) {
          final dateKey = DateTime.utc(date.year, date.month, date.day);
          events[dateKey] =
              todos
                  .map(
                    (e) => '${e['subject'] ?? '무제'}: ${e['plan_name'] ?? '무제'}',
                  )
                  .toList();
          eventDataMap[dateKey] = todos;
        }
      }
    }

    setState(() {
      _events = events;
      _eventDataMap = eventDataMap;
    });
  }



  // ======================== UI ========================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // appBar: AppBar(
      //   //title: const Text('Study Manager'),
      //   actions: [
      //     Stack(
      //       clipBehavior: Clip.none,
      //       children: [
      //         CompositedTransformTarget(
      //           link: _bellLink,
      //           child: IconButton(
      //             icon: Icon(
      //               _unreadCount > 0
      //                   ? Icons.notifications
      //                   : Icons.notifications_none,
      //               color: const Color(0xFF004377),
      //             ),
      //             onPressed: _toggleNotifPopover,
      //             tooltip: '알림',
      //           ),
      //         ),
      //         if (_unreadCount > 0)
      //           Positioned(
      //             right: 6,
      //             top: 6,
      //             child: Container(
      //               padding: const EdgeInsets.symmetric(
      //                 horizontal: 6,
      //                 vertical: 2,
      //               ),
      //               decoration: BoxDecoration(
      //                 color: Colors.redAccent,
      //                 borderRadius: BorderRadius.circular(10),
      //               ),
      //               child: Text(
      //                 _unreadCount > 99 ? '99+' : '$_unreadCount',
      //                 style: const TextStyle(
      //                   color: Colors.white,
      //                   fontSize: 11,
      //                   fontWeight: FontWeight.bold,
      //                 ),
      //               ),
      //             ),
      //           ),
      //       ],
      //     ),
      //   ],
      // ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTodoAndWeeklySection(),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "📅 캘린더",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                TextButton.icon(
                  onPressed: _showAddPersonalScheduleDialog,
                  icon: const Icon(Icons.add_circle_outline, size: 18),
                  label: const Text(
                    "개인일정 추가",
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildTodoCard(title: ' ', child: _buildCalendar()),
          ],
        ),
      ),
    );
  }




 // ======= 나머지 UI/로직(변경 없음) =======
  void _showFullTodoPopup(BuildContext context, DateTime day, List<Map<String, dynamic>> initialTodos) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          builder: (context, scrollController) {
            return StatefulBuilder(
              builder: (context, setModalState) {
                // 1. 복사본 생성
                List<Map<String, dynamic>> todos = List<Map<String, dynamic>>.from(initialTodos);

                // 2. subject 기준으로 그룹핑
                final Map<String, List<Map<String, dynamic>>> groupedTodos = {};
                for (var todo in todos) {
                  final subject = todo['subject'] ?? '기타';
                  groupedTodos.putIfAbsent(subject, () => []).add(todo);
                }

                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "${day.month}월 ${day.day}일 할 일",
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 20),
                      Expanded(
                        child: ListView(
                          controller: scrollController,
                          children: groupedTodos.entries.map((entry) {
                            return ExpansionTile(
                              title: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.bold)),
                              children: entry.value.map((todo) {
                                final isComplete = todo['complete'] == true || todo['complete'] == 1;

                                return ListTile(
                                  leading: Checkbox(
                                    value: isComplete,
                                    onChanged: (val) async {
                                      if (val != null) {
                                        await toggleComplete(todo['plan_id'], val);
                                        await fetchTodayTodos();
                                        await fetchWeeklyTodos();
                                        await fetchCalendarEvents();

                                        todo['complete'] = val ? 1 : 0;
                                        setModalState(() {}); // 팝업만 새로 그림
                                      }
                                    },
                                  ),
                                  title: Text(
                                    todo['plan_name'] ?? '무제',
                                    style: TextStyle(
                                      color: isComplete ? Colors.grey : Colors.black,
                                      decoration: isComplete ? TextDecoration.lineThrough : null,
                                    ),
                                  ),
                                );
                              }).toList(),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }




  // 도넛 차트 카드 위젯
  Widget _buildDonutCard(String title, double percent, String valueText) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularPercentIndicator(
            radius: 48.0,
            lineWidth: 10.0,
            animation: true,
            percent: percent,
            center: Text(valueText, style: const TextStyle(fontSize: 14)),
            circularStrokeCap: CircularStrokeCap.round,
            backgroundColor: Colors.grey.shade300,
            progressColor: const Color(0xFF004377),
          ),
          const SizedBox(height: 20), //8
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // 카드 컴포넌트
  Widget _buildTodoCard({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title.isNotEmpty)
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          if (title.isNotEmpty)
            const SizedBox(height: 20), //12
          child,
        ],
      ),
    );
  }


  Widget _buildStyledTodoTile(Map<String, dynamic> todo) {
    final isComplete = todo['complete'] == true || todo['complete'] == 1;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isComplete ? Colors.grey.shade200 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Checkbox(
            value: isComplete,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            onChanged: (val) async {
              if (val != null) {
                await toggleComplete(todo['plan_id'], val);
                await fetchTodayTodos();
                await fetchWeeklyTodos();
                await fetchCalendarEvents();
                setState(() {});
              }
            },
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              todo['plan_name'] ?? '무제',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                decoration: isComplete ? TextDecoration.lineThrough : null,
                color: isComplete ? Colors.grey : Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }

  
Widget _buildTodoAndWeeklySection() {
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // 왼쪽: 할 일 카드들
      Expanded(
        flex: 3,
        child: Column(
          children: [
            _buildTodoCard(
              title: "오늘 할 일",
              child: Builder(
                builder: (context) {
                  if (todayTodos.isEmpty && subjectGroups.isEmpty) {
                    return const SizedBox(
                      height: 100,
                      child: Center(
                        child: Text("오늘은 계획된 Todo가 없습니다!", style: TextStyle(fontSize: 14)),
                      ),
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ✅ 1. 개인 일정만 먼저 출력
                      ...todayTodos
                          .where((todo) => todo['subject'] == '📌 개인 일정')
                          .map((todo) => _buildStyledTodoTile(todo)),

                      const SizedBox(height: 12),

                      // ✅ 2. 과목별 ExpansionTile 출력
                      ...subjectGroups.entries.map((entry) {
                        return ExpansionTile(
                          title: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.bold)),
                          children: entry.value
                              .map((todo) => _buildStyledTodoTile(todo))
                              .toList(),
                        );
                      }).toList(),
                    ],
                  );
                },
              ),
            ),

            const SizedBox(height: 20),
            _buildTodoCard(
              title: "주간 할 일",
              child: weeklyTodos.isEmpty
                  ? const SizedBox(
                      height: 100, // 높이 확보
                      child: Center(
                        child: Text("이번 주에 계획된 Todo가 없습니다!", style: TextStyle(fontSize: 14)),
                      ),
                    )
                  : Column(
                      children: weeklyTodos.entries.map(
                        (entry) => ExpansionTile(
                          title: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.bold)),
                          children: entry.value.map((todo) => _buildStyledTodoTile(todo)).toList(),
                        ),
                      ).toList(),
                    ),
            ),

          ],
        ),
      ),
      const SizedBox(width: 16),

      // 오른쪽: 학습 통계 도넛 카드 (Consumer로 연동)
      Expanded(
        flex: 2,
        child: Consumer<TimerProvider>(
          builder: (context, timer, _) {
            final today = ['월', '화', '수', '목', '금', '토', '일'][DateTime.now().weekday - 1];
            final todayStudyMin = timer.weeklyStudy[today]?.inMinutes ?? 0;
            final weeklyStudyMin = timer.weeklyStudy.values
                .fold<int>(0, (sum, d) => sum + d.inMinutes);

            double calculatePercent(int value, int goal) =>
                (value / goal).clamp(0.0, 1.0);

            String formatMinutes(int minutes) {
              final h = (minutes ~/ 60).toString();
              final m = (minutes % 60).toString().padLeft(2, '0');
              return '${h}H${m}M';
            }

            return _buildTodoCard(
              title: "학습 통계",
              child: GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1,
                children: [
                  _buildDonutCard("오늘 공부 달성률", _calculateTodayPercent(), "${(_calculateTodayPercent() * 100).toStringAsFixed(1)}%"),
                  _buildDonutCard("오늘 공부 시간", calculatePercent(todayStudyMin, 240), formatMinutes(todayStudyMin)),
                  _buildDonutCard("주간 목표 달성률", _calculateWeeklyPercent(), "${(_calculateWeeklyPercent() * 100).toStringAsFixed(1)}%"),
                  _buildDonutCard("이번주 공부 시간", calculatePercent(weeklyStudyMin, 1680), formatMinutes(weeklyStudyMin)),
                ],
              ),
            );
          },
        ),
      ),
    ],
  );
}




  String _minutesToHourMin(int minutes) {
    final h = (minutes ~/ 60).toString();
    final m = (minutes % 60).toString().padLeft(2, '0');
    return '${h}H${m}M';
  }


//현재는 계획당 시간 가중치를 두고 퍼센트 계산 중인데, 이게 별로이면, 나중에 수정 가능!
  double _calculateTodayPercent() {
    //print('todayTodos length: ${todayTodos.length}');
    //print('todayTodos: $todayTodos');

    final totalPlannedTime = todayTodos
        .map((todo) => todo['plan_time'] ?? 0)
        .fold<int>(0, (a, b) => a + (b as num).toInt());

    final completedTime = todayTodos
        .where((todo) => todo['complete'] == true || todo['complete'] == 1)
        .map((todo) => todo['plan_time'] ?? 0)
        .fold<int>(0, (a, b) => a + (b as num).toInt());

    //print('totalPlannedTime: $totalPlannedTime');
    //print('completedTime: $completedTime');

    if (totalPlannedTime == 0) return 0.0;

    return (completedTime / totalPlannedTime).clamp(0, 1).toDouble();
  }



  double _calculateWeeklyPercent() {
    int totalPlannedTime = 0;
    int completedTime = 0;

    bool isComplete(dynamic v) =>
        v == true || v == 1 || v == '1' || v == 'true';

    for (var subject in weeklyTodos.entries) {
      //print('Subject: ${subject.key}, Todos: ${subject.value}');

      for (var todo in subject.value) {
        final rawTime = todo['plan_time'] ?? 0;
        final int time = rawTime is num ? rawTime.toInt() : int.tryParse(rawTime.toString()) ?? 0;
        final complete = isComplete(todo['complete']);

        totalPlannedTime += time;
        if (complete) completedTime += time;
      }
    }

    //print('Weekly totalPlannedTime: $totalPlannedTime');
    //print('Weekly completedTime: $completedTime');

    if (totalPlannedTime == 0) return 0.0;

    return (completedTime / totalPlannedTime).clamp(0, 1).toDouble();
  }


  List<Map<String, dynamic>> getTodosForDay(DateTime day) {
    return todayTodos.where((todo) {
      final planDate = DateTime.parse(todo['plan_date']);
      return planDate.year == day.year && planDate.month == day.month && planDate.day == day.day;
    }).toList();
  }


  Widget _buildCalendarDay(DateTime day, {bool isToday = false}) {
    final dateKey = DateTime.utc(day.year, day.month, day.day);
    final events = _events[dateKey] ?? [];
    final isSelected = isSameDay(_selectedDay, day);
    final hasEvent = events.isNotEmpty;

    return GestureDetector(
      onTap: () {
        _showFullTodoPopup(context, day, _eventDataMap[dateKey] ?? []);
      },
      child: Container(
        height: 70, // 전체 셀 높이 고정
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE3F2FD) : null,
          border: isSelected
              ? Border.all(color: const Color(0xFF004377), width: 2)
              : Border.all(color: Colors.transparent),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Text(
              '${day.day}',
              style: TextStyle(
                color: isSelected
                    ? const Color(0xFF004377)
                    : isToday
                        ? const Color(0xFF004377)
                        : Colors.black,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            if (hasEvent)
              Text(
                events.first.length > 10
                    ? '${events.first.substring(0, 9)}…'
                    : events.first,
                style: const TextStyle(fontSize: 10, color: Colors.black87),
                overflow: TextOverflow.ellipsis,
              ),
            if (events.length > 1)
              Text(
                '+${events.length - 1}개 더보기',
                style: const TextStyle(fontSize: 10, color: Colors.grey),
              ),
          ],
        ),
      ),
    );
  }





  Widget _buildCalendar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TableCalendar(
        firstDay: DateTime.utc(2020, 1, 1),
        lastDay: DateTime.utc(2100, 12, 31),
        focusedDay: _focusedDay,
        onPageChanged: (focusedDay) {
          setState(() {
            _focusedDay = focusedDay;
          });
          fetchCalendarEvents(); // 새 달을 불러옴
        },
        calendarFormat: CalendarFormat.month,
        rowHeight: 80,
        headerStyle: const HeaderStyle(
          formatButtonVisible: false,
          titleCentered: true,
          titleTextStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          leftChevronIcon: Icon(Icons.chevron_left, color: Colors.black),
          rightChevronIcon: Icon(Icons.chevron_right, color: Colors.black),
        ),
        selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
        onDaySelected: (selectedDay, focusedDay) {
          final dateKey = DateTime.utc(selectedDay.year, selectedDay.month, selectedDay.day);

          setState(() {
            _selectedDay = selectedDay;
            _focusedDay = focusedDay;
          });

          _showFullTodoPopup(context, selectedDay, _eventDataMap[dateKey] ?? []);
        },
        eventLoader: (day) => _events[DateTime.utc(day.year, day.month, day.day)] ?? [],
        calendarStyle: CalendarStyle(
          todayDecoration: BoxDecoration(
            color: const Color(0xFF004377),
            shape: BoxShape.circle,
          ),
          selectedDecoration: BoxDecoration(
            // border: Border.all(color: const Color(0xFF004377), width: 2),
            // shape: BoxShape.circle,
            color: Colors.transparent, // 선택 배경 투명
            shape: BoxShape.rectangle, // 원형 제거
          ),
          todayTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          selectedTextStyle: const TextStyle(color: Color(0xFF004377), fontWeight: FontWeight.bold),
          markersAlignment: Alignment.bottomCenter,
          markerDecoration: const BoxDecoration(color: Colors.transparent),
        ),
        calendarBuilders: CalendarBuilders(
          defaultBuilder: (context, day, _) => _buildCalendarDay(day),
          todayBuilder: (context, day, _) => _buildCalendarDay(day, isToday: true),
        ),
      ),
    );
  }

  //25-08-03 민경 추가
  Future<void> saveDailyAchievement(double achievement) async {
    final headers = await _headers();
    final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

    final res = await http.post(  // ✅ POST로 변경했는지 확인
      Uri.parse('$baseUrl/study-daily/achievement'),
      headers: headers,
      body: json.encode({
        'study_date': dateStr,
        'daily_achievement': (achievement * 100).round(),  // ✅ 소수점 → 정수 %
      }),
    );

    if (res.statusCode == 200) {
      print('🎯 일일 달성률 저장 완료');
    } else {
      print('❌ 달성률 저장 실패: ${res.statusCode}');
    }
  }



  Future<void> createDailySummaryIfAbsent() async {
    final headers = await _headers();
    final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

    final res = await http.post(
      Uri.parse('$baseUrl/study-daily/auto?date=$dateStr'),
      headers: headers,
    );

    if (res.statusCode == 200) {
      print('✅ 요약 생성 완료');
    } else {
      print('❌ 요약 생성 실패: ${res.statusCode}');
    }
  }

 }


// ─────────────────────────────────────────────────────────────
// 팝오버 본문: 서버 연동 + 전체보기(호스트 컨텍스트 사용)
// ─────────────────────────────────────────────────────────────
class _NotificationsPopoverBody extends StatelessWidget {
  final void Function(bool refresh) onClose;
  final BuildContext hostContext; // ✅ 페이지 컨텍스트
  const _NotificationsPopoverBody({
    super.key,
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

        final list =
            (snapshot.data ?? <AppNotification>[]) as List<AppNotification>;
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
                          await NotificationService.instance
                              .markAllAsRead(); // 백엔드 호출 + 배지 0
                        } catch (e) {
                          debugPrint('모두 읽음 실패: $e');
                        } finally {
                          onClose(true); // 팝오버 닫고 상위에서 fetchUnreadCount 재동기화
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
                                        .markAsRead(n.id); // 읽음 + 배지 -1
                                  } catch (e) {
                                    debugPrint('읽음 처리 실패: $e');
                                  }
                                }
                                onClose(true); // 닫고 상위에서 새로고침
                              },
                            );
                          },
                        ),
              ),

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
                      onClose(false); // 팝오버 먼저 닫기
                      WidgetsBinding.instance.addPostFrameCallback((_) async {
                        await openNotifications(
                          hostContext,
                        ); // ✅ 페이지 컨텍스트로 네비게이션
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