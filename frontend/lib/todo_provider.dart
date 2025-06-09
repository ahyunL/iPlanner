
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

class TodoProvider with ChangeNotifier {
  Map<String, List<Map<String, dynamic>>> weeklyTodos = {};
  Map<String, List<bool>> todoChecked = {};
  Map<String, List<int>> planIdMap = {};

  // 오늘 할 일 관련
  Map<String, List<Map<String, dynamic>>> todayTodosGrouped = {};
  Map<int, bool> todayCheckedMap = {};

  // -------------------- 오늘 할 일 관련 -------------------- //

  void groupTodayTodosBySubject(List<Map<String, dynamic>> rawTodos) {
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (var todo in rawTodos) {
      final subject = todo['subject'] ?? '기타';
      grouped.putIfAbsent(subject, () => []).add(todo);
    }
    todayTodosGrouped = grouped;
    notifyListeners();
  }

  Future<void> fetchTodayTodosGrouped() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken');
    if (token == null) return;

    final today = DateTime.now();
    final todayStr = "${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";

    final response = await http.get(
      Uri.parse("http://localhost:8000/plan/by-date-with-subject?date=$todayStr"),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final data = json.decode(utf8.decode(response.bodyBytes)) as List;
      groupTodayTodosBySubject(data.cast<Map<String, dynamic>>());

      todayCheckedMap.clear();
      for (var todo in data) {
        final int planId = todo['plan_id'];
        final bool isChecked = todo['complete'] ?? false;
        todayCheckedMap[planId] = isChecked;
      }

      notifyListeners();
    } else {
      print("오늘 할 일 불러오기 실패: ${response.statusCode}");
    }
  }

  Future<void> toggleTodayCheck(int planId, bool value) async {
    todayCheckedMap[planId] = value;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken');
    if (token == null) return;

    final url = Uri.parse("http://localhost:8000/plan/$planId/complete");
    final response = await http.patch(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({"complete": value}),
    );

    if (response.statusCode == 200) {
      print("체크 변경 완료: planId=$planId → $value");
    } else {
      print("체크 변경 실패: ${response.statusCode}");
    }
  }

  // -------------------- 주간 할 일 관련 -------------------- //

  Future<void> fetchTodosFromDB({int retry = 0}) async {
    print("fetchTodosFromDB 시작");

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken');

    if (token == null) {
      if (retry < 5) {
        print("accessToken 없음 → 0.5초 뒤 재시도 ($retry)");
        await Future.delayed(const Duration(milliseconds: 500));
        return fetchTodosFromDB(retry: retry + 1);
      } else {
        print("최대 재시도 초과: SharedPreferences accessToken 없음");
        return;
      }
    }

    final url = Uri.parse("http://localhost:8000/plan/weekly-grouped");
    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    print("응답 상태: ${response.statusCode}");

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;

      weeklyTodos.clear();
      todoChecked.clear();
      planIdMap.clear();

      data.forEach((subject, items) {
        final List<Map<String, dynamic>> todos = [];
        final List<bool> checks = [];
        final List<int> ids = [];

        for (var item in items) {
          todos.add({
            'text': item["plan_name"],
            'plan_time': item["plan_time"],
            'plan_date': item["plan_date"],
          });
          checks.add(item["complete"] == true);
          ids.add(item["plan_id"]);
        }

        weeklyTodos[subject] = todos;
        todoChecked[subject] = checks;
        planIdMap[subject] = ids;
      });

      print("주간 투두 불러오기 완료: $weeklyTodos");
      notifyListeners();
    } else {
      print("할 일 불러오기 실패: ${response.statusCode}, ${response.body}");
    }
  }

  void toggleCheck(String subject, int index, bool? value) async {
    if (todoChecked[subject] != null && index < todoChecked[subject]!.length) {
      todoChecked[subject]![index] = value ?? false;
      notifyListeners();

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('accessToken');
      final planId = planIdMap[subject]?[index];

      if (token != null && planId != null) {
        final url = Uri.parse("http://localhost:8000/plan/$planId/complete");
        final response = await http.patch(
          url,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({"complete": value ?? false}),
        );
        print("체크 변경 응답: ${response.statusCode}");

        await fetchTodosFromDB();
      }
    }
  }

  void updateTodo(String subject, int index, String newText) {
    if (weeklyTodos[subject] != null && index < weeklyTodos[subject]!.length) {
      weeklyTodos[subject]![index]['text'] = newText;
      notifyListeners();
    }
  }

  void updatePlanTime(String subject, int index, int newTime) {
    if (weeklyTodos[subject] != null && index < weeklyTodos[subject]!.length) {
      weeklyTodos[subject]![index]['plan_time'] = newTime;
      notifyListeners();
    }
  }

  void updatePlanDate(String subject, int index, String newDate) {
    if (weeklyTodos[subject] != null && index < weeklyTodos[subject]!.length) {
      weeklyTodos[subject]![index]['plan_date'] = newDate;
      notifyListeners();
    }
  }

  void addTodo(String subject, Map<String, dynamic> newTodo) {
    weeklyTodos.putIfAbsent(subject, () => []);
    todoChecked.putIfAbsent(subject, () => []);
    planIdMap.putIfAbsent(subject, () => []);

    weeklyTodos[subject]!.add(newTodo);
    todoChecked[subject]!.add(false);
    planIdMap[subject]!.add(-1); 
    notifyListeners();
  }

  void syncCheckedWithTodos() {
    for (var subject in weeklyTodos.keys) {
      final todos = weeklyTodos[subject] ?? [];
      final checks = todoChecked[subject] ?? [];
      todoChecked[subject] = List<bool>.generate(
        todos.length,
        (i) => i < checks.length ? checks[i] : false,
      );
    }
    notifyListeners();
  }

  void clearAll() {
    weeklyTodos.clear();
    todoChecked.clear();
    planIdMap.clear();
    todayTodosGrouped.clear();
    todayCheckedMap.clear();
    notifyListeners();
  }
}
