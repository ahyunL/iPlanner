

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
  bool isLoading = true;

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
          isLoading = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final todoProvider = Provider.of<TodoProvider>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('')),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : todoProvider.weeklyTodos.isEmpty
              ? _buildNoDataMessage(context)
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    ...todoProvider.weeklyTodos.entries.map((entry) {
                      final subject = entry.key;
                      final todos = entry.value ?? [];
                      final checked = todoProvider.todoChecked[subject] ?? List.filled(todos.length, false);
                      final expanded = isExpanded[subject] ?? true;

                      return Card(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        elevation: 2,
                        child: ExpansionTile(
                          title: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('$subject (${todos.length}개)', style: const TextStyle(fontWeight: FontWeight.bold)),
                              IconButton(
                                icon: const Icon(Icons.delete_forever, color: Colors.redAccent),
                                onPressed: () => _confirmDeleteSubject(subject),
                              ),
                            ],
                          ),
                          initiallyExpanded: expanded,
                          onExpansionChanged: (bool expandedState) {
                            setState(() {
                              isExpanded[subject] = expandedState;
                            });
                          },
                          children: todos.asMap().entries.map((entryItem) {
                            final i = entryItem.key;
                            final todoItem = entryItem.value;
                            final String todoText = todoItem['text']?.toString() ?? '';
                            final String planDate = todoItem['plan_date']?.toString() ?? '';
                            final planTimeRaw = todoItem['plan_time'];
                            final int? planTime = planTimeRaw is int ? planTimeRaw : int.tryParse(planTimeRaw?.toString() ?? '');
                            final bool isChecked = checked.length > i ? checked[i] : false;

                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  border: Border.all(color: Colors.grey.shade300),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Checkbox(
                                      value: isChecked,
                                      onChanged: (value) {
                                        todoProvider.toggleCheck(subject, i, value);
                                      },
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  todoText,
                                                  style: TextStyle(
                                                    fontSize: 15,
                                                    color: isChecked ? Colors.grey : Colors.black,
                                                    decoration: isChecked ? TextDecoration.lineThrough : null,
                                                  ),
                                                ),
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.delete_outline, color: Colors.grey),
                                                onPressed: () => _confirmDeletePlan(todoItem['plan_id']),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              const Icon(Icons.calendar_today, size: 16, color: Colors.blueGrey),
                                              const SizedBox(width: 6),
                                              GestureDetector(
                                                onTap: () async {
                                                  final selectedDate = await showDatePicker(
                                                    context: context,
                                                    initialDate: DateTime.tryParse(planDate) ?? DateTime.now(),
                                                    firstDate: DateTime(2020),
                                                    lastDate: DateTime(2030),
                                                  );
                                                  if (selectedDate != null) {
                                                    setState(() {
                                                      todoItem['plan_date'] = selectedDate.toIso8601String().split('T')[0];
                                                    });
                                                  }
                                                },
                                                child: Text(planDate, style: const TextStyle(color: Colors.blueGrey)),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              const Icon(Icons.access_time, size: 16, color: Colors.blueGrey),
                                              const SizedBox(width: 6),
                                              DropdownButton<int>(
                                                value: planTime,
                                                onChanged: (value) {
                                                  setState(() {
                                                    todoItem['plan_time'] = value;
                                                  });
                                                },
                                                items: [
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
                                                ].map((item) {
                                                  return DropdownMenuItem<int>(
                                                    value: item['value'] as int,
                                                    child: Text(item['label'].toString()),
                                                  );
                                                }).toList(),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      );
                    }),
                    const SizedBox(height: 24),
                    Center(
                      child: Column(
                        children: [
                          OutlinedButton.icon(
                            icon: const Icon(Icons.auto_awesome),
                            label: const Text("AI 학습 계획 세우기!", style: TextStyle(fontWeight: FontWeight.bold)),
                            onPressed: _handleScheduleAI,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF004377),
                              side: const BorderSide(color: Color(0xFF004377), width: 2),
                              minimumSize: const Size(300, 50),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: 300,
                            height: 50,
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.edit_note),
                              label: const Text('과목 추가 및 수정', style: TextStyle(fontWeight: FontWeight.bold)),
                              onPressed: () => Navigator.pushNamed(context, '/studyplan'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF004377),
                                side: const BorderSide(color: Color(0xFF004377), width: 2),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
    );
  }

  Future<void> _confirmDeleteSubject(String subject) async {
    final todoProvider = Provider.of<TodoProvider>(context, listen: false);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('과목 삭제'),
        content: const Text('정말 이 과목과 관련된 모든 계획을 삭제하시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('삭제')),
        ],
      ),
    );

    if (confirmed == true) {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('accessToken');
      final subjectId = todoProvider.subjectIds[subject.trim()];
      print("🧪 삭제 요청한 subject: '$subject'");
      print("🧪 등록된 subjectIds 키 목록: ${todoProvider.subjectIds.keys}");
      print("🧪 매칭된 subjectId: $subjectId");

      if (token != null && subjectId != null) {
        final response = await http.delete(
          Uri.parse('http://10.0.2.2:8000/subject/$subjectId'),
          headers: {'Authorization': 'Bearer $token'},
        );

        if (response.statusCode == 200) {
          final provider = Provider.of<TodoProvider>(context, listen: false);
          await provider.fetchTodosFromDB();
          await provider.fetchTodayTodosGrouped();   
          provider.syncCheckedWithTodos();
          setState(() {});
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('삭제 실패: ${response.body}')));
        }
      }
    }
  }

  Future<void> _confirmDeletePlan(int planId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('계획 삭제'),
        content: const Text('정말 이 계획을 삭제하시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('삭제')),
        ],
      ),
    );

    if (confirmed == true) {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('accessToken');

      if (token != null) {
        final response = await http.delete(
          Uri.parse('http://10.0.2.2:8000/plan/$planId'),
          headers: {'Authorization': 'Bearer $token'},
        );

        if (response.statusCode == 200) {
          final provider = Provider.of<TodoProvider>(context, listen: false);
          await provider.fetchTodosFromDB();
          provider.syncCheckedWithTodos();
          setState(() {});
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('삭제 실패: ${response.body}')));
        }
      }
    }
  }

  Future<void> _handleScheduleAI() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken');
    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('로그인이 필요합니다.')));
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Expanded(child: Text("AI가 계획을 배분하는 중입니다...")),
            ],
          ),
        );
      },
    );

    try {
      final response = await http.post(
        Uri.parse('http://10.0.2.2:8000/plan/schedule'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token'
        },
      );

      Navigator.pop(context);

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('AI 학습 계획이 성공적으로 저장되었습니다!')));
        final provider = Provider.of<TodoProvider>(context, listen: false);
        await provider.fetchTodosFromDB();
        provider.syncCheckedWithTodos();
        setState(() {
          for (var subject in provider.weeklyTodos.keys) {
            isExpanded[subject] = true;
          }
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('오류 발생: ${response.body}')));
      }
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('네트워크 오류: $e')));
    }
  }

  Widget _buildNoDataMessage(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.info_outline, size: 80, color: Colors.grey),
            const SizedBox(height: 20),
            const Text(
              '등록된 학습 계획이 없습니다.',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pushNamed(context, '/studyplan');
              },
              icon: const Icon(Icons.add),
              label: const Text('과목 추가하러 가기'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                backgroundColor: const Color(0xFF004377),
                foregroundColor: Colors.white,
                textStyle: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
