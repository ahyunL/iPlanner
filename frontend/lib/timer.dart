// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import 'timer_provider.dart';
// import 'package:capstone_edu_app/study_session.dart';


// class TimerPage extends StatefulWidget {
//   const TimerPage({super.key});

//   @override
//   State<TimerPage> createState() => _TimerPageState();
// }



// class _TimerPageState extends State<TimerPage> {
//   bool _isInitialized = false;

//   @override
//   void didChangeDependencies() {
//     super.didChangeDependencies();
//     if (!_isInitialized) {
//       // Provider.of<TimerProvider>(context, listen: false).loadInitialTimeFromServer();
//       Provider.of<TimerProvider>(context, listen: false).restoreTimerState();
//       _isInitialized = true;
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text('타이머')),
//       body: Center(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             Consumer<TimerProvider>(
//               builder: (context, timerProvider, _) {
//                 return Text(
//                   timerProvider.formattedTime,
//                   style: const TextStyle(
//                     fontSize: 60,
//                     fontWeight: FontWeight.bold,
//                   ),
//                 );
//               },
//             ),
//             const SizedBox(height: 40),
//             Consumer<TimerProvider>(
//               builder: (context, timerProvider, _) {
//                 return IconButton(
//                   icon: Icon(
//                     timerProvider.isRunning ? Icons.pause : Icons.play_arrow,
//                     size: 48,
//                   ),
//                   onPressed: () {
//                     if (timerProvider.isRunning) {
//                       timerProvider.pause();
//                     } else {
//                       timerProvider.start();
//                     }
//                   },
//                 );
//               },
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }


import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'timer_provider.dart';
import 'package:capstone_edu_app/study_session.dart';

class TimerPage extends StatefulWidget {
  const TimerPage({super.key});

  @override
  State<TimerPage> createState() => _TimerPageState();
}

class _TimerPageState extends State<TimerPage> {
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<TimerProvider>(context, listen: false).fetchSessionsByDate(DateTime.now());
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      Provider.of<TimerProvider>(context, listen: false).restoreTimerState();
      _isInitialized = true;
    }
  }

  Widget buildTimeGrid(List<StudySession> sessions) {
    const int startHour = 0;
    const int endHour = 24;
    const double cellHeight = 24;
    const double cellWidth = 24;
    final int rows = endHour - startHour;
    final int columns = 6; // 10분 단위

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: columns * cellWidth + 60,
        child: ListView.builder(
          itemCount: rows,
          itemBuilder: (context, rowIndex) {
            final hour = startHour + rowIndex;
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 40,
                  height: cellHeight,
                  child: Center(
                    child: Text(
                      '${hour % 24}시',
                      style: const TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ),
                ),
                SizedBox(
                  width: columns * cellWidth,
                  height: cellHeight,
                  child: Stack(
                    children: [
                      Row(
                        children: List.generate(columns, (_) => Container(
                          width: cellWidth,
                          height: cellHeight,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                        )),
                      ),
                      ...sessions.map((session) {
                        final start = session.startTime;
                        final end = session.endTime;

                        if (start.hour > hour || end.hour < hour) return const SizedBox.shrink();

                        final startMinute = start.hour == hour ? start.minute : 0;
                        final endMinute = end.hour == hour ? end.minute : 60;

                        final left = (startMinute / 10) * cellWidth;
                        final width = ((endMinute - startMinute) / 10) * cellWidth;

                        return Positioned(
                          left: left,
                          top: 3,
                          child: Container(
                            width: width,
                            height: cellHeight - 6,
                            decoration: BoxDecoration(
                              color: Colors.lightBlue.shade100.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(4),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black12,
                                  blurRadius: 2,
                                  offset: Offset(1, 1),
                                )
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                )
              ],
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(title: const Text('타이머')),
      body: Consumer<TimerProvider>(
        builder: (context, timerProvider, _) {
          final sessions = timerProvider.sessionList;

          return Center( // 중앙 정렬
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720), // 화면 중앙에 너비 제한
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    /// 타이머 영역
                    Expanded(
                      flex: 1,
                      child: Container(
                        margin: const EdgeInsets.all(16),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 4,
                              offset: Offset(2, 2),
                            )
                          ],
                        ),
                        child: Column(
                          children: [
                            const SizedBox(height: 20),
                            Text(
                              timerProvider.formattedTime,
                              style: const TextStyle(fontSize: 60, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 20),
                            IconButton(
                              icon: Icon(
                                timerProvider.isRunning ? Icons.pause : Icons.play_arrow,
                                size: 48,
                              ),
                              onPressed: () {
                                if (timerProvider.isRunning) {
                                  timerProvider.pause();
                                } else {
                                  timerProvider.start();
                                }
                              },
                            ),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),

                    /// 타임 테이블 영역
                    Expanded(
                      flex: 1,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(8, 16, 16, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "오늘의 공부 세션",
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 12),
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border.all(color: Colors.grey.shade300),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: sessions.isEmpty
                                    ? const Center(child: Text("오늘 세션이 없습니다."))
                                    : buildTimeGrid(sessions),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
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