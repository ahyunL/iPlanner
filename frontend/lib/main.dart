// main.dart
import 'package:flutter/material.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'submain.dart'; // 서브메인페이지 분리해서 가져옴
import 'studyplan.dart';
import 'login_page.dart';
import 'folder_home_page.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

void main() => runApp(const StudyApp());

class StudyApp extends StatelessWidget {
  const StudyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      initialRoute: '/',
      routes: {
        '/': (context) => const LoginPage(),
        '/folder': (context) => FolderHomePage(),
        '/home': (context) => const PageViewContainer(),
      },
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ko', 'KR'), // 한국어
        Locale('en', 'US'), // 영어 (필수는 아님, fallback용)
      ],
      theme: ThemeData(
        scaffoldBackgroundColor: const Color.fromARGB(255, 255, 255, 255),
        primaryColor: const Color(0xFF004377),
        colorScheme: ColorScheme.fromSwatch().copyWith(
          primary: const Color(0xFF004377),
          secondary: const Color(0xFF004377),
        ),
        checkboxTheme: CheckboxThemeData(
          fillColor: MaterialStateProperty.all(const Color(0xFF004377)),
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

  @override
  Widget build(BuildContext context) {
    return PageView(
      controller: _pageController,
      children: const [HomePage(), SubMainPage(), StudyPlanPage()],
    );
  }
}

// HomePage 정의 추가

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final Map<String, List<String>> weeklyTodos = {
    'A 과목': ['1주차 시청하기'],
    'B 과목': ['1주차 시청하기', '2주차 시청하기'],
  };

  final Map<String, List<bool>> todoChecked = {
    'A 과목': [false],
    'B 과목': [false, false],
  };

  final Map<DateTime, List<String>> _events = {
    DateTime.utc(2025, 4, 8): ['AI 프로젝트 회의'],
    DateTime.utc(2025, 4, 10): ['시험 공부', '서브과목 복습'],
  };

  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();

  final List<String> todayTodos = [];

  void updateTodo(String subject, int index, String newText) {
    setState(() {
      weeklyTodos[subject]![index] = newText;
    });
  }

  void toggleCheck(String subject, int index, bool? value) {
    setState(() {
      todoChecked[subject]![index] = value ?? false;
    });
  }

  Future<void> handlePlanButtonPressed() async {
    final plan = await showDialog<String>(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('계획 입력'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(hintText: '예: 3일 안에 2강 듣기'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(controller.text),
              child: const Text('확인'),
            ),
          ],
        );
      },
    );

    if (plan != null && plan.isNotEmpty) {
      debugPrint('입력된 계획: $plan (AI에게 전달 예정)');
    }
  }

  void handleAddSubjectPressed() {
    // TODO: 과목 추가 기능 구현 예정
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
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "TODAY Todo",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TodayTodoBox(
                        todos: todayTodos,
                        onPlanPressed: handlePlanButtonPressed,
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        "WEEKLY Todo",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...weeklyTodos.entries.map(
                        (entry) => SubjectTodoCard(
                          subject: entry.key,
                          todos: entry.value,
                          checked: todoChecked[entry.key]!,
                          onEdit:
                              (index, newText) =>
                                  updateTodo(entry.key, index, newText),
                          onCheck:
                              (index, value) =>
                                  toggleCheck(entry.key, index, value),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 3,
                  child: GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    children: [
                      Column(
                        children: [
                          donutChart("%", 0.8),
                          const SizedBox(height: 4),
                          const Text(
                            "오늘 공부 달성률",
                            style: TextStyle(color: Color(0xFF004377)),
                          ),
                        ],
                      ),
                      Column(
                        children: [
                          donutChart("3H", 0.75),
                          const SizedBox(height: 4),
                          const Text(
                            "오늘 공부 시간",
                            style: TextStyle(color: Color(0xFF004377)),
                          ),
                        ],
                      ),
                      Column(
                        children: [
                          donutChart("20%", 0.2),
                          const SizedBox(height: 4),
                          const Text(
                            "주간 목표 달성률",
                            style: TextStyle(color: Color(0xFF004377)),
                          ),
                        ],
                      ),
                      Column(
                        children: [
                          donutChart("10H\\20M", 0.6),
                          const SizedBox(height: 4),
                          const Text(
                            "이번주 공부 시간",
                            style: TextStyle(color: Color(0xFF004377)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "📅 캘린더",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                TableCalendar(
                  firstDay: DateTime.utc(2020, 1, 1),
                  lastDay: DateTime.utc(2100, 12, 31),
                  focusedDay: _focusedDay,
                  calendarFormat: CalendarFormat.month,
                  headerStyle: const HeaderStyle(formatButtonVisible: false),
                  rowHeight: 70,
                  selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                  onDaySelected: (selectedDay, focusedDay) {
                    setState(() {
                      _selectedDay = selectedDay;
                      _focusedDay = focusedDay;
                    });
                  },
                  eventLoader: (day) {
                    return _events[DateTime.utc(
                          day.year,
                          day.month,
                          day.day,
                        )] ??
                        [];
                  },
                  calendarStyle: const CalendarStyle(
                    todayDecoration: BoxDecoration(
                      color: Color(0xFF004377),
                      shape: BoxShape.circle,
                    ),
                    selectedDecoration: BoxDecoration(
                      color: Color(0xFF004377),
                      shape: BoxShape.circle,
                    ),
                    markersAlignment: Alignment.bottomCenter,
                    markerDecoration: BoxDecoration(
                      color: Colors.transparent, // 점 제거
                    ),
                  ),
                  calendarBuilders: CalendarBuilders(
                    defaultBuilder: (context, day, focusedDay) {
                      final events =
                          _events[DateTime.utc(day.year, day.month, day.day)] ??
                          [];
                      return Column(
                        children: [
                          Text('${day.day}'),
                          ...events
                              .take(2)
                              .map(
                                (e) => Container(
                                  margin: const EdgeInsets.symmetric(
                                    vertical: 1,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Color(0xFFD1C4E9), // 💜 연보라 배경색
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    e,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Colors.black,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                        ],
                      );
                    },

                    todayBuilder: (context, day, focusedDay) {
                      final events =
                          _events[DateTime.utc(day.year, day.month, day.day)] ??
                          [];
                      return Column(
                        children: [
                          Container(
                            decoration: const BoxDecoration(
                              color: Color(0xFF004377),
                              shape: BoxShape.circle,
                            ),
                            padding: const EdgeInsets.all(6),
                            child: Text(
                              '${day.day}',
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          ...events
                              .take(2)
                              .map(
                                (e) => Container(
                                  margin: const EdgeInsets.symmetric(
                                    vertical: 1,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Color(0xFFB2EBF2), // 💙 오늘 일정 배경색
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    e,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Colors.black,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Center(
              child: ElevatedButton(
                onPressed: handleAddSubjectPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF004377),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: const Text('과목 추가하기'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget donutChart(String label, double percent) {
    return CircularPercentIndicator(
      radius: 60.0,
      lineWidth: 12.0,
      animation: true,
      percent: percent,
      center: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 16),
      ),
      circularStrokeCap: CircularStrokeCap.round,
      backgroundColor: Colors.grey[300]!,
      progressColor: Color(0xFF004377),
    );
  }
}

class TodayTodoBox extends StatelessWidget {
  final List<String> todos;
  final VoidCallback onPlanPressed;

  const TodayTodoBox({
    super.key,
    required this.todos,
    required this.onPlanPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      height: 200,
      width: double.infinity,
      color: Colors.grey[300],
      child: Column(
        children: [
          ElevatedButton(
            onPressed: onPlanPressed,
            child: const Text("계획 세우러 가기!"),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.builder(
              itemCount: todos.length,
              itemBuilder: (context, index) => Text(todos[index]),
            ),
          ),
        ],
      ),
    );
  }
}

class SubjectTodoCard extends StatelessWidget {
  final String subject;
  final List<String> todos;
  final List<bool> checked;
  final bool initiallyExpanded;
  final void Function(int index, String newText) onEdit;
  final void Function(int index, bool? value) onCheck;

  const SubjectTodoCard({
    super.key,
    required this.subject,
    required this.todos,
    required this.checked,
    this.initiallyExpanded = false,
    required this.onEdit,
    required this.onCheck,
  });

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      initiallyExpanded: initiallyExpanded,
      title: Text(subject, style: const TextStyle(fontWeight: FontWeight.bold)),
      backgroundColor: Colors.grey[200],
      children:
          todos
              .asMap()
              .entries
              .map(
                (entry) => ListTile(
                  leading: Checkbox(
                    value: checked[entry.key],
                    onChanged: (value) => onCheck(entry.key, value),
                  ),
                  title: Text(entry.value),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit, color: Color(0xFF004377)),
                    onPressed: () async {
                      final newText = await showDialog<String>(
                        context: context,
                        builder: (context) {
                          final controller = TextEditingController(
                            text: entry.value,
                          );
                          return AlertDialog(
                            title: const Text('할 일 수정'),
                            content: TextField(
                              controller: controller,
                              decoration: const InputDecoration(
                                hintText: '새로운 할 일 입력',
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: const Text('취소'),
                              ),
                              TextButton(
                                onPressed:
                                    () => Navigator.of(
                                      context,
                                    ).pop(controller.text),
                                child: const Text('저장'),
                              ),
                            ],
                          );
                        },
                      );

                      if (newText != null && newText != entry.value) {
                        onEdit(entry.key, newText);
                      }
                    },
                  ),
                ),
              )
              .toList(),
    );
  }
}
