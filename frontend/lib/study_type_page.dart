
// frontend/lib/study_type_page.dart
import 'env.dart'; 
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:fl_chart/fl_chart.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

// PDF 내보내기 (A4/Letter 등 페이지 크기 제어)
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

// MyPage로 이동
import 'mypage.dart';

// -------------------- API 모델 & 함수 (전역) --------------------

// 필요 시만 Platform 분기했는데 현재는 하드코딩 사용
// final String baseUrl =
//     Platform.isAndroid ? '${Env.baseUrl}' : '${Env.baseUrl}';
final String baseUrl = '${Env.baseUrl}';

Future<String?> _getAccessToken() async {
  final sp = await SharedPreferences.getInstance();
  return sp.getString('accessToken');
}

class UserStudyDailyModel {
  final int userId;
  final DateTime studyDate;
  final int totalMinutes;
  final int morningMinutes;
  final int afternoonMinutes;
  final int eveningMinutes;
  final int nightMinutes;
  final num repetition;
  final int dailyAchievement;

  UserStudyDailyModel({
    required this.userId,
    required this.studyDate,
    required this.totalMinutes,
    required this.morningMinutes,
    required this.afternoonMinutes,
    required this.eveningMinutes,
    required this.nightMinutes,
    required this.repetition,
    required this.dailyAchievement,
  });

  factory UserStudyDailyModel.fromJson(Map<String, dynamic> j) {
    return UserStudyDailyModel(
      userId: j['user_id'] ?? 0,
      studyDate: DateTime.parse(j['study_date']),
      totalMinutes: j['total_minutes'] ?? 0,
      morningMinutes: j['morning_minutes'] ?? 0,
      afternoonMinutes: j['afternoon_minutes'] ?? 0,
      eveningMinutes: j['evening_minutes'] ?? 0,
      nightMinutes: j['night_minutes'] ?? 0,
      repetition: j['repetition'] ?? 0,
      dailyAchievement: j['daily_achievement'] ?? 0,
    );
  }
}

Future<Map<String, String>> _headers() async {
  final token = await _getAccessToken();
  debugPrint('[_headers] token present? ${token != null && token.isNotEmpty}');
  return {
    'Content-Type': 'application/json',
    if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
  };
}

Future<List<UserStudyDailyModel>> apiFetchLast7() async {
  final res = await http.get(
    Uri.parse('$baseUrl/study-daily/last7'),
    headers: await _headers(),
  );
  if (res.statusCode != 200) {
    throw Exception('GET /study-daily/last7 실패: ${res.statusCode} ${res.body}');
  }
  final list = jsonDecode(res.body) as List;
  return list.map((e) => UserStudyDailyModel.fromJson(e)).toList();
}

Future<void> apiSaveDailyAchievement(DateTime date, int percent) async {
  final body = jsonEncode({
    'study_date': date.toIso8601String().split('T').first,
    'daily_achievement': percent,
  });
  final res = await http.post(
    Uri.parse('$baseUrl/study-daily/achievement'),
    headers: await _headers(),
    body: body,
  );
  if (res.statusCode != 200) {
    throw Exception('POST /study-daily/achievement 실패: ${res.statusCode} ${res.body}');
  }
}

Future<String?> apiFetchTrend() async {
  final res = await http.get(
    Uri.parse('$baseUrl/user-type/trend'),
    headers: await _headers(),
  );
  if (res.statusCode != 200) return null;
  final decoded = utf8.decode(res.bodyBytes);
  final j = jsonDecode(decoded);
  return (j['trend'] ?? j['message']) as String?;
}

Future<String?> apiFetchFeedback() async {
  final res = await http.get(
    Uri.parse('$baseUrl/user-type/feedback'),
    headers: await _headers(),
  );
  if (res.statusCode != 200) return null;
  final decoded = utf8.decode(res.bodyBytes);
  final j = jsonDecode(decoded);
  return j['feedback'] as String?;
}

