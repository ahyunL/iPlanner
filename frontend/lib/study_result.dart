// study_result.dart
import 'env.dart'; 
import 'package:flutter/material.dart';

class StudyResultPage extends StatefulWidget {
  const StudyResultPage({super.key});

  @override
  State<StudyResultPage> createState() => _StudyResultPageState();
}

class _StudyResultPageState extends State<StudyResultPage> {
  List<bool> checkedList = [false, false];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      //appBar: AppBar(title: const Text(' ')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSubjectCard(),
            const Spacer(),
            Center(
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 40),
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    backgroundColor: Colors.purple.shade50,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(40),
                    ),
                    elevation: 4,
                  ),
                  child: const Text(
                    '학습 완료',
                    style: TextStyle(color: Colors.purple),
                  ),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildSubjectCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Chip(
            label: Text('A 과목', style: TextStyle(fontWeight: FontWeight.bold)),
            backgroundColor: Colors.white,
            side: BorderSide.none,
          ),
          const SizedBox(height: 12),
          _buildTodoItem('1주차 시청', 0),
          _buildTodoItem('2주차 시청', 1),
          const Divider(height: 24),
          Row(
            children: [
              const Icon(Icons.add, size: 20, color: Colors.purple),
              const SizedBox(width: 6),
              const Text('추가하기', style: TextStyle(fontSize: 16)),
              const Spacer(),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildTodoItem(String title, int index) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Checkbox(
        value: checkedList[index],
        onChanged: (value) {
          setState(() {
            checkedList[index] = value!;
          });
        },
      ),
      title: Text(title),
      trailing: IconButton(
        icon: const Icon(Icons.edit, color: Colors.purple),
        onPressed: () {},
      ),
    );
  }
}
