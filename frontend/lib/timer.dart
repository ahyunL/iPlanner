
import 'env.dart'; 
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
    }
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      Provider.of<TimerProvider>(context, listen: false).restoreTimerState();
      _isInitialized = true;
    }
  }
  

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isWide = MediaQuery.of(context).size.width >= 900; // 넓은 화면에서 좌우 분할

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      //appBar: AppBar(title: const Text('타이머')),
      body: Consumer<TimerProvider>(
        builder: (context, timerProvider, _) {
          final sessions = timerProvider.sessionList;
          final int totalMinutes = sessions.fold(0, (sum, s) => sum + s.totalMinutes);

          // ✅ 오늘 하루(0~23시) * 6칸(10분) = 144칸 — 각 칸은 0.0~1.0 비율로 채움
          final slotFractions = _computeDailySlotFractions(sessions);

          return SingleChildScrollView(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 🕒 타이머 카드 영역 (상단 고정, 중앙 정렬, 최대너비 제한)
                      Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1000),
                          child: _TimerCard(timerProvider: timerProvider),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // 아래 영역: 좌(타임테이블) | 우(세션 리스트) — 좁으면 세로 스택
                      if (isWide)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 좌: 타임테이블 (정확히 절반)
                            Expanded(
                              flex: 1,
                              child: _TimeTableSection(
                                totalMinutes: totalMinutes,
                                slotFractions: slotFractions,
                              ),
                            ),
                            const SizedBox(width: 24),
                            // 우: 세션 리스트 (정확히 절반)
                            Expanded(
                              flex: 1,
                              child: _SessionListSection(sessions: sessions),
                            ),
                          ],
                        )
                      else
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _TimeTableSection(
                              totalMinutes: totalMinutes,
                              slotFractions: slotFractions,
                            ),
                            const SizedBox(height: 16),
                            _SessionListSection(sessions: sessions),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }
      ),
    );

  }

  // ========================= Helper methods =========================

  String _formatTotal(int minutes) {
    if (minutes < 60) return '${minutes}분';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? '${h}시간' : '${h}시간 ${m}분';
  }

  /// 세션들을 10분 단위 슬롯(총 144칸)으로 변환: 각 칸 0.0~1.0 (채움 비율)
  List<double> _computeDailySlotFractions(List<StudySession> sessions) {
    final slots = List<double>.filled(144, 0.0);

    for (final s in sessions) {
      final st = s.startTime.toLocal();
      final en = s.endTime.toLocal();
      if (!en.isAfter(st)) continue;

      int startMin = st.hour * 60 + st.minute; // 0~1439
      int endMin = en.hour * 60 + en.minute;   // 0~1440
      endMin = endMin.clamp(0, 1440);

      final startSlot = (startMin / 10).floor().clamp(0, 143);
      final endSlotExclusive = ((endMin + 9) / 10).floor().clamp(0, 144); // ceil 대체

      for (int slot = startSlot; slot < endSlotExclusive; slot++) {
        final slotStart = slot * 10;
        final slotEnd = slotStart + 10;

        final overlapStart = startMin > slotStart ? startMin : slotStart;
        final overlapEnd = endMin < slotEnd ? endMin : slotEnd;
        final overlap = overlapEnd - overlapStart; // 분

        if (overlap > 0) {
          final frac = overlap / 10.0;
          slots[slot] = (slots[slot] + frac).clamp(0.0, 1.0); // 여러 세션 누적 대비
        }
      }
    }
    return slots;


  }
}

// ========================= Sub Widgets =========================

class _TimerCard extends StatelessWidget {
  const _TimerCard({required this.timerProvider});
  final TimerProvider timerProvider;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
        BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(2, 2)),
        ],
      ),
      child: Column(
        children: [
          Text(
            timerProvider.formattedTime,
            style: const TextStyle(fontSize: 60, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
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
              const SizedBox(width: 20),
              IconButton(
                icon: const Icon(Icons.stop, size: 40, color: Colors.redAccent),
                onPressed: () {
                  timerProvider.stopAndSave();
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            timerProvider.isRunning ? '집중 중...' : '일시정지됨',
            style: const TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 8),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => timerProvider.reset(),
          ),
        ],
      ),
    );
  }
}