Future<Map<String, dynamic>> apiAutoPredict() async {
  final res = await http.post(
    Uri.parse('$baseUrl/user-type/auto-predict'),
    headers: await _headers(),
  );
  if (res.statusCode != 200) {
    throw Exception('POST /user-type/auto-predict 실패: ${res.statusCode} ${res.body}');
  }
  final decoded = utf8.decode(res.bodyBytes);
  return jsonDecode(decoded) as Map<String, dynamic>;
}

// ---------------------------------------------------------------

class _SummarySquare extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final double size;

  const _SummarySquare({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final double iconSize = (size * 0.22).clamp(18.0, 40.0);
    final double titleSize = (size * 0.16).clamp(16.0, 24.0);
    final double subSize = (size * 0.10).clamp(11.0, 16.0);
    final double gap1 = (size * 0.06).clamp(8.0, 12.0);
    final double gap2 = (size * 0.02).clamp(4.0, 8.0);

    return SizedBox(
      width: size,
      height: size,
      child: Container(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 16,
              offset: const Offset(0, 10),
            ),
            BoxShadow(
              color: Colors.white.withOpacity(0.6),
              blurRadius: 2,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: iconSize, color: Colors.black87),
                SizedBox(height: gap1),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: titleSize,
                    color: Colors.black,
                  ),
                ),
                SizedBox(height: gap2),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: subSize,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class StudyTypePage extends StatefulWidget {
  const StudyTypePage({super.key});

  @override
  State<StudyTypePage> createState() => _StudyTypePageState();
}

class _StudyTypePageState extends State<StudyTypePage> {
  bool hasEnoughData = false;
  bool insufficient = false;
  List<UserStudyDailyModel> _last7 = [];
  bool _loading = false;

  // ✅ 캡처용 Key
  final GlobalKey _captureKey = GlobalKey();

  int? _selectedBarIndex;

  static const double kBtnWidth = 320;
  static const double kBtnHeight = 48;
  static const Color kSurface = Color(0xFFF8F9FA);

  String? _cardSincerity; // 성실도
  String? _cardRepetition; // 반복형
  String? _cardTimeslot; // 시간대
  String? _feedbackText; // GPT 피드백

  int _weekdayIndex(DateTime d) {
    // Dart weekday: 월=1 ... 일=7 → 월=0 ... 일=6로 변환
    return (d.weekday + 6) % 7;
  }


  @override
  void initState() {
    super.initState();
    _loadLast7().then((_) => _refreshUserTypeAndFeedback());
  }

  Future<void> _refreshUserTypeAndFeedback() async {
    setState(() => _loading = true);
    try {
      final pred = await apiAutoPredict();
      setState(() {
        _cardSincerity = pred['prediction']?['성실도']?.toString();
        _cardRepetition = pred['prediction']?['반복형']?.toString();
        _cardTimeslot = pred['prediction']?['시간대']?.toString();
      });

      final fb = await apiFetchFeedback();
      setState(() {
        _feedbackText = fb;
      });
    } catch (e) {
      debugPrint('refreshUserTypeAndFeedback error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('예측/피드백 불러오기 실패: $e')),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  Widget _insightPanel(String? text) {
    final t = (text ?? '분석 준비 중입니다. 잠시 후 다시 시도해 주세요.').trim();
    final firstBreak = t.indexOf(RegExp(r'[.!?]\s|[\n]'));
    final head = firstBreak > 0 ? t.substring(0, firstBreak + 1) : t;
    final body = firstBreak > 0 ? t.substring(firstBreak + 1).trimLeft() : '';

    return _whitePanel(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(Icons.lightbulb_rounded, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  head,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (body.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    body,
                    style: const TextStyle(fontSize: 14, height: 1.4),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasAnyStudy = _last7.any((d) => d.totalMinutes > 0);

    return WillPopScope(
      onWillPop: () async {
        if (Navigator.of(context).canPop()) return true;
        Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: const Text('학습 성향 분석', style: TextStyle(color: Colors.black)),
          centerTitle: true,
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ---------- 헤더 ----------
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '나의 학습 성향',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    '분석 요약',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: Colors.black,
                    ),
                  ),
                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                ],
              ),
            ),

            // ---------- 본문 ----------
            Expanded(
              child: Container(
                color: kSurface,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                  child: RepaintBoundary(
                    key: _captureKey, // ✅ 캡처 대상 전체
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionBox(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 카드 3개
                              Expanded(
                                flex: 3,
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 80),
                                  child: LayoutBuilder(
                                    builder: (context, constraints) {
                                      const gap = 12.0;
                                      const cols = 3;
                                      final raw = (constraints.maxWidth - gap * (cols - 1)) / cols;
                                      final double size = raw.clamp(120.0, 170.0).toDouble();

                                      return Wrap(
                                        spacing: gap,
                                        runSpacing: gap,
                                        alignment: WrapAlignment.center,
                                        children: [
                                          _SummarySquare(
                                            icon: Icons.verified_user_rounded,
                                            title: _cardSincerity ?? '저성실',
                                            subtitle: '성실도 지수',
                                            color: const Color(0xFFFFE5D8),
                                            size: size,
                                          ),
                                          _SummarySquare(
                                            icon: Icons.autorenew_rounded,
                                            title: _cardRepetition ?? '복습형',
                                            subtitle: '학습 유형',
                                            color: const Color(0xFFE8F9DA),
                                            size: size,
                                          ),
                                          _SummarySquare(
                                            icon: Icons.wb_sunny_rounded,
                                            title: _cardTimeslot ?? '오전',
                                            subtitle: '학습 시간대',
                                            color: const Color(0xFFDFF2FF),
                                            size: size,
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                ),
                              ),

                              const SizedBox(width: 16),

                              // 차트
                              Expanded(
                                flex: 3,
                                child: Container(
                                  height: 360,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    border: Border.all(
                                      width: 1.5,
                                      color: const Color(0xFFE9EDF2),
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 12,
                                        ),
                                        decoration: const BoxDecoration(
                                          color: Color(0xFFF2F5F8),
                                          borderRadius: BorderRadius.vertical(
                                            top: Radius.circular(16),
                                          ),
                                        ),
                                        child: const Text(
                                          '요일별 시간 분석',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.black,
                                          ),
                                        ),
                                      ),
                                      Divider(
                                        height: 1,
                                        thickness: 1,
                                        color: Colors.grey.shade200,
                                      ),
                                      Expanded(
                                        child: Padding(
                                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                                          child: hasAnyStudy
                                              ? Builder(
                                                  builder: (_) {
                                                    // --- 요일별 집계 준비 (월=0 ... 일=6) ---
                                                    final List<double> hoursByWeekday = List<double>.filled(7, 0.0);
                                                    final List<DateTime?> dateByWeekday = List<DateTime?>.filled(7, null);

                                                    for (final d in _last7) {
                                                      final i = _weekdayIndex(d.studyDate);
                                                      hoursByWeekday[i] = d.totalMinutes / 60.0;
                                                      dateByWeekday[i] = d.studyDate;
                                                    }

                                                    return BarChart(
                                                      BarChartData(
                                                        maxY: 8,
                                                        minY: 0,
                                                        barTouchData: BarTouchData(
                                                          enabled: true,
                                                          handleBuiltInTouches: true,
                                                          touchTooltipData: BarTouchTooltipData(
                                                            tooltipRoundedRadius: 8,
                                                            tooltipPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                                            getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                                              const days = ['MON','TUE','WED','THU','FRI','SAT','SUN'];
                                                              return BarTooltipItem(
                                                                '${days[group.x.toInt() % 7]}\n${rod.toY.toStringAsFixed(1)}h',
                                                                const TextStyle(color: Colors.black, fontWeight: FontWeight.w700),
                                                              );
                                                            },
                                                          ),
                                                          touchCallback: (event, response) {
                                                            if (!event.isInterestedForInteractions || response?.spot == null) {
                                                              setState(() => _selectedBarIndex = null);
                                                              return;
                                                            }
                                                            final idx = response!.spot!.touchedBarGroupIndex;
                                                            setState(() => _selectedBarIndex = idx);

                                                            final dt = dateByWeekday[idx];
                                                            if (dt != null) {
                                                              _onBarSelectedByDate(dt);
                                                            }
                                                          },
                                                        ),
                                                        gridData: FlGridData(
                                                          show: true,
                                                          drawVerticalLine: true,
                                                          horizontalInterval: 1,
                                                          getDrawingHorizontalLine: (v) => FlLine(
                                                            color: Colors.grey.withOpacity(0.18),
                                                            strokeWidth: 1,
                                                            dashArray: const [4, 4],
                                                          ),
                                                          getDrawingVerticalLine: (v) => FlLine(
                                                            color: Colors.grey.withOpacity(0.12),
                                                            strokeWidth: 1,
                                                          ),
                                                        ),
                                                        borderData: FlBorderData(show: false),
                                                        titlesData: FlTitlesData(
                                                          rightTitles: const AxisTitles(
                                                            sideTitles: SideTitles(showTitles: false),
                                                          ),
                                                          topTitles: const AxisTitles(
                                                            sideTitles: SideTitles(showTitles: false),
                                                          ),
                                                          leftTitles: AxisTitles(
                                                            sideTitles: SideTitles(
                                                              showTitles: true,
                                                              reservedSize: 24,
                                                              interval: 1,
                                                              getTitlesWidget: (v, _) => Text(
                                                                v.toInt().toString(),
                                                                style: const TextStyle(fontSize: 10, color: Colors.black),
                                                              ),
                                                            ),
                                                          ),
                                                          bottomTitles: AxisTitles(
                                                            sideTitles: SideTitles(
                                                              showTitles: true,
                                                              getTitlesWidget: (value, _) {
                                                                const days = ['MON','TUE','WED','THU','FRI','SAT','SUN'];
                                                                final i = value.toInt().clamp(0, 6);
                                                                return Padding(
                                                                  padding: const EdgeInsets.only(top: 4),
                                                                  child: Text(days[i], style: const TextStyle(fontSize: 10, color: Colors.black)),
                                                                );
                                                              },
                                                            ),
                                                          ),
                                                        ),
                                                        alignment: BarChartAlignment.spaceAround,
                                                        barGroups: List.generate(7, (i) {
                                                          final selected = _selectedBarIndex == i;
                                                          return BarChartGroupData(
                                                            x: i,
                                                            barsSpace: 2,
                                                            barRods: [
                                                              BarChartRodData(
                                                                toY: hoursByWeekday[i],
                                                                width: selected ? 14 : 12,
                                                                borderRadius: BorderRadius.circular(6),
                                                                color: selected ? Colors.black87 : Colors.grey.shade700,
                                                              ),
                                                            ],
                                                          );
                                                        }),
                                                      ),
                                                    );
                                                  },
                                                )
                                              : Center(
                                                  child: Text(
                                                    '최근 7일 데이터가 거의 없어요.\n타이머를 시작해 첫 기록을 만들어볼까요?',
                                                    textAlign: TextAlign.center,
                                                    style: TextStyle(color: Colors.black.withOpacity(.6)),
                                                  ),
                                                ),
                                        ),

                                      )
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),
                        _insightPanel(_feedbackText),

                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // 하단 버튼 바
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(24, 14, 24, 20),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 980),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _analyzeButton(),
                      const SizedBox(width: 12),

                      // ▶ 내보내기(이미지 공유, PDF 저장)
                      SizedBox(
                        width: kBtnWidth,
                        height: kBtnHeight,
                        child: ElevatedButton.icon(
                          onPressed: _showExportSheet,
                          icon: const Icon(Icons.ios_share, size: 18, color: Colors.black),
                          label: const Text(
                            '내보내기',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: const BorderSide(color: Colors.grey, width: 2),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 흰색 패널 공통
  Widget _whitePanel({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(width: 1.5, color: const Color(0xFFE9EDF2)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
  }

  // 섹션 박스
  Widget _sectionBox({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE9EDF2), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }

  // 기존 _analyzeButton() 통째로 교체
  Widget _analyzeButton() {
    return SizedBox(
      width: kBtnWidth,
      height: kBtnHeight,
      child: ElevatedButton.icon(
        onPressed: () async {
          if (!hasEnoughData) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('최근 7일 기록이 부족하지만 분석을 시도합니다.')),
            );
          }
          await _runAutoPredictAndShow();
        },
        onLongPress: () async {
          try {
            final pred  = await apiAutoPredict();
            final trend = await apiFetchTrend();
            final fb    = await apiFetchFeedback();

            if (!mounted) return;
            await showModalBottomSheet(
              context: context,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              builder: (_) => Padding(
                padding: const EdgeInsets.all(20),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('📊 이번 주 예측',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      _kv('성실도', pred['prediction']?['성실도'] ?? '-'),
                      _kv('반복형', pred['prediction']?['반복형'] ?? '-'),
                      _kv('시간대', pred['prediction']?['시간대'] ?? '-'),
                      if (pred['missing_days'] != null) _kv('결측일(자동 보정)', '${pred['missing_days']}일'),
                      const Divider(height: 28, thickness: 1),
                      Text('📈 전주 대비 변화',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text(trend ?? '변화 비교 데이터가 부족합니다.', style: const TextStyle(fontSize: 14, height: 1.5)),
                      const Divider(height: 28, thickness: 1),
                      Text('💡 GPT 피드백',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text(fb ?? '피드백을 생성할 수 없습니다.', style: const TextStyle(fontSize: 14, height: 1.5)),
                    ],
                  ),
                ),
              ),
            );
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('상세 보기 실패: $e')),
              );
            }
          }
        },
        icon: const Icon(Icons.autorenew, size: 18, color: Colors.black),
        label: const Text(
          '다시 분석하기',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Colors.grey, width: 2),
          ),
        ),
      ),
    );
  }

  Widget _kv(String k, String v) => RichText(
    text: TextSpan(
      style: const TextStyle(color: Colors.black, fontSize: 15, height: 1.4),
      children: [
        TextSpan(text: '$k: ', style: const TextStyle(fontWeight: FontWeight.w600)),
        TextSpan(text: v),
      ],
    ),
  );

  Future<void> _loadLast7() async {
    setState(() => _loading = true);
    try {
      final data = await apiFetchLast7();
      final activeDays = data.where((d) => d.totalMinutes > 0).length;
      setState(() {
        _last7 = data;
        hasEnoughData = activeDays >= 3;
        insufficient = !hasEnoughData;
      });
    } catch (e) {
      setState(() {
        _last7 = [];
        hasEnoughData = false;
        insufficient = true;
      });
      debugPrint('loadLast7 error: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _onBarSelected(int index) async {
    _selectedBarIndex = index;
    setState(() {});
    try {
      await apiSaveDailyAchievement(_last7[index].studyDate, 100);
      final d = _last7[index];
      _last7[index] = UserStudyDailyModel(
        userId: d.userId,
        studyDate: d.studyDate,
        totalMinutes: d.totalMinutes,
        morningMinutes: d.morningMinutes,
        afternoonMinutes: d.afternoonMinutes,
        eveningMinutes: d.eveningMinutes,
        nightMinutes: d.nightMinutes,
        repetition: d.repetition,
        dailyAchievement: 100,
      );
      setState(() {});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('달성률 저장 실패: $e')),
      );
    }
  }

  Future<void> _onBarSelectedByDate(DateTime date) async {
    try {
      await apiSaveDailyAchievement(date, 100);

      // _last7 내부 데이터도 반영
      final k = _last7.indexWhere((e) =>
          e.studyDate.year == date.year &&
          e.studyDate.month == date.month &&
          e.studyDate.day == date.day);
      if (k != -1) {
        final d = _last7[k];
        _last7[k] = UserStudyDailyModel(
          userId: d.userId,
          studyDate: d.studyDate,
          totalMinutes: d.totalMinutes,
          morningMinutes: d.morningMinutes,
          afternoonMinutes: d.afternoonMinutes,
          eveningMinutes: d.eveningMinutes,
          nightMinutes: d.nightMinutes,
          repetition: d.repetition,
          dailyAchievement: 100,
        );
        setState(() {}); // 그래프 갱신
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('달성률 저장 실패: $e')),
        );
      }
    }
  }


  Future<void> _runAutoPredictAndShow() async {
    setState(() => _loading = true);
    try {
      final pred = await apiAutoPredict();
      final fb   = await apiFetchFeedback();

      if (mounted) {
        setState(() {
          _cardSincerity  = pred['prediction']?['성실도']?.toString();
          _cardRepetition = pred['prediction']?['반복형']?.toString();
          _cardTimeslot   = pred['prediction']?['시간대']?.toString();
          _feedbackText   = fb;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('분석이 갱신됐어요.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('예측/피드백 실패: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ====== Export helpers ===================================================

  Future<Uint8List?> _capturePngBytes({double pixelRatio = 3.0}) async {
    final boundary = _captureKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return null;

    // 스크롤 영역 전체가 렌더링되도록 약간 대기 (프레임 보장)
    await Future.delayed(const Duration(milliseconds: 20));

    final ui.Image image = await boundary.toImage(pixelRatio: pixelRatio);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  }

  // 3:2(4x6) 비율로 패딩 (인쇄 UI 기본 4x6일 때 잘림 방지용)
  Uint8List _padToThreeByTwo(Uint8List src) {
    final codec = ui.instantiateImageCodec(src);
    throw UnimplementedError('sync codec not allowed');
  }
  // ↑ 위처럼 동기 디코딩은 못 쓰므로, 간단히는 “그대로 공유”하고,
  // 인쇄 잘림 문제는 아래 PDF 내보내기로 해결합니다.
  // 필요하면 향후 isolate로 패딩 구현해줄게요.

  Future<void> _shareAsImage() async {
    try {
      final pngBytes = await _capturePngBytes();
      if (pngBytes == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('공유할 영역을 찾지 못했어요.')));
        }
        return;
      }
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/study_type_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(pngBytes);
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'image/png', name: 'study_type.png')],
        text: '학습 성향 분석 결과를 공유합니다.',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('이미지 내보내기 실패: $e')));
      }
    }
  }

  Future<void> _exportAsPdf({PdfPageFormat? pageFormat}) async {
    try {
      // 화면 캡처
      final pngBytes = await _capturePngBytes(pixelRatio: 3.0);
      if (pngBytes == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('내보낼 화면을 찾지 못했어요.')),
          );
        }
        return;
      }

      final doc = pw.Document();
      final img = pw.MemoryImage(pngBytes);

      // ★ 기본: 6×4 inch 가로(프린터 용지 4×6과 딱 맞아 잘림 방지)
      // 원하는 용지 있으면 호출부에서 pageFormat 파라미터로 덮어쓰기
      final format = pageFormat ??
          PdfPageFormat(6 * PdfPageFormat.inch, 4 * PdfPageFormat.inch);

      doc.addPage(
        pw.Page(
          pageFormat: format,
          margin: pw.EdgeInsets.zero, // 여백 0 → 크롭 방지
          build: (_) => pw.Container(
            color: PdfColors.white, // 배경 흰색(투명 PNG 대비)
            alignment: pw.Alignment.center,
            child: pw.FittedBox(
              fit: pw.BoxFit.contain, // 비율 유지 + 크롭 없음
              child: pw.Image(img),
            ),
          ),
        ),
      );

      // 파일 저장
      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/study_type_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final file = File(path);
      await file.writeAsBytes(await doc.save());

      // 공유
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/pdf', name: 'study_type.pdf')],
        text: '학습 성향 분석 결과 PDF',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF 내보내기 실패: $e')),
        );
      }
    }
  }

  void _showExportSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.image_outlined),
              title: const Text('이미지로 공유'),
              onTap: () async {
                Navigator.pop(context);
                await _shareAsImage();
              },
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf),
              title: const Text('PDF로 저장/공유 (권장)'),
              onTap: () async {
                Navigator.pop(context);
                await _exportAsPdf(pageFormat: PdfPageFormat.a4);
              },
            ),
          ],
        ),
      ),
    );
  }
}

// (미사용) 분석 요약 카드 - 그대로 유지
class _SummaryCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color startColor;
  final Color endColor;
  final IconData icon;

  const _SummaryCard({
    required this.title,
    required this.subtitle,
    required this.startColor,
    required this.endColor,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 170,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, Colors.white],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(color: Colors.white.withOpacity(.6), width: 2),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 24, color: Colors.black87),
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.black.withOpacity(.65),
            ),
          ),
        ],
      ),
    );
  }
}


