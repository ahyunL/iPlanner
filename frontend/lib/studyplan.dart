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

final TextEditingController fieldController = TextEditingController();         // 시험 분야
final TextEditingController testNameController = TextEditingController();      // 시험 이름
final TextEditingController materialNameController = TextEditingController();  // 자료명
final TextEditingController customTypeController = TextEditingController();    // 사용자 입력 유형
final List<Map<String, dynamic>> timeOptions = [
  {'label': '5분', 'value': 5},
  {'label': '10분', 'value': 10},
  {'label': '15분', 'value': 15},
  {'label': '30분', 'value': 30},
  {'label': '45분', 'value': 45},
  {'label': '1시간', 'value': 60},
  {'label': '1시간 10분', 'value': 70},
  {'label': '1시간 20분', 'value': 80},
  {'label': '1시간 30분', 'value': 90},
  {'label': '1시간 40분', 'value': 100},
  {'label': '1시간 50분', 'value': 110},
  {'label': '2시간', 'value': 120},
];
int selectedTime = 60;


DateTime? testDate;                 // 시험 날짜
DateTime _focusedTestDay = DateTime.now();  // 시험 달력 포커스

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
  if (token == null) {
    print('accessToken 없음');
    return;
  }

  final response = await http.get(
    Uri.parse('http://localhost:8000/subject/list'),
    headers: {'Authorization': 'Bearer $token'},
  );

  if (response.statusCode == 200) {
    final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
if (!mounted) return; 

    setState(() {
      subjects = data.cast<Map<String, dynamic>>();
      _tabController = TabController(length: subjects.length + 1, vsync: this);
    });
  } else {
    print('subject 불러오기 실패: ${response.statusCode}');
  }
}

  Future<void> saveDataToDB() async {
    final prefs = await SharedPreferences.getInstance();
final token = prefs.getString('accessToken');
if (token == null) {
  print('accessToken 없음');
  return;
}

print('저장 요청 시작: 시험명: ${testNameController.text}, 자료 개수: ${studyMaterials.length}');

final subjectResponse = await http.post(
  Uri.parse('http://localhost:8000/subject/'),
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

if (subjectResponse.statusCode != 200) {
   print('subject 저장 실패: ${subjectResponse.body}');
  return;
}

final subjectId = jsonDecode(subjectResponse.body)['subject_id'];
print('subject 저장 성공. ID: $subjectId');
print('studyMaterials.length: ${studyMaterials.length}');
print('studyMaterials 내용: $studyMaterials');

for (int i = 0; i < studyMaterials.length; i++) {
  final material = studyMaterials[i];
  final response = await http.post(
    Uri.parse('http://localhost:8000/row-plan/'),
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

  print("[$i] row_plan 저장 응답: ${response.statusCode}");
  print("[$i] 응답 내용: ${response.body}");
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
  Uri.parse('http://localhost:8000/plan/schedule'),
  headers: {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $token',
  },
);

    Navigator.of(context).pop(); // 로딩창 닫기

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
  Uri.parse('http://localhost:8000/subject/delete-all'),
  headers: {
    'Authorization': 'Bearer $token',
  },
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
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
             const Text('시험 정보', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
TextField(controller: fieldController, decoration: InputDecoration(labelText: '시험 분야')),
TextField(controller: testNameController, decoration: InputDecoration(labelText: '시험 이름')),
const SizedBox(height: 10),


              const Text('시험 날짜 선택', style: TextStyle(fontWeight: FontWeight.bold)),
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
              const SizedBox(height: 20),
              const Divider(),
              const Text('공부 기간 선택', style: TextStyle(fontWeight: FontWeight.bold)),
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
              const SizedBox(height: 20),
              const Divider(),
              const Text('학습 자료 추가', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              TextField(controller: materialNameController, decoration: const InputDecoration(labelText: '자료명')),

              Row(children: [
                DropdownButton<String>(
                  value: selectedType,
                  items: ['책', '인강', '직접입력'].map((type) {
                    return DropdownMenuItem(value: type, child: Text(type));
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedType = value!;
                    });
                  },
                ),
                if (selectedType == '직접입력')
                  Expanded(
                    child: TextField(controller: customTypeController, decoration: const InputDecoration(labelText: '유형 입력')),
                  ),
              ]),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  const Text('반복 횟수:  '),
                  DropdownButton<int>(
                    value: repeatCount,
                    items: List.generate(10, (index) => index + 1)
                        .map((count) => DropdownMenuItem<int>(
                              value: count,
                              child: Text('$count회'),
                            ))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        repeatCount = value!;
                      });
                    },
                  ),
                ],
              ),
               Row(
  children: [
    const Text('예상 학습 시간:  '),
    DropdownButton<int>(
      value: selectedTime,
      onChanged: (value) {
        setState(() {
          selectedTime = value!;
        });
      },
      items: timeOptions.map((option) {
        return DropdownMenuItem<int>(
          value: option['value'],
          child: Text(option['label']),
        );
      }).toList(),
    ),
  ],
),

              ElevatedButton(
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
                child: const Text('자료 추가'),
              ),
              const SizedBox(height: 10),
              ...studyMaterials.map((item) {
                return Card(
                  child: ListTile(
                    title: Text(item['row_plan_name'] ?? ''),

                    subtitle: Text('유형: ${item['type']}, 반복: ${item['repetition']}회'), 

                  ),
                );
              }),


              const SizedBox(height: 20),
              Center(
                child: SizedBox(
                  width: 200,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: saveAndRunAIAndMove,
                    child: const Text('저장하기', style: TextStyle(fontSize: 18)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: SizedBox(
                  width: 200,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: deleteAllStudyData,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    child: const Text('삭제하기', style: TextStyle(fontSize: 18)),
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
