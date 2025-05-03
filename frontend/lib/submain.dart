import 'package:flutter/material.dart';

class SubMainPage extends StatefulWidget {
  const SubMainPage({super.key});

  @override
  State<SubMainPage> createState() => _SubMainPageState();
}

class _SubMainPageState extends State<SubMainPage> {
  final Map<String, List<String>> weeklyTodos = {
    'A 과목': ['1챕터 풀기'],
    'B 과목': ['1주차 시청', '2주차 시청'],
  };

  final Map<String, List<bool>> todoChecked = {
    'A 과목': [true],
    'B 과목': [false, false],
  };

//펼쳐진 상태:true, 닫힌 상태:false
  final Map<String, bool> isExpanded = {
    'A 과목': true,
    'B 과목': true,
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ...weeklyTodos.entries.map((entry) {
              final subject = entry.key;
              final todos = entry.value;
              final checked = todoChecked[subject]!;
              final expanded = isExpanded[subject]!;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        isExpanded[subject] = !expanded;
                      });
                    },
                    icon: Icon(expanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right),
                    label: Text(subject, style: const TextStyle(fontWeight: FontWeight.bold)),
                    style: TextButton.styleFrom(backgroundColor: Colors.black87, foregroundColor: Colors.white),
                  ),
                  if (expanded)
                    Container(
                      color: Colors.grey[300],
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      child: Column(
                        children: List.generate(todos.length, (i) {
                          return Row(
                            children: [
                              Checkbox(
                                value: checked[i],
                                onChanged: (value) {
                                  setState(() {
                                    checked[i] = value ?? false;
                                  });
                                },
                              ),
                              Expanded(child: Text(todos[i])),
                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.purple),
                                onPressed: () {},
                              ),
                            ],
                          );
                        }),
                      ),
                    )
                ],
              );
            }),
            const Spacer(),
            Column(
              children: [
                ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple[100],
                    foregroundColor: Colors.black,
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(32),
                    ),
                  ),
                  child: const Text("AI 학습 계획 세우기!", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple[50],
                    foregroundColor: Colors.black87,
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(32),
                    ),
                  ),
                  child: const Text("과목 세부 사항 수정 및 추가"),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}
