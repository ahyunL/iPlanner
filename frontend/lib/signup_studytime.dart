import 'env.dart'; 
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class StudyPreferencePage extends StatefulWidget {
  final String loginId;
  const StudyPreferencePage({super.key, required this.loginId});

  @override
  State<StudyPreferencePage> createState() => _StudyPreferencePageState();
}

class _StudyPreferencePageState extends State<StudyPreferencePage> {
  final Map<String, int?> _selectedTimes = {
    '월': null,
    '화': null,
    '수': null,
    '목': null,
    '금': null,
    '토': null,
    '일': null,
  };

  final Map<int, String> timeOptions = {
    for (int i = 10; i <= 50; i += 10) i: "$i분",
    for (int i = 60; i <= 600; i += 30)
      i: i % 60 == 0
          ? "${i ~/ 60}시간"
          : "${i ~/ 60}시간 ${i % 60}분",
  };

  Future<void> _submitPreferences() async {
    final url = Uri.parse('${Env.baseUrl}/user/singup-study-time');

    final Map<String, dynamic> body = {
      'login_id': widget.loginId,
      'study_time_mon': _selectedTimes['월'] ?? 0,
      'study_time_tue': _selectedTimes['화'] ?? 0,
      'study_time_wed': _selectedTimes['수'] ?? 0,
      'study_time_thu': _selectedTimes['목'] ?? 0,
      'study_time_fri': _selectedTimes['금'] ?? 0,
      'study_time_sat': _selectedTimes['토'] ?? 0,
      'study_time_sun': _selectedTimes['일'] ?? 0,
    };

    final response = await http.put(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("공부 목표 시간이 저장되었습니다.")),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("저장 실패: ${response.body}")),
      );
    }
  }

  Widget _buildDropdownList() {
    return Column(
      children: _selectedTimes.keys.map((day) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("$day요일", style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              DropdownButtonFormField<int>(
                value: _selectedTimes[day],
                menuMaxHeight: 300,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                hint: const Text("시간 선택"),
                items: timeOptions.entries.map((entry) {
                  return DropdownMenuItem<int>(
                    value: entry.key,
                    child: Text(entry.value),
                  );
                }).toList(),
                onChanged: (val) {
                  setState(() {
                    _selectedTimes[day] = val;
                  });
                },
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("공부 목표 시간 입력"),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          children: [
            const Text(
              "🎉 회원가입을 축하드립니다!",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              "AI가 나만의 학습 계획을 만들 수 있도록\n요일별 목표 공부 시간을 선택해주세요 🙂",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: SingleChildScrollView(
                child: _buildDropdownList(),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: _submitPreferences,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[700],
                    padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: const Text("저장", style: TextStyle(color: Colors.white)),
                ),
                const SizedBox(width: 16),
                OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: const Text("건너뛰기"),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}