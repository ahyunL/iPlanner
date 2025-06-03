import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'todo_provider.dart';

class SubMainPage extends StatefulWidget {
  const SubMainPage({super.key});

  @override
  State<SubMainPage> createState() => _SubMainPageState();
}

class _SubMainPageState extends State<SubMainPage> {
  final Map<String, bool> isExpanded = {};

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      final provider = Provider.of<TodoProvider>(context, listen: false);
      await provider.fetchTodosFromDB();
      provider.syncCheckedWithTodos();
      if (mounted) {
        setState(() {
          for (var subject in provider.weeklyTodos.keys) {
            isExpanded[subject] = true;
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final todoProvider = Provider.of<TodoProvider>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('')),
      body: todoProvider.weeklyTodos.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: IntrinsicHeight(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ...todoProvider.weeklyTodos.entries.map((entry) {
                            final subject = entry.key;
                            final todos = entry.value ?? [];
                            final checked = todoProvider.todoChecked[subject] ?? List.filled(todos.length, false);
                            final expanded = isExpanded[subject] ?? true;

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
                                  style: TextButton.styleFrom(
                                    backgroundColor: Colors.black87,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                                if (expanded)
                                  Container(
                                    color: Colors.grey[300],
                                    padding: const EdgeInsets.all(12),
                                    margin: const EdgeInsets.only(bottom: 16),
                                    child: Column(
                                      children: List.generate(todos.length, (i) {
                                        if (i >= todos.length || i >= checked.length) return const SizedBox();
                                        final todoText = todos[i];
                                        final isChecked = checked[i];

                                        return Row(
                                          key: ValueKey('$subject-$i'),
                                          children: [
                                            Checkbox(
                                              value: isChecked,
                                              onChanged: (value) {
                                                todoProvider.toggleCheck(subject, i, value);
                                              },
                                            ),
                                            Expanded(
                                              child: Text(
                                                todoText,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.edit, color: Color(0xFF004377)),
                                              onPressed: () async {
                                                final newText = await showDialog<String>(
                                                  context: context,
                                                  builder: (context) {
                                                    final controller = TextEditingController(text: todoText);
                                                    return AlertDialog(
                                                      title: const Text('할 일 수정'),
                                                      content: TextField(
                                                        controller: controller,
                                                        decoration: const InputDecoration(hintText: '새로운 할 일 입력'),
                                                      ),
                                                      actions: [
                                                        TextButton(
                                                          onPressed: () => Navigator.of(context).pop(),
                                                          child: const Text('취소'),
                                                        ),
                                                        TextButton(
                                                          onPressed: () => Navigator.of(context).pop(controller.text),
                                                          child: const Text('저장'),
                                                        ),
                                                      ],
                                                    );
                                                  },
                                                );

                                                if (newText != null && newText.isNotEmpty && newText != todoText) {
                                                  todoProvider.updateTodo(subject, i, newText);
                                                }
                                              },
                                            ),
                                          ],
                                        );
                                      }),
                                    ),
                                  ),
                              ],
                            );
                          }),
                          const SizedBox(height: 24),
                          Center(
                            child: Column(
                              children: [
                                OutlinedButton(
 onPressed: () async {
  print("✅ [AI 학습 계획 버튼] 눌림");

  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('accessToken');

  print("📦 [토큰]: $token");

  if (token == null) {
    print("❌ [실패] 토큰 없음");
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('로그인이 필요합니다.')),
    );
    return;
  }

  try {
    final response = await http.post(
      Uri.parse('http://172.16.11.249:8000/plan/schedule'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token'
      },
    );

    print("✅ [요청 완료]");
    print("📡 응답 코드: ${response.statusCode}");
    final decodedBody = utf8.decode(response.bodyBytes);
print("📄 응답 디코딩: $decodedBody");


    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('AI 학습 계획이 성공적으로 저장되었습니다!')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('오류 발생: ${response.body}')),
      );
    }
  } catch (e) {
    print("❗ 예외 발생: $e");
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('네트워크 오류: $e')),
    );
  }
},

  style: OutlinedButton.styleFrom(
    foregroundColor: const Color(0xFF004377),
    side: const BorderSide(color: Color(0xFF004377), width: 2),
    minimumSize: const Size(300, 50),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(32),
    ),
  ),
  child: const Text(
    "AI 학습 계획 세우기!",
    style: TextStyle(fontWeight: FontWeight.bold),
  ),
),

                                const SizedBox(height: 12),
                                SizedBox(
                                  width: 300,
                                  height: 50,
                                  child: OutlinedButton(
                                    onPressed: () {
                                       Navigator.pushNamed(context, '/studyplan');
                                    },
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: const Color(0xFF004377),
                                      side: const BorderSide(color: Color(0xFF004377), width: 2),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(32),
                                      ),
                                    ),
                                    child: const Text(
                                      '과목 추가 및 수정',
                                      style: TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
