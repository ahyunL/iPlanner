


import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_calendar/table_calendar.dart';

class StudyPlanPage extends StatefulWidget {
  const StudyPlanPage({super.key});

  @override
  State<StudyPlanPage> createState() => _StudyPlanPageState();
}

class _StudyPlanPageState extends State<StudyPlanPage> with TickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> subjects = [];
  bool isNewSubject = true;

  final TextEditingController fieldController = TextEditingController();
  final TextEditingController testNameController = TextEditingController();
  final TextEditingController materialNameController = TextEditingController();
  final TextEditingController customTypeController = TextEditingController();

  final List<Map<String, dynamic>> timeOptions = [
    {'label': '5분', 'value': 5}, {'label': '10분', 'value': 10}, {'label': '15분', 'value': 15},
    {'label': '30분', 'value': 30}, {'label': '45분', 'value': 45}, {'label': '1시간', 'value': 60},
    {'label': '1시간 10분', 'value': 70}, {'label': '1시간 20분', 'value': 80},
    {'label': '1시간 30분', 'value': 90}, {'label': '1시간 40분', 'value': 100},
    {'label': '1시간 50분', 'value': 110}, {'label': '2시간', 'value': 120},
  ];
  int selectedTime = 60;

  DateTime? testDate;
  DateTime _focusedTestDay = DateTime.now();
  DateTime? startDate;
  DateTime? endDate;
  DateTime _focusedStudyDay = DateTime.now();

  String selectedType = '책';
  int repeatCount = 1;
  List<Map<String, dynamic>> studyMaterials = [];

  @override
  void initState() {
    super.initState();
    _loadSubjects();
  }

  Future<void> _loadSubjects() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken');
    if (token == null) return;

    final response = await http.get(
      Uri.parse('http://10.0.2.2:8000/subject/list'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
      if (!mounted) return;
      setState(() {
        subjects = data.cast<Map<String, dynamic>>();
        _tabController = TabController(length: subjects.length + 1, vsync: this);
      });
    }
  }

  Future<void> saveDataToDB() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken');
    if (token == null) return;

    final subjectResponse = await http.post(
      Uri.parse('http://10.0.2.2:8000/subject/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'field': fieldController.text,
        'test_name': testNameController.text,
        'test_date': testDate?.toIso8601String(),
        'start_date': startDate?.toIso8601String(),
        'end_date': endDate?.toIso8601String(),
      }),
    );

    if (subjectResponse.statusCode != 200) return;

    final subjectId = jsonDecode(subjectResponse.body)['subject_id'];

    for (int i = 0; i < studyMaterials.length; i++) {
      final material = studyMaterials[i];
      await http.post(
        Uri.parse('http://10.0.2.2:8000/row-plan/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'subject_id': subjectId,
          'row_plan_name': material['row_plan_name'],
          'type': material['type'],
          'repetition': material['repetition'],
          'ranking': i + 1,
          'plan_time': material['plan_time'],
        }),
      );
    }
  }

  Future<void> saveAndRunAIAndMove() async {
    await saveDataToDB();
    if (!context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        title: Text('AI 실행 중'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('AI가 계획을 생성하는 중입니다...'),
            SizedBox(height: 20),
            CircularProgressIndicator(),
          ],
        ),
      ),
    );

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken');
    if (token == null) return;

    final response = await http.post(
      Uri.parse('http://10.0.2.2:8000/plan/schedule'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    Navigator.of(context).pop();

    if (response.statusCode == 200 && context.mounted) {
      Navigator.pushReplacementNamed(context, '/home');
    } else if (context.mounted) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('실패'),
          content: Text('AI 계획 생성 실패: ${response.body}'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('확인')),
          ],
        ),
      );
    }
  }

  Future<void> deleteAllStudyData() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken');
    if (token == null) return;

    final response = await http.delete(
      Uri.parse('http://10.0.2.2:8000/subject/delete-all'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      setState(() {
        studyMaterials.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: subjects.length + 1,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('학습 계획 입력'),
          bottom: subjects.isNotEmpty
              ? TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  labelColor: Colors.blue,
                  unselectedLabelColor: Colors.black,
                  indicatorColor: Colors.transparent,
                  onTap: (index) {
                    if (index == subjects.length) {
                      setState(() {
                        isNewSubject = true;
                        fieldController.clear();
                        testNameController.clear();
                        testDate = null;
                        startDate = null;
                        endDate = null;
                        studyMaterials.clear();
                      });
                    } else {
                      final subject = subjects[index];
                      setState(() {
                        isNewSubject = false;
                        fieldController.text = subject['field'];
                        testNameController.text = subject['test_name'];
                        testDate = DateTime.parse(subject['test_date']);
                        startDate = DateTime.parse(subject['start_date']);
                        endDate = DateTime.parse(subject['end_date']);
                      });
                    }
                  },
                  tabs: [
                    ...subjects.map((subj) => Tab(text: subj['test_name'])),
                    const Tab(icon: Icon(Icons.add)),
                  ],
                )
              : null,
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: ListView(
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('시험 정보', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),  
                      TextField(
                        controller: fieldController,
                        decoration: const InputDecoration(labelText: '시험 분야'),
                      ),
                      const SizedBox(height: 12), 
                      TextField(
                        controller: testNameController,
                        decoration: const InputDecoration(labelText: '시험 이름'),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('시험 날짜 선택', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      TableCalendar(
                        firstDay: DateTime.utc(2023, 1, 1),
                        lastDay: DateTime.utc(2030, 12, 31),
                        focusedDay: _focusedTestDay,
                        selectedDayPredicate: (day) => isSameDay(testDate, day),
                        onDaySelected: (selectedDay, focusedDay) {
                          setState(() {
                            testDate = selectedDay;
                            _focusedTestDay = focusedDay;
                          });
                        },
                        calendarFormat: CalendarFormat.month,
                        rowHeight: 38,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('공부 기간 선택', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      TableCalendar(
                        firstDay: DateTime.utc(2023, 1, 1),
                        lastDay: DateTime.utc(2030, 12, 31),
                        focusedDay: _focusedStudyDay,
                        rangeStartDay: startDate,
                        rangeEndDay: endDate,
                        rangeSelectionMode: RangeSelectionMode.toggledOn,
                        onDaySelected: (selectedDay, focusedDay) {
                          setState(() {
                            _focusedStudyDay = focusedDay;
                            if (startDate != null && endDate == null && selectedDay.isAfter(startDate!)) {
                              endDate = selectedDay;
                            } else {
                              startDate = selectedDay;
                              endDate = null;
                            }
                          });
                        },
                        onPageChanged: (focusedDay) {
                          _focusedStudyDay = focusedDay;
                        },
                        calendarStyle: CalendarStyle(
                          rangeHighlightColor: Colors.blue.shade200,
                          withinRangeTextStyle: const TextStyle(color: Colors.white),
                          rangeStartDecoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle),
                          rangeEndDecoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle),
                        ),
                        rowHeight: 38,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '학습 자료 추가',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),

                      //자료명
                      TextField(
                        controller: materialNameController,
                        decoration: const InputDecoration(
                          labelText: '자료명',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        ),
                      ),

                      const SizedBox(height: 16),

                      //자료 유형 + 직접입력
                      Row(
                        children: [
                          DropdownButton<String>(
                            value: selectedType,
                            items: ['책', '인강', '직접입력']
                                .map((type) => DropdownMenuItem(value: type, child: Text(type)))
                                .toList(),
                            onChanged: (value) => setState(() => selectedType = value!),
                          ),
                          const SizedBox(width: 12),
                          if (selectedType == '직접입력')
                            Expanded(
                              child: TextField(
                                controller: customTypeController,
                                decoration: const InputDecoration(
                                  labelText: '유형 입력',
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                ),
                              ),
                            ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      //반복 횟수 + 예상 시간
                      Row(
                        children: [
                          const Text('반복 횟수:'),
                          const SizedBox(width: 8),
                          DropdownButton<int>(
                            value: repeatCount,
                            items: List.generate(10, (i) => DropdownMenuItem(value: i + 1, child: Text('${i + 1}회'))),
                            onChanged: (val) => setState(() => repeatCount = val!),
                          ),
                          const SizedBox(width: 24),
                          const Text('예상 시간:'),
                          const SizedBox(width: 8),
                          DropdownButton<int>(
                            value: selectedTime,
                            items: timeOptions.map((opt) {
                              return DropdownMenuItem<int>(
                                value: opt['value'] as int,
                                child: Text(opt['label']),
                              );
                            }).toList(),
                            onChanged: (val) => setState(() => selectedTime = val!),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // 가운데 버튼
                      Center(
                        child: ElevatedButton(
                          onPressed: () {
                            final type = selectedType == '직접입력' ? customTypeController.text : selectedType;
                            setState(() {
                              studyMaterials.add({
                                'row_plan_name': materialNameController.text,
                                'type': type,
                                'repetition': repeatCount,
                                'plan_time': selectedTime,
                              });
                              materialNameController.clear();
                              customTypeController.clear();
                              selectedType = '책';
                              repeatCount = 1;
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF004377),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                          ),
                          child: const Text('자료 추가'),
                        ),
                      ),
                      if (studyMaterials.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        const Text(
                          '추가된 자료 목록',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        ...studyMaterials.map((item) {
                          return Card(
                            child: ListTile(
                              title: Text(item['row_plan_name'] ?? ''),
                              subtitle: Text('유형: ${item['type']}, 반복: ${item['repetition']}회, 시간: ${item['plan_time']}분'),
                            ),
                          );
                        }).toList(),
                      ],

                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: saveAndRunAIAndMove,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    ),
                    child: const Text('저장하기', style: TextStyle(fontSize: 16)),
                  ),
                  ElevatedButton(
                    onPressed: deleteAllStudyData,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    ),
                    child: const Text('삭제하기', style: TextStyle(fontSize: 16)),
                  ),
                ],
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
