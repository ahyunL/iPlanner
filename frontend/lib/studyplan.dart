// study_plan.dart
import 'package:flutter/material.dart';
import 'study_result.dart';


class StudyPlanPage extends StatefulWidget {
  const StudyPlanPage({super.key});

  @override
  State<StudyPlanPage> createState() => _StudyPlanPageState();
}

class _StudyPlanPageState extends State<StudyPlanPage> {
  final List<String> examTypes = ['학교 시험', '자격증', '어학 시험', '수능', '기타'];
  String selectedExamType = '학교 시험';
  DateTime? examDate;
  DateTime? studyStartDate;
  DateTime? studyEndDate;
  final TextEditingController examNameController = TextEditingController();
  final List<String> materials = ['사용자 입력', '책·인강', '개수', '챕터/강의, 주차 등등', '반복 횟수'];

  List<String> subjects = ['A 과목'];
  String selectedSubject = 'A 과목';
  final TextEditingController newMaterialController = TextEditingController();

  static const Color cream = Color(0xFFFBFCF7);
  static const Color cobaltBlue = Color(0xFF004377);

  void _addMaterial() {
    final newMaterial = newMaterialController.text.trim();
    if (newMaterial.isNotEmpty) {
      setState(() {
        materials.add(newMaterial);
        newMaterialController.clear();
      });
    }
  }

  void _navigateToResultPage() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const StudyResultPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: cream,
      appBar: AppBar(
        title: const Text('AI 학습 계획 세우기'),
        backgroundColor: cream,
        foregroundColor: cobaltBlue,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSubjectTabs(),
            const SizedBox(height: 24),
            const Text('시험 분야', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            _buildExamTypeSelector(),
            const SizedBox(height: 24),
            _buildExamNameField(),
            const SizedBox(height: 24),
            const Text('시험 날짜', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            _buildExamDatePicker(),
            const SizedBox(height: 24),
            const Text('공부기간', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            _buildStudyPeriodPicker(),
            const SizedBox(height: 32),
            const Text('사용할 학습자료 목록', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _buildMaterialsChips(),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: newMaterialController,
                    decoration: const InputDecoration(
                      hintText: '자료 이름 입력',
                      filled: true,
                      fillColor: Color(0xFFFBFCF7),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _addMaterial,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF004377),
                    foregroundColor: Color(0xFFFBFCF7),
                  ),
                  child: const Text('추가'),
                ),
              ],
            ),
            const SizedBox(height: 40),
            Center(
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _navigateToResultPage,
                    child: _roundedButton('저장하기'),
                  ),
                  const SizedBox(height: 16),
                  _roundedButton('삭제하기'),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _roundedButton(String label) {
    return Container(
      width: 280,
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: Color(0xFFFBFCF7),
        borderRadius: BorderRadius.circular(40),
        boxShadow: [
          BoxShadow(color: Colors.grey.shade300, offset: const Offset(2, 2), blurRadius: 6),
        ],
      ),
      child: Center(
        child: Text(
          label,
          style: const TextStyle(fontSize: 16, color: Color(0xFF004377)),
        ),
      ),
    );
  }

  Widget _buildSubjectTabs() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Color(0xFF004377)),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          ...subjects.map((s) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: TextButton(
                  onPressed: () {
                    setState(() {
                      selectedSubject = s;
                    });
                  },
                  child: Text(
                    s,
                    style: TextStyle(
                      fontWeight: s == selectedSubject ? FontWeight.bold : FontWeight.normal,
                      color: s == selectedSubject ? Color(0xFF004377) : Colors.black,
                    ),
                  ),
                ),
              )),
          IconButton(
            icon: const Icon(Icons.add, size: 20, color: Color(0xFF004377)),
            onPressed: () {
              setState(() {
                subjects.add('과목 ${subjects.length + 1}');
              });
            },
          )
        ],
      ),
    );
  }

  Widget _buildExamTypeSelector() {
    return Wrap(
      spacing: 12,
      children: examTypes.map((type) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Radio<String>(
            value: type,
            groupValue: selectedExamType,
            onChanged: (value) {
              setState(() {
                selectedExamType = value!;
              });
            },
            activeColor: Color(0xFF004377),
          ),
          Text(type),
        ],
      )).toList(),
    );
  }

  Widget _buildExamNameField() {
    return Row(
      children: [
        const Text('시험명', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black)),
        const SizedBox(width: 16),
        Expanded(
          child: TextField(
            controller: examNameController,
            decoration: const InputDecoration(
              hintText: '사용자 지정',
              hintStyle: TextStyle(color: Colors.grey),
              isDense: true,
              border: InputBorder.none,
            ),
            textAlign: TextAlign.start,
          ),
        ),
      ],
    );
  }

  Widget _buildExamDatePicker() {
    return CalendarDatePicker(
      initialDate: examDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      onDateChanged: (date) => setState(() => examDate = date),
    );
  }

  Widget _buildStudyPeriodPicker() {
    return CalendarDatePicker(
      initialDate: studyStartDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      onDateChanged: (date) => setState(() => studyStartDate = date),
    );
  }

  Widget _buildMaterialsChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ...materials.map((m) => Chip(
              label: Text(m),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: const BorderSide(color: Color(0xFF004377)),
              ),
              backgroundColor: Colors.transparent,
            )),
        const Chip(
          label: Text('X'),
          backgroundColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(10)),
            side: BorderSide(color: Color(0xFF004377)),
          ),
        )
      ],
    );
  }
}
