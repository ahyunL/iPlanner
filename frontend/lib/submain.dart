// ignore_for_file: use_build_context_synchronously

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
                                            final todoItem = todos[i];
                                            final String todoText = todoItem['text']?.toString() ?? '';
                                            final String planDate = todoItem['plan_date']?.toString() ?? '';
                                            final planTimeRaw = todoItem['plan_time'];
                                            final int? planTime = planTimeRaw is int ? planTimeRaw : int.tryParse(planTimeRaw?.toString() ?? '');
                                            final bool isChecked = checked[i];

                                            return Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Checkbox(
                                                      value: isChecked,
                                                      onChanged: (value) {
                                                        todoProvider.toggleCheck(subject, i, value);
                                                      },
                                                    ),
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          Text(todoText, overflow: TextOverflow.ellipsis),
                                                          const SizedBox(height: 4),
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
                                                            child: Text(
                                                              '📅 날짜: ${todoItem['plan_date']}',
                                                              style: const TextStyle(color: Colors.blueGrey),
                                                            ),
                                                          ),
                                                          const SizedBox(height: 4),
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
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 12),
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
                                        final prefs = await SharedPreferences.getInstance();
                                        final token = prefs.getString('accessToken');
                                        if (token == null) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('로그인이 필요합니다.')),
                                          );
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
                                            Uri.parse('http://localhost:8000/plan/schedule'),
                                            headers: {
                                              'Content-Type': 'application/json',
                                              'Authorization': 'Bearer $token'
                                            },
                                          );

                                          Navigator.pop(context); // 팝업 닫기

                                          if (response.statusCode == 200) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(content: Text('AI 학습 계획이 성공적으로 저장되었습니다!')),
                                            );
                                            final provider = Provider.of<TodoProvider>(context, listen: false);
                                            await provider.fetchTodosFromDB();
                                            provider.syncCheckedWithTodos();
                                            setState(() {
                                              for (var subject in provider.weeklyTodos.keys) {
                                                isExpanded[subject] = true;
                                              }
                                            });
                                          } else {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(content: Text('오류 발생: ${response.body}')),
                                            );
                                          }
                                        } catch (e) {
                                          Navigator.pop(context);
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


