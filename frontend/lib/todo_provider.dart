import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

class TodoProvider with ChangeNotifier {
  Map<String, List<String>> weeklyTodos = {};
  Map<String, List<bool>> todoChecked = {};
  Map<String, List<int>> planIdMap = {};

  Future<void> fetchTodosFromDB({int retry = 0}) async {
    print("✅ fetchTodosFromDB 시작");

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken');

    if (token == null) {
      if (retry < 5) {
        print("❌ accessToken 없음 → 0.5초 뒤 재시도 ($retry)");
        await Future.delayed(const Duration(milliseconds: 500));
        return fetchTodosFromDB(retry: retry + 1);
      } else {
        print("❌ 최대 재시도 초과: SharedPreferences accessToken 없음");
        return;
      }
    }

    final url = Uri.parse("http://172.16.11.249:8000/plan/weekly-grouped");
    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    print("📡 응답 상태: ${response.statusCode}");

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;

      weeklyTodos.clear();
      todoChecked.clear();
      planIdMap.clear();

      data.forEach((subject, items) {
        final List<String> todos = [];
        final List<bool> checks = [];
        final List<int> ids = [];

        for (var item in items) {
          todos.add(item["plan_name"]);
          checks.add(item["complete"] == true);
          ids.add(item["plan_id"]);
        }

        weeklyTodos[subject] = todos;
        todoChecked[subject] = checks;
        planIdMap[subject] = ids;
      });

      print("✅ 주간 투두 불러오기 완료: $weeklyTodos");
      notifyListeners();
    } else {
      print("❌ 할 일 불러오기 실패: ${response.statusCode}, ${response.body}");
    }
  }

  // void toggleCheck(String subject, int index, bool? value) async {
  //   if (todoChecked[subject] != null && index < todoChecked[subject]!.length) {
  //     todoChecked[subject]![index] = value ?? false;
  //     notifyListeners();

  //     if (value == true) {
  //       final prefs = await SharedPreferences.getInstance();
  //       final token = prefs.getString('accessToken');
  //       final planId = planIdMap[subject]?[index];

  //       if (token != null && planId != null) {
  //         final url = Uri.parse("http://172.16.11.249:8000/plan/$planId/complete");
  //         final response = await http.patch(
  //           url,
  //           headers: {
  //             'Content-Type': 'application/json',
  //             'Authorization': 'Bearer $token',
  //           },
  //         );
  //         print("📌 체크 완료 응답: ${response.statusCode}");
  //       }
  //     }
  //   }
  // }


  void toggleCheck(String subject, int index, bool? value) async {
    if (todoChecked[subject] != null && index < todoChecked[subject]!.length) {
      todoChecked[subject]![index] = value ?? false;
      notifyListeners();  // ✅ UI 업데이트

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('accessToken');
      final planId = planIdMap[subject]?[index];

      if (token != null && planId != null) {
        final url = Uri.parse("http://172.16.11.249:8000/plan/$planId/complete");
        final response = await http.patch(
          url,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({"complete": value ?? false}),  // ✅ True/False 반영
        );
        print("📌 체크 변경 응답: ${response.statusCode}");

        // ✅ 최신 데이터 동기화 (퍼센트 업데이트까지 포함)
        await fetchTodosFromDB();
      }
    }
  }


  void updateTodo(String subject, int index, String newText) {
    if (weeklyTodos[subject] != null && index < weeklyTodos[subject]!.length) {
      weeklyTodos[subject]![index] = newText;
      notifyListeners();
    }
  }

  void addTodo(String subject, String newText) {
    weeklyTodos.putIfAbsent(subject, () => []);
    todoChecked.putIfAbsent(subject, () => []);
    planIdMap.putIfAbsent(subject, () => []);

    weeklyTodos[subject]!.add(newText);
    todoChecked[subject]!.add(false);
    planIdMap[subject]!.add(-1); // 임시 plan_id
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
    notifyListeners();
  }
}