class _TimeTableSection extends StatelessWidget {
  const _TimeTableSection({required this.totalMinutes, required this.slotFractions});
  final int totalMinutes;
  final List<double> slotFractions; // 길이 144

  String _formatTotal(int minutes) {
    if (minutes < 60) return '${minutes}분';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? '${h}시간' : '${h}시간 ${m}분';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            '오늘의 공부 기록',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            '총 공부 시간: ${_formatTotal(totalMinutes)}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
        ),
        const SizedBox(height: 12),
        _TimeTableGrid(slotFractions: slotFractions),
      ],
    );
  }
}

class _SessionListSection extends StatelessWidget {
  const _SessionListSection({required this.sessions});
  final List<StudySession> sessions;

  String _fmtTime(DateTime t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            '오늘의 공부 세션',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 6),
        // 왼쪽 섹션의 "총 공부 시간" 라인(텍스트 높이 ~20) + 아래 간격(12)을 합친 공간을 확보해
        const SizedBox(height: 28),
        if (sessions.isEmpty)
        const Card(
          elevation: 0,
          color: Color(0xFFF7F7F7),
          child: Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('오늘 세션이 없습니다.'),
          ),
        )
        else
        ListView.builder(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          itemCount: sessions.length,
          itemBuilder: (context, index) {
            final session = sessions[index];
            return Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 1,
              margin: const EdgeInsets.symmetric(vertical: 6),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${_fmtTime(session.startTime)} ~ ${_fmtTime(session.endTime)}', style: const TextStyle(fontSize: 16)),
                    const Expanded(
                    child: Center(child: Text('공부 세션', style: TextStyle(fontSize: 16))),
                    ),
                    Text('${session.totalMinutes}분', style: const TextStyle(color: Colors.grey)),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.grey),
                      onPressed: () {
                        Provider.of<TimerProvider>(context, listen: false).removeSessionAt(index);
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _TimeTableGrid extends StatelessWidget {
  const _TimeTableGrid({required this.slotFractions});
  final List<double> slotFractions; // 길이 144, 각 0.0~1.0

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(2, 2)),
        ],
      ),
      child: Column(
        children: List.generate(24, (hour) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: 32,
                  child: Text('${hour}시', style: const TextStyle(color: Colors.black87)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Row(
                    children: List.generate(6, (i) {
                      final idx = hour * 6 + i; // 0~143
                      final frac = slotFractions[idx].clamp(0.0, 1.0);
                      return Expanded(
                        child: Container(
                          height: 20,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final fillWidth = constraints.maxWidth * frac;
                              return Stack(
                                children: [
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: Container(
                                      width: fillWidth,
                                      height: double.infinity,
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.primary.withOpacity(0.85),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}




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
//   void initState() {
//     super.initState();
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       Provider.of<TimerProvider>(context, listen: false).fetchSessionsByDate(DateTime.now());
//     });
//   }

//   @override
//   void didChangeDependencies() {
//     super.didChangeDependencies();
//     if (!_isInitialized) {
//       Provider.of<TimerProvider>(context, listen: false).restoreTimerState();
//       _isInitialized = true;
//     }
//   }

//   Widget buildTimeGrid(List<StudySession> sessions) {
//     const int startHour = 0;
//     const int endHour = 24;
//     const double cellHeight = 24;
//     const double cellWidth = 24;
//     final int rows = endHour - startHour;
//     final int columns = 6; // 10분 단위

//     return SingleChildScrollView(
//       scrollDirection: Axis.horizontal,
//       child: SizedBox(
//         width: columns * cellWidth + 60,
//         child: ListView.builder(
//           itemCount: rows,
//           itemBuilder: (context, rowIndex) {
//             final hour = startHour + rowIndex;
//             return Row(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 SizedBox(
//                   width: 40,
//                   height: cellHeight,
//                   child: Center(
//                     child: Text(
//                       '${hour % 24}시',
//                       style: const TextStyle(fontSize: 12, color: Colors.black54),
//                     ),
//                   ),
//                 ),
//                 SizedBox(
//                   width: columns * cellWidth,
//                   height: cellHeight,
//                   child: Stack(
//                     children: [
//                       Row(
//                         children: List.generate(columns, (_) => Container(
//                           width: cellWidth,
//                           height: cellHeight,
//                           decoration: BoxDecoration(
//                             border: Border.all(color: Colors.grey.shade300),
//                           ),
//                         )),
//                       ),
//                       ...sessions.map((session) {
//                         final start = session.startTime;
//                         final end = session.endTime;

//                         // if (start.hour > hour || end.hour < hour) return const SizedBox.shrink();

//                         // final startMinute = start.hour == hour ? start.minute : 0;
//                         // final endMinute = end.hour == hour ? end.minute : 60;
//                         if (start == null || end == null) return const SizedBox.shrink();

//                         if (start!.hour > hour || end!.hour < hour) return const SizedBox.shrink();

//                         final startMinute = start!.hour == hour ? start!.minute : 0;
//                         final endMinute = end!.hour == hour ? end!.minute : 60;


//                         final left = (startMinute / 10) * cellWidth;
//                         final width = ((endMinute - startMinute) / 10) * cellWidth;

//                         return Positioned(
//                           left: left,
//                           top: 3,
//                           child: Container(
//                             width: width,
//                             height: cellHeight - 6,
//                             decoration: BoxDecoration(
//                               color: Colors.lightBlue.shade100.withOpacity(0.7),
//                               borderRadius: BorderRadius.circular(4),
//                               boxShadow: [
//                                 BoxShadow(
//                                   color: Colors.black12,
//                                   blurRadius: 2,
//                                   offset: Offset(1, 1),
//                                 )
//                               ],
//                             ),
//                           ),
//                         );
//                       }).toList(),
//                     ],
//                   ),
//                 )
//               ],
//             );
//           },
//         ),
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.grey[100],
//       appBar: AppBar(title: const Text('타이머')),
//       body: Consumer<TimerProvider>(
//         builder: (context, timerProvider, _) {
//           final sessions = timerProvider.sessionList;

//           return Center( // 중앙 정렬
//             child: ConstrainedBox(
//               constraints: const BoxConstraints(maxWidth: 720), // 화면 중앙에 너비 제한
//               child: Padding(
//                 padding: const EdgeInsets.symmetric(horizontal: 8),
//                 child: Row(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     /// 타이머 영역
//                     Expanded(
//                       flex: 1,
//                       child: Container(
//                         margin: const EdgeInsets.all(16),
//                         padding: const EdgeInsets.all(20),
//                         decoration: BoxDecoration(
//                           color: Colors.white,
//                           borderRadius: BorderRadius.circular(16),
//                           boxShadow: const [
//                             BoxShadow(
//                               color: Colors.black12,
//                               blurRadius: 4,
//                               offset: Offset(2, 2),
//                             )
//                           ],
//                         ),
//                         child: Column(
//                           children: [
//                             const SizedBox(height: 20),
//                             Text(
//                               timerProvider.formattedTime,
//                               style: const TextStyle(fontSize: 60, fontWeight: FontWeight.bold),
//                             ),
//                             const SizedBox(height: 20),
//                             IconButton(
//                               icon: Icon(
//                                 timerProvider.isRunning ? Icons.pause : Icons.play_arrow,
//                                 size: 48,
//                               ),
//                               onPressed: () {
//                                 if (timerProvider.isRunning) {
//                                   timerProvider.pause();
//                                 } else {
//                                   timerProvider.start();
//                                 }
//                               },
//                             ),
//                             const SizedBox(height: 20),
//                           ],
//                         ),
//                       ),
//                     ),

//                     /// 타임 테이블 영역
//                     Expanded(
//                       flex: 1,
//                       child: Padding(
//                         padding: const EdgeInsets.fromLTRB(8, 16, 16, 16),
//                         child: Column(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             const Text(
//                               "오늘의 공부 세션",
//                               style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
//                             ),
//                             const SizedBox(height: 12),
//                             Expanded(
//                               child: Container(
//                                 decoration: BoxDecoration(
//                                   color: Colors.white,
//                                   border: Border.all(color: Colors.grey.shade300),
//                                   borderRadius: BorderRadius.circular(12),
//                                 ),
//                                 child: sessions.isEmpty
//                                     ? const Center(child: Text("오늘 세션이 없습니다."))
//                                     : buildTimeGrid(sessions),
//                               ),
//                             ),
//                           ],
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//           );
//         },
//       ),
//     );
//   }
// }
