
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
import 'package:provider/provider.dart';  // 🔧 꼭 추가!
// import 'todo_provider_main.dart';
import 'todo_provider.dart';
import 'mypage.dart'; 
import 'timer.dart'; 
import 'timer_provider.dart';
import 'package:google_fonts/google_fonts.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
void main() {
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
        '/': (context) => const LoginPage(),
        '/folder': (context) => FolderHomePage(),
        '/home': (context) => const PageViewContainer(),
        '/studyplan': (context) => const StudyPlanPage(),
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

  final String baseUrl = 'http://localhost:8000';

   Future<void> refreshTodayStudyTime() async {
    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString('accessToken');
    if (accessToken == null) return;

    final response = await http.get(
      Uri.parse('http://localhost:8000/timer/today'),
      headers: {
        'Authorization': 'Bearer $accessToken',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      setState(() {
        todayMinutes = data['today_minutes']; // 도넛에 쓰이는 값
      });
    }
  }


  @override
  void initState() {
    super.initState();
    fetchAllData();

    // TodoProvider 오늘 투두 그룹핑
    Future.microtask(() {
      Provider.of<TodoProvider>(context, listen: false).fetchTodayTodosGrouped();

      // TimerProvider에서 도넛용 공부 시간 로딩
      Provider.of<TimerProvider>(context, listen: false).loadWeeklyStudyFromServer();
    });
  }

  Future<Map<String, String>> _headers() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken');
    if (token == null || token.isEmpty) {
      print('accessToken 없음!');
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
    final res = await http.get(Uri.parse('$baseUrl/plan/today?date=${DateFormat('yyyy-MM-dd').format(DateTime.now())}'), headers: headers);
    if (res.statusCode == 200) {
      final decoded = utf8.decode(res.bodyBytes); // UTF-8 명시적 디코딩
      final List data = json.decode(decoded);
      setState(() {
        todayTodos = data.map((e) => e as Map<String, dynamic>).toList();
      });
    } else {
      print('fetchTodayTodos 실패: ${res.statusCode}');
    }
  }

  Future<void> fetchWeeklyTodos() async {
    final headers = await _headers();
    final now = DateTime.now();
    final start = now.subtract(Duration(days: now.weekday - 1));
    final end = start.add(const Duration(days: 6));
    final res = await http.get(Uri.parse('$baseUrl/plan/weekly?start=${DateFormat('yyyy-MM-dd').format(start)}&end=${DateFormat('yyyy-MM-dd').format(end)}'), headers: headers);
    if (res.statusCode == 200) {
      final decoded = utf8.decode(res.bodyBytes); // UTF-8 명시적 디코딩
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
            entry.key: List<bool>.generate(entry.value.length, (i) => entry.value[i]['complete'] ?? false),
        };
      });
    } else {
      print('fetchWeeklyTodos 실패: ${res.statusCode}');
    }
  }

  Future<void> markComplete(int planId) async {
    final headers = await _headers();
    await http.patch(Uri.parse('$baseUrl/plan/$planId/complete'), headers: headers);
    await fetchWeeklyTodos();
    await fetchTodayTodos();
  }

  Future<void> toggleComplete(int planId, bool newValue) async {
    final headers = await _headers();

    final res = await http.patch(
      Uri.parse('$baseUrl/plan/$planId/complete'),
      headers: headers,
      body: json.encode({"complete": newValue}),
    );

    if (res.statusCode == 200) {
      await Provider.of<TodoProvider>(
        navigatorKey.currentContext!,
        listen: false,
      ).fetchTodayTodosGrouped(); 

      await fetchTodayTodos();      // 오늘 투두 → 도넛 계산용
      await fetchWeeklyTodos();     // 주간 투두 → UI용
      await fetchCalendarEvents();  // 캘린더 이벤트 반영
      setState(() {});              // 전체 UI 갱신
    } else {
      print('❌ complete 변경 실패: ${res.statusCode}');
    }
  }



  Future<void> fetchTimers() async {
    final headers = await _headers();
    final todayRes = await http.get(Uri.parse('$baseUrl/timer/today'), headers: headers);
    final weeklyRes = await http.get(Uri.parse('$baseUrl/timer/weekly'), headers: headers);

    if (todayRes.statusCode == 200 && weeklyRes.statusCode == 200) {

      final todayDecoded = json.decode(utf8.decode(todayRes.bodyBytes));
      final weeklyDecoded = json.decode(utf8.decode(weeklyRes.bodyBytes));

      setState(() {
        todayMinutes = todayDecoded['today_minutes'] ?? 0;
        weeklyMinutes = weeklyDecoded['weekly_minutes'] ?? 0;
      });
    } else {
      print('fetchTimers 실패: ${todayRes.statusCode}, ${weeklyRes.statusCode}');
    }
}


  Future<void> fetchUserStudyTime() async {
    final headers = await _headers();
    final res = await http.get(Uri.parse('$baseUrl/user/study-time'), headers: headers);
    if (res.statusCode == 200) {
    final decoded = utf8.decode(res.bodyBytes);
      setState(() {
        userStudyTime = Map<String, int>.from(json.decode(decoded));
      });
    } else {
      print('fetchUserStudyTime 실패: ${res.statusCode}');
    }
  }



  Future<void> fetchCalendarEvents() async {
    final headers = await _headers();
    final formatter = DateFormat('yyyy-MM-dd');

    final year = _focusedDay.year;
    final month = _focusedDay.month;
    final firstDay = DateTime(year, month, 1);
    final lastDay = DateTime(year, month + 1, 0); // 마지막 날 자동 계산

    // 월 전체 날짜 생성
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

          events[dateKey] = todos
              .map((e) => '${e['subject'] ?? '무제'}: ${e['plan_name'] ?? '무제'}')
              .toList();

          eventDataMap[dateKey] = todos;
        }
      } else {
        print(' [$formattedDate] 이벤트 조회 실패: ${res.statusCode}');
      }
    }

    setState(() {
      _events = events;
      _eventDataMap = eventDataMap;
    });
  }




  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Study Manager')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTodoAndWeeklySection(),
            const SizedBox(height: 20),
            _buildTodoCard(
              title: "📅 캘린더",
              child: _buildCalendar(),
            ),
          ],
        ),
      ),
    );
  }





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
              child: Consumer<TodoProvider>(
                builder: (context, todoProvider, _) {
                  final grouped = todoProvider.todayTodosGrouped;

                  if (grouped.isEmpty) {
                    return const SizedBox(
                      height: 100, // 주간 카드와 동일한 높이로 맞춤
                      child: Center(
                        child: Text(
                          "오늘은 계획된 Todo가 없습니다!",
                          style: TextStyle(fontSize: 14),
                        ),
                      ),
                    );
                  }

                  return Column(
                    children: grouped.entries.map(
                      (entry) => ExpansionTile(
                        title: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.bold)),
                        children: entry.value.map((todo) => _buildStyledTodoTile(todo)).toList(),
                      ),
                    ).toList(),
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
    print('todayTodos length: ${todayTodos.length}');
    print('todayTodos: $todayTodos');

    final totalPlannedTime = todayTodos
        .map((todo) => todo['plan_time'] ?? 0)
        .fold<int>(0, (a, b) => a + (b as num).toInt());

    final completedTime = todayTodos
        .where((todo) => todo['complete'] == true || todo['complete'] == 1)
        .map((todo) => todo['plan_time'] ?? 0)
        .fold<int>(0, (a, b) => a + (b as num).toInt());

    print('totalPlannedTime: $totalPlannedTime');
    print('completedTime: $completedTime');

    if (totalPlannedTime == 0) return 0.0;

    return (completedTime / totalPlannedTime).clamp(0, 1).toDouble();
  }



  double _calculateWeeklyPercent() {
    int totalPlannedTime = 0;
    int completedTime = 0;

    bool isComplete(dynamic v) =>
        v == true || v == 1 || v == '1' || v == 'true';

    for (var subject in weeklyTodos.entries) {
      print('Subject: ${subject.key}, Todos: ${subject.value}');

      for (var todo in subject.value) {
        final rawTime = todo['plan_time'] ?? 0;
        final int time = rawTime is num ? rawTime.toInt() : int.tryParse(rawTime.toString()) ?? 0;
        final complete = isComplete(todo['complete']);

        totalPlannedTime += time;
        if (complete) completedTime += time;
      }
    }

    print('Weekly totalPlannedTime: $totalPlannedTime');
    print('Weekly completedTime: $completedTime');

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



 }

