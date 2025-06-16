
import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:path_drawing/path_drawing.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:ui' as ui;
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter/foundation.dart'; // kIsWeb 사용
import 'dart:async'; // Completer 사용을 위한 import
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:ui' show PointerDeviceKind;
import 'package:phosphor_flutter/phosphor_flutter.dart';

enum DrawMode { hand, pen, highlighter, eraser, lasso, transform }

class Stroke {
  List<Offset> points;
  Paint paint;
  String penType; // 추가
  Stroke({required this.points, required this.paint, required this.penType, // 생성자
  });
}

class NotePage extends StatefulWidget {
  final int pdfId;
  final String noteTitle;
  const NotePage({super.key, required this.pdfId, required this.noteTitle});

  @override
  State<NotePage> createState() => _NotePageState();
}

class _NotePageState extends State<NotePage> {
  List<Map<String, dynamic>> pages = [];
  int currentPageIndex = 0;
  late PageController _pageController;
  List<GlobalKey> _viewerKeys = []; // InteractiveViewer 감시용 키 목록
  List<GlobalKey> repaintKeys = [];

  Map<int, List<Stroke>> pageStrokes = {};
  List<Offset> lassoPoints = [];
  Set<int> selectedIndexes = {};

  DrawMode currentMode = DrawMode.pen;
  Color currentColor = Colors.black;
  double strokeWidth = 3.0;

  Offset? _scaleDragStart;

  bool _isScaling = false; // 현재 드래그가 핸들 기반인지 여부
  int? _activeHandleIndex; // 핸들 꼭짓점 인덱스: 0~3

  bool _showPenOptions = false;
  String _selectedPenType = 'pen'; // 예: pen, brush, highlighter

  bool _isToolbarVisible = false;
  double _toolbarHeight = 80.0;

  bool _isThumbnailVisible = true; // 상태 추가

  final String baseUrl = kIsWeb || Platform.isAndroid
    ? 'http://localhost:8000'
    : 'http://localhost:8000';

  bool _isCapturing = false; // 중복 캡처 방지용

  List<TransformationController> _controllers = [];
  bool _interactionEnabled = true; // 필드 선언 필요 (State 클래스에)

  List<double> _minScales = [];
  List<Stroke> copiedStrokes = [];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();

    _fetchPages().then((_) {
      if (pages.isNotEmpty) {
        // 페이지 수만큼 TransformationController 생성
        _controllers = List.generate(pages.length, (_) => TransformationController());

        // 기존 단일 컨트롤러는 더 이상 사용하지 않으므로 제거

        _onPageChanged(0);
      }
    });
  }



  @override
  void dispose() {
    final pageId = pages.isNotEmpty ? pages[currentPageIndex]['page_id'] : null;
    if (pageId != null) _saveAnnotation(pageId);
    _pageController.dispose();
    super.dispose();
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      backgroundColor: const Color(0xFFFBFCF7),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const DrawerHeader(
            child: Text('메뉴', style: TextStyle(fontSize: 20, color: Color(0xFF004377))),
          ),
          ExpansionTile(
            title: const Text('PDF', style: TextStyle(color: Color(0xFF004377))),
            children: const [
              ListTile(title: Text('- A과목')),
              ListTile(title: Text('- B과목')),
              ListTile(title: Text('- PDF')),
            ],
          ),
          ListTile(
            title: const Text('AI 학습플래너', style: TextStyle(color: Color(0xFF004377))),
            onTap: () => Navigator.pushNamed(context, '/home'),
          ),
          const ListTile(title: Text('스터디 타이머', style: TextStyle(color: Color(0xFF004377)))),
          const ListTile(title: Text('마이페이지', style: TextStyle(color: Color(0xFF004377)))),
        ],
      ),
    );
  }

  Widget _modeIcon(IconData icon, DrawMode mode) {
    return IconButton(
      tooltip: mode.toString().split('.').last,
      icon: Icon(icon, color: currentMode == mode ? Colors.blue : Colors.black),
      onPressed: () => _setMode(mode),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (pages.isNotEmpty) {
          final pageId = pages[currentPageIndex]['page_id'];
          await _saveAnnotation(pageId);
          debugPrint('페이지 나가기 전에 자동 저장됨');
        }
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.pop(context); // 현재 페이지 pop → 이전 NoteListPage로 돌아감
            },
          ),
          title: Text(
            widget.noteTitle,
            style: GoogleFonts.notoSansKr(fontSize: 20),
          ),
          actions: [
            Tooltip(
              message: '페이지 추가',
              child: IconButton(
                icon: Icon(PhosphorIcons.plus()), // () 호출 필수
                onPressed: _addPage,
              ),
            ),
            const SizedBox(width: 6),

            Tooltip(
              message: '손 모드',
              child: _modeIcon(PhosphorIcons.hand(), DrawMode.hand),
            ),
            const SizedBox(width: 6),

            Tooltip(
              message: '펜 설정',
              child: IconButton(
                icon: Icon(
                  PhosphorIcons.pen(),
                  color: currentMode == DrawMode.pen ? Colors.blue : Colors.black,
                ),
                onPressed: () {
                  setState(() {
                    currentMode = DrawMode.pen;
                    _isToolbarVisible = !_isToolbarVisible;
                    _showPenOptions = !_showPenOptions;
                  });
                },
              ),
            ),
            const SizedBox(width: 6),

            Tooltip(
              message: '지우개',
              child: _modeIcon(PhosphorIcons.eraser(), DrawMode.eraser),
            ),
            const SizedBox(width: 6),

            Tooltip(
              message: '라쏘',
              child: _modeIcon(PhosphorIcons.selection(), DrawMode.lasso),
            ),
            const SizedBox(width: 6),

            Tooltip(
              message: '선택 삭제',
              child: IconButton(
                icon: Icon(PhosphorIcons.trash()), // () 추가
                onPressed: _deleteSelection,
              ),
            ),
            const SizedBox(width: 12),

            Tooltip(
              message: _isThumbnailVisible ? '썸네일 숨기기' : '썸네일 펼치기',
              child: IconButton(
                icon: Icon(
                  _isThumbnailVisible
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                ),
                onPressed: () {
                  setState(() {
                    _isThumbnailVisible = !_isThumbnailVisible;
                  });
                },
              ),
            ),
          ],



        ),



        drawer: _buildDrawer(context),
        body: pages.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  AnimatedCrossFade(
                    duration: const Duration(milliseconds: 300),
                    crossFadeState: _isThumbnailVisible ? CrossFadeState.showFirst : CrossFadeState.showSecond,
                    firstChild: SizedBox(
                      height: 80,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: pages.length,
                        itemBuilder: (context, index) {
                          final previewUrl = pages[index]['image_preview_url'];
                          final isSelected = index == currentPageIndex;
                          final pageId = pages[index]['page_id'];

                          return GestureDetector(
                            onTap: () async {
                              final oldPageId = pages[currentPageIndex]['page_id'];
                              await _saveAnnotation(oldPageId);
                              setState(() => currentPageIndex = index);
                              _pageController.jumpToPage(index);
                              final newPageId = pages[index]['page_id'];
                              if ((pageStrokes[newPageId]?.isEmpty ?? true)) {
                                await _loadAnnotations(newPageId);
                              }
                            },
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                border: Border.all(color: isSelected ? Colors.blue : Colors.grey, width: 2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: previewUrl != null
                                  ? CachedNetworkImage(
                                      imageUrl: '$baseUrl$previewUrl?timestamp=${DateTime.now().millisecondsSinceEpoch}',
                                      cacheKey: '$baseUrl$previewUrl',
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                                      errorWidget: (context, url, error) => const Center(child: Text('이미지 로딩 실패')),
                                    )
                                  : ThumbnailCanvas(
                                      strokes: pageStrokes[pageId] ?? [],
                                      width: 60,
                                      height: 80,
                                    ),
                            ),
                          );
                        },
                      ),

                    ),
                    secondChild: const SizedBox.shrink(),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    height: _isToolbarVisible ? 80.0 : 0,
                    child: SingleChildScrollView(
                      child: Opacity(
                        opacity: _isToolbarVisible ? 1.0 : 0.0,
                        child: _buildPenOptions(),
                      ),
                    ),
                  ),
                  Expanded(
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: pages.length,
                      onPageChanged: _onPageChanged,
                      physics: _interactionEnabled
                          ? const AlwaysScrollableScrollPhysics()
                          : const NeverScrollableScrollPhysics(),
                      itemBuilder: (context, index) {
                        // 방어 조건: 아직 controllers, keys가 초기화되지 않은 경우
                        if (index >= _controllers.length ||
                            index >= _viewerKeys.length ||
                            index >= _minScales.length) {
                          return const Center(child: CircularProgressIndicator()); // 로딩 중 처리
                        }

                        final pageId = pages[index]['page_id'];
                        final pageNumber = pages[index]['page_number'];
                        final pdfImageUrl = '$baseUrl/pdf/page-image/${widget.pdfId}/$pageNumber';
                        final rawAspectRatio = pages[index]['aspect_ratio'] ?? 0.75;
                        final aspectRatio = rawAspectRatio > 0 ? rawAspectRatio : 0.75;

                        return LayoutBuilder(
                          builder: (context, constraints) {
                            final double screenWidth = constraints.maxWidth;
                            final double pageWidth = screenWidth;
                            final double pageHeight = pageWidth / aspectRatio;

                            return Container(
                              color: Colors.grey[200],
                              child: Center(
                                child: Listener(
                                  onPointerDown: (event) {
                                    final isStylus = event.kind == PointerDeviceKind.stylus;
                                    setState(() => _interactionEnabled = !isStylus);

                                    if (isStylus) {
                                      final box = context.findRenderObject();
                                      if (box is! RenderBox) return;
                                      final local = box.globalToLocal(event.position);
                                      _handlePanStart(
                                        DragStartDetails(
                                          globalPosition: event.position,
                                          localPosition: local,
                                        ),
                                        pageId,
                                      );
                                    }
                                  },
                                  onPointerMove: (event) {
                                    if (event.kind != PointerDeviceKind.stylus) return;
                                    final box = context.findRenderObject();
                                    if (box is! RenderBox) return;
                                    final local = box.globalToLocal(event.position);
                                    _handlePanUpdate(
                                      DragUpdateDetails(
                                        globalPosition: event.position,
                                        localPosition: local,
                                        delta: event.delta,
                                      ),
                                      pageId,
                                    );
                                  },
                                  onPointerUp: (event) {
                                    if (event.kind == PointerDeviceKind.stylus) {
                                      _handlePanEnd(pageId);
                                    }
                                  },
                                  child: Builder(
                                    builder: (context) {
                                      debugPrint('scale: min=${_minScales[index]}, max=4.0');
                                      return InteractiveViewer(
                                        key: _viewerKeys[index],
                                        transformationController: _controllers[index],
                                        constrained: false,
                                        boundaryMargin: const EdgeInsets.all(100),
                                        minScale: _minScales[index],
                                        maxScale: 4.0,
                                        panEnabled: _interactionEnabled,
                                        scaleEnabled: _interactionEnabled,
                                        child: Container(
                                          width: pageWidth,
                                          height: pageHeight,
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(6),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withOpacity(0.08),
                                                blurRadius: 8,
                                                offset: const Offset(2, 2),
                                              ),
                                            ],
                                          ),
                                          child: RepaintBoundary(
                                            key: repaintKeys[index],
                                            child: Stack(
                                              alignment: Alignment.center,
                                              children: [
                                                _buildPdfBackground(pdfImageUrl, pageWidth, pageHeight),
                                                _buildHandwritingLayer(pageId, pageWidth, pageHeight),
                                              ],
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },

                    ),

                  ),

                ],
              ),
      ),
    );
  }



  void _handlePanStart(DragStartDetails details, int pageId) {
    final local = details.localPosition; // 화면 좌표
    final adjusted = _controllers[currentPageIndex].toScene(local); // PDF 좌표

    if (currentMode == DrawMode.hand) return;

    // 확대 핸들 감지
    if (currentMode == DrawMode.lasso && selectedIndexes.isNotEmpty) {
      final strokes = pageStrokes[pageId]!;
      final box = _computeBoundingBox(strokes, selectedIndexes);
      final currentScale = _controllers[currentPageIndex].value.getMaxScaleOnAxis();

      final handleVisualSize = 8.0 / currentScale; // 실제 화면에 그릴 핸들 크기
      final handleHitSize = 80.0; // 손가락 감지 영역은 넉넉하게 고정

      final handles = [
        box.topLeft,
        box.topRight,
        box.bottomLeft,
        box.bottomRight,
      ];

      final hitHandles = handles.map((center) =>
        Rect.fromCenter(center: center, width: handleHitSize, height: handleHitSize)).toList();

      _activeHandleIndex = null;
      for (int i = 0; i < hitHandles.length; i++) {
        if (hitHandles[i].contains(adjusted)) {
          _activeHandleIndex = i;
          break;
        }
      }

      _isScaling = _activeHandleIndex != null;
      _scaleDragStart = adjusted;

      setState(() {
        currentMode = DrawMode.transform;
      });
      return;
    }

    _isScaling = false;

    // 라쏘 시작
    if (currentMode == DrawMode.lasso) {
      lassoPoints.clear();
      lassoPoints.add(local); // 화면 좌표 저장
      debugPrint("라쏘 시작 좌표: ${local.dx}, ${local.dy}");
      setState(() {});
      return;
    }

    if (currentMode == DrawMode.eraser) return;

    if (currentMode == DrawMode.transform && selectedIndexes.isNotEmpty) {
      _scaleDragStart = adjusted;
      return;
    }

    // 필기 시작
    final paint = _createPaint();
    final newStroke = Stroke(points: [adjusted], paint: paint, penType: _selectedPenType);
    debugPrint("Stroke 좌표: ${adjusted.dx}, ${adjusted.dy}");

    pageStrokes[pageId] ??= [];
    pageStrokes[pageId]!.add(newStroke);
    setState(() {});
  }




  void _handlePanUpdate(DragUpdateDetails details, int pageId) {
    final local = details.localPosition;
    final adjusted = _controllers[currentPageIndex].toScene(local);

    if (currentMode == DrawMode.hand) return;

    // 지우개
    if (currentMode == DrawMode.eraser) {
      final strokes = pageStrokes[pageId]!;
      strokes.removeWhere((stroke) =>
          stroke.points.any((point) => (point - adjusted).distance < 12));
      setState(() {});
      return;
    }

    // 라쏘 그리기
    if (currentMode == DrawMode.lasso) {
      if (selectedIndexes.isNotEmpty) {
        _moveSelection(details.delta); // 화면 기준 이동
      } else {
        lassoPoints.add(local); // 화면 좌표 저장
        setState(() {});
      }
      return;
    }

    // 핸들 드래그로 스케일
    if (currentMode == DrawMode.transform && selectedIndexes.isNotEmpty) {
      if (_isScaling && _scaleDragStart != null) {
        final scenePrev = _controllers[currentPageIndex].toScene(details.localPosition);
        final sceneCurr = _controllers[currentPageIndex].toScene(details.localPosition + details.delta);
        final delta = sceneCurr - scenePrev;

        double baseDelta = 0.0;
        if (_activeHandleIndex != null) {
          switch (_activeHandleIndex) {
            case 0: baseDelta = -delta.dx - delta.dy; break;
            case 1: baseDelta = delta.dx - delta.dy; break;
            case 2: baseDelta = -delta.dx + delta.dy; break;
            case 3: baseDelta = delta.dx + delta.dy; break;
          }
        }

        double scaleFactor = 1.0 + (baseDelta / 220.0);
        scaleFactor = scaleFactor.clamp(0.8, 1.25);
        double smoothedScale = ui.lerpDouble(1.0, scaleFactor, 0.25)!;
        _scaleSelectionGesture(smoothedScale);

        _scaleDragStart = adjusted;
      } else {
        _moveSelection(details.delta); // 화면 기준 이동
      }

      setState(() {});
      return;
    }

    // 필기 중
    final strokes = pageStrokes[pageId];
    if (strokes != null && strokes.isNotEmpty) {
      strokes.last.points.add(adjusted);
      setState(() {});
    }
  }







  void _handlePanEnd(int pageId) async {
    if (currentMode == DrawMode.hand) return;

    if (currentMode == DrawMode.lasso) {
      if (selectedIndexes.isNotEmpty) {
        setState(() {
          currentMode = DrawMode.transform;
        });
      } else {
        _selectByLasso(); // 이 안에서 toScene 적용
      }
      return;
    }

    _scaleDragStart = null;
    _isScaling = false;
    _activeHandleIndex = null;

    if (currentMode != DrawMode.transform && currentMode != DrawMode.eraser) {
      await _saveAnnotation(pageId);
    }
  }



  void _scaleSelectionGesture(double factor) {
    final pageId = pages[currentPageIndex]['page_id'];
    final strokes = pageStrokes[pageId]!;
    final box = _computeBoundingBox(strokes, selectedIndexes);

    // 기준점(anchor) 결정
    Offset anchor;
    switch (_activeHandleIndex) {
      case 0: anchor = box.bottomRight; break;
      case 1: anchor = box.bottomLeft; break;
      case 2: anchor = box.topRight; break;
      case 3: anchor = box.topLeft; break;
      default: anchor = _computeCenter(selectedIndexes, strokes);
    }

    for (int index in selectedIndexes) {
      final stroke = strokes[index];
      stroke.points = stroke.points.map((p) {
        final dx = anchor.dx + (p.dx - anchor.dx) * factor;
        final dy = anchor.dy + (p.dy - anchor.dy) * factor;
        return Offset(dx, dy);
      }).toList();
    }

    setState(() {});
  }

  void _setMode(DrawMode mode) {
    setState(() {
      currentMode = mode;
      if (mode == DrawMode.pen) {
        currentColor = Colors.black;
        strokeWidth = 3.0;
      } else if (mode == DrawMode.highlighter) {
        currentColor = Colors.yellow.withAlpha((255 * 0.5).toInt());
        strokeWidth = 10.0;
      }
    });
  }

  void _moveSelection(Offset delta) {
    final pageId = pages[currentPageIndex]['page_id'];
    final strokes = pageStrokes[pageId]!;
    for (int index in selectedIndexes) {
      final stroke = strokes[index];
      stroke.points = stroke.points.map((p) => p + delta).toList();
    }
    setState(() {});
  }

  void _clearSelection() {
    if (selectedIndexes.isNotEmpty) {
      selectedIndexes.clear();
      setState(() {});
    }
  }



  void _clearSelectionAtTapPosition(Offset tapPosition) {
    if (selectedIndexes.isEmpty) return;

    final pageId = pages[currentPageIndex]['page_id'];
    final strokes = pageStrokes[pageId]!;

    final selectedPoints = <Offset>[];
    for (final index in selectedIndexes) {
      selectedPoints.addAll(strokes[index].points);
    }

    if (selectedPoints.isEmpty) return;

    final transformedTap = _controllers[currentPageIndex].toScene(tapPosition);

    final selectionRect = Rect.fromPoints(
      selectedPoints.reduce((a, b) => Offset(
        a.dx < b.dx ? a.dx : b.dx,
        a.dy < b.dy ? a.dy : b.dy,
      )),
      selectedPoints.reduce((a, b) => Offset(
        a.dx > b.dx ? a.dx : b.dx,
        a.dy > b.dy ? a.dy : b.dy,
      )),
    );

    // handle hitbox 크기만 큼 판정 (화면엔 작게 보여도)
    const handleHitBoxSize = 44.0;
    final handles = [
      selectionRect.topLeft,
      selectionRect.topRight,
      selectionRect.bottomLeft,
      selectionRect.bottomRight,
    ];

    final tappedOnHandle = handles.any((handle) =>
      Rect.fromCenter(center: handle, width: handleHitBoxSize, height: handleHitBoxSize)
          .contains(transformedTap)
    );

    if (selectionRect.inflate(20).contains(transformedTap) || tappedOnHandle) {
      return; // 선택 유지
    }

    // 선택 해제
    selectedIndexes.clear();
    currentMode = DrawMode.lasso;
    setState(() {});
  }







  Rect _computeBoundingBox(List<Stroke> strokes, Set<int> selectedIndexes) {
    final selectedPoints = <Offset>[];
    for (var index in selectedIndexes) {
      selectedPoints.addAll(strokes[index].points);
    }

    if (selectedPoints.isEmpty) return Rect.zero;

    double minX = selectedPoints.first.dx;
    double maxX = selectedPoints.first.dx;
    double minY = selectedPoints.first.dy;
    double maxY = selectedPoints.first.dy;

    for (var point in selectedPoints) {
      if (point.dx < minX) minX = point.dx;
      if (point.dx > maxX) maxX = point.dx;
      if (point.dy < minY) minY = point.dy;
      if (point.dy > maxY) maxY = point.dy;
    }

    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }



  Offset _computeCenter(Set<int> indexes, List<Stroke> strokes) {
    List<Offset> allPoints = [];
    for (int i in indexes) {
      allPoints.addAll(strokes[i].points);
    }
    if (allPoints.isEmpty) return const Offset(0, 0);
    final dx = allPoints.map((p) => p.dx).reduce((a, b) => a + b) / allPoints.length;
    final dy = allPoints.map((p) => p.dy).reduce((a, b) => a + b) / allPoints.length;
    return Offset(dx, dy);
  }

  bool _pointInPolygon(Offset point, List<Offset> polygon) {
    int intersectCount = 0;
    for (int j = 0; j < polygon.length; j++) {
      final a = polygon[j];
      final b = polygon[(j + 1) % polygon.length];
      if ((a.dy > point.dy) != (b.dy > point.dy)) {
        final x = (b.dx - a.dx) * (point.dy - a.dy) / (b.dy - a.dy) + a.dx;
        if (point.dx < x) intersectCount++;
      }
    }
    return intersectCount % 2 == 1;
  }


  void _selectByLasso() {
    final pageId = pages[currentPageIndex]['page_id'];
    final strokes = pageStrokes[pageId]!;
    selectedIndexes.clear();

    debugPrint("라쏘 선택 시작 - 라쏘 포인트 개수: ${lassoPoints.length}, 스토로크 수: ${strokes.length}");

    // 라쏘 좌표를 scene 기준으로 변환
    final transformedLasso = lassoPoints.map((p) => _controllers[currentPageIndex].toScene(p)).toList();

    if (transformedLasso.length > 2 &&
        (transformedLasso.first - transformedLasso.last).distance > 1.0) {
      transformedLasso.add(transformedLasso.first);
      debugPrint("라쏘 경로 자동 닫힘: 시작점 추가됨");
    }

    for (int i = 0; i < strokes.length; i++) {
      final stroke = strokes[i];

      // 1. 점 중 하나라도 라쏘 내부에 포함되면 선택
      bool pointInside = stroke.points.any((point) => _pointInPolygon(point, transformedLasso));

      // 2. 중심점이 라쏘 경계 근처에만 있어도 선택되도록 보완
      final center = _computeCenter({i}, strokes);
      final nearLasso = transformedLasso.any((p) => (p - center).distance < 15); // ← 거리 임계값 (조절 가능)

      if (pointInside || nearLasso) {
        debugPrint("선택됨: stroke $i");
        selectedIndexes.add(i);
      }
    }

    debugPrint("최종 선택된 stroke index: $selectedIndexes");

    lassoPoints.clear();
    setState(() {});
  }






  void _deleteSelection({bool keepSelection = false}) {
    final pageId = pages[currentPageIndex]['page_id'];
    final strokes = pageStrokes[pageId]!;

    for (int index in selectedIndexes) {
      strokes[index] = Stroke(points: [], paint: Paint()..blendMode = BlendMode.clear, penType: 'pen');
    }

    if (!keepSelection) {
      selectedIndexes.clear(); // 기본적으로 해제, 원하면 유지
    }

    setState(() {});
    _saveAnnotation(pageId);
  }


  Paint _createPaint() {
    final paint = Paint()
      ..color = currentColor
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    switch (_selectedPenType) {
      case 'pen':
        paint
          ..blendMode = BlendMode.srcOver
          ..style = PaintingStyle.stroke;
        break;

      case 'brush':
        paint
          ..color = currentColor.withOpacity(0.85) 
          ..strokeWidth = strokeWidth               
          ..blendMode = BlendMode.srcOver
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0);
        break;


      case 'highlighter':
        paint
          ..blendMode = BlendMode.srcATop
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.butt
          ..color = currentColor.withOpacity(0.25);
        break;

      default:
        paint.blendMode = BlendMode.srcOver;
    }

    return paint;
  }




  void _onPageChanged(int index) async {
    final oldPageId = pages[currentPageIndex]['page_id'];
    await _saveAnnotation(oldPageId);

    setState(() {
      currentPageIndex = index;
    });

    await _ensureWidgetIsRendered(_viewerKeys[index]);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final contextBox = _viewerKeys[index].currentContext;
      if (contextBox != null) {
        final box = contextBox.findRenderObject() as RenderBox?;
        if (box != null && box.hasSize) {
          final viewerSize = box.size;

          final aspectRatio = (pages[index]['aspect_ratio'] ?? 0.75).toDouble();
          final pageWidth = viewerSize.width;
          final pageHeight = pageWidth / aspectRatio;

          // 실제 화면에 맞게 계산한 최소 배율 (초기 확대 비율)
          final initialScale = viewerSize.height / pageHeight;
          
          final adjustedMinScale = initialScale * 0.95;  
          _minScales[index] = adjustedMinScale;
          
         

          final dx = (viewerSize.width - pageWidth * initialScale) / 2;
          final dy = (viewerSize.height - pageHeight * initialScale) / 2;
          debugPrint('initialScale 계산됨 → minScale으로 사용됨: \$initialScale');

          debugPrint('viewerSize: \${viewerSize.width} x \${viewerSize.height}');
          debugPrint('pageSize: \$pageWidth x \$pageHeight (aspectRatio: \$aspectRatio)');
          debugPrint('initialScale: \$initialScale → minScale 설정 완료');
          debugPrint('dx/dy: \$dx / \$dy');

          _controllers[index].value = Matrix4.identity()
            ..translate(dx, dy)
            ..scale(initialScale);

          debugPrint('controller matrix: \${_controllers[index].value}');
        }
      }
    });

    final newPageId = pages[index]['page_id'];
    if ((pageStrokes[newPageId]?.isEmpty ?? true)) {
      await _loadAnnotations(newPageId);
    }
  }



  Future<void> _addPage() async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/pdf/pages'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'pdf_id': widget.pdfId,
          'page_number': pages.length + 1,
          'image_preview_url': null,
        }),
      );

      if (response.statusCode == 201) {
        // 전체 페이지 및 관련 리스트 초기화
        await _fetchPages();

        // 새로 추가된 페이지 인덱스
        final newIndex = pages.length - 1;

        // 페이지 데이터, 컨트롤러, 키 등이 전부 정상인지 확인
        final isSafe = newIndex >= 0 &&
            newIndex < _controllers.length &&
            newIndex < _viewerKeys.length &&
            newIndex < _minScales.length &&
            pageStrokes.containsKey(pages[newIndex]['page_id']);

        if (!isSafe) {
          debugPrint("_addPage → 데이터 누락 또는 인덱스 범위 초과: $newIndex");
          return;
        }

        // 렌더링 후 안전하게 jumpToPage 및 상태 설정
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _pageController.jumpToPage(newIndex);

          // 너무 빠르면 context가 아직 null이므로 약간 지연
          Future.delayed(const Duration(milliseconds: 120), () {
            setState(() {
              currentPageIndex = newIndex;
            });

            _onPageChanged(newIndex);
          });
        });
      } else {
        debugPrint('_addPage 실패: status ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('_addPage 예외 발생: $e');
    }
  }



  Future<void> _fetchPages() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/pdf/pages/${widget.pdfId}'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        final newPages = List<Map<String, dynamic>>.from(data);

        for (var page in newPages) {
          page['aspect_ratio'] ??= 0.75;
        }

        // 모든 구조 동기화 준비
        final newControllers = List.generate(newPages.length, (_) => TransformationController());
        final newViewerKeys = List.generate(newPages.length, (_) => GlobalKey());
        final newRepaintKeys = List.generate(newPages.length, (_) => GlobalKey());
        final newMinScales = List.generate(newPages.length, (_) => 0.5);
        final newPageStrokes = <int, List<Stroke>>{};
        for (var page in newPages) {
          int pageId = page['page_id'];
          newPageStrokes[pageId] = [];
        }

        // 먼저 세팅 (strokes 구조가 존재해야 필기 데이터를 채울 수 있음)
        setState(() {
          pages = newPages;
          _controllers = newControllers;
          _viewerKeys = newViewerKeys;
          repaintKeys = newRepaintKeys;
          _minScales = newMinScales;
          pageStrokes = newPageStrokes;
        });

        // 필기 데이터 로딩은 나중에 (setState 이후)
        await _loadAllAnnotations();

        setState(() {}); // 필기 반영 다시 트리거
      }
    } catch (e) {
      debugPrint('_fetchPages 오류: $e');
    }
  }





  Future<void> _saveAnnotation(int pageId) async {
    final strokes = pageStrokes[pageId] ?? [];
    List<Map<String, dynamic>> lines = [];

    // 현재 페이지 정보에서 aspect_ratio 사용
    final page = pages.firstWhere((p) => p['page_id'] == pageId);
    final aspectRatio = page['aspect_ratio'] ?? 0.75; // 예: 4:3 → 0.75

    // 좌표 정규화: width는 그대로, height만 비율 적용
    for (final stroke in strokes) {
      if (stroke.points.isNotEmpty) {
        lines.add({
          'points': stroke.points.map((p) => {
            'x': p.dx,
            'y': p.dy * aspectRatio, // 정규화된 y 좌표
          }).toList(),
          'color': stroke.paint.color.value.toRadixString(16),
          'strokeWidth': stroke.paint.strokeWidth,
          'penType': stroke.penType,
        });
      }
    }

    final data = {
      'page_id': pageId,
      'page_number': page['page_number'],
      'annotation_type': 'pen',
      'data': {'lines': lines},
    };

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('accessToken');
      if (token == null) {
        debugPrint('토큰 없음: 삭제 요청 불가');
        return;
      }

      // 기존 필기 삭제
      await http.delete(
        Uri.parse('$baseUrl/pdf/annotations/$pageId'),
        headers: {'Authorization': 'Bearer $token'},
      );

      // 새 필기 업로드
      await http.post(
        Uri.parse('$baseUrl/pdf/annotations'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(data),
      );

      // 썸네일 캡처 및 업로드
      if (_isCapturing) return;
      _isCapturing = true;

      try {
        final imageBytes = await _captureThumbnailImage(pageId);
        if (imageBytes != null && imageBytes.isNotEmpty) {
          await uploadNoteThumbnail(imageBytes, pageId);
          //await _fetchPages(); // 최신 썸네일 반영
          debugPrint('썸네일 업로드 완료');
        } else {
          debugPrint('썸네일 이미지 없음 → 업로드 생략');
        }
      } catch (e) {
        debugPrint('썸네일 처리 중 오류: $e');
      } finally {
        _isCapturing = false;
      }
    } catch (e) {
      debugPrint('_saveAnnotation 오류: $e');
      _isCapturing = false;
    }
  }




  /// 필기 저장 debounce 함수 추가
  Timer? _saveDebounce;
  void scheduleAnnotationSave(int pageId) {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(seconds: 2), () => _saveAnnotation(pageId));
  }


  Future<void> _loadAnnotations(int pageId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/pdf/annotations/$pageId'),
      );
      if (response.statusCode == 200) {
        pageStrokes[pageId] = [];

        final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));

        final aspectRatio = pages.firstWhere((p) => p['page_id'] == pageId)['aspect_ratio'] ?? 0.75;

        for (var annotation in data) {
          if (annotation['data']?['lines'] != null) {
            for (var line in annotation['data']['lines']) {
              final List points = line['points'];
              final String colorHex = line['color'] ?? 'ff000000';
              final double strokeWidth = (line['strokeWidth'] ?? 3.0).toDouble();
              final String penType = line['penType'] ?? 'pen';

              final Color baseColor = Color(int.parse(colorHex, radix: 16));
              final paint = Paint()..strokeWidth = strokeWidth;

              switch (penType) {
                case 'brush':
                  paint
                    ..color = baseColor.withOpacity(0.85)
                    ..blendMode = BlendMode.srcOver
                    ..style = PaintingStyle.stroke
                    ..strokeCap = StrokeCap.round
                    ..strokeJoin = StrokeJoin.round
                    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0);
                  break;
                case 'highlighter':
                  paint
                    ..color = baseColor.withOpacity(0.25)
                    ..blendMode = BlendMode.srcATop
                    ..style = PaintingStyle.stroke
                    ..strokeCap = StrokeCap.butt;
                  break;
                default:
                  paint
                    ..color = baseColor
                    ..blendMode = BlendMode.srcOver
                    ..style = PaintingStyle.stroke
                    ..strokeCap = StrokeCap.round;
              }

              final strokePoints = points.map<Offset>((p) {
                final dx = (p['x'] ?? 0).toDouble();
                final dy = (p['y'] ?? 0).toDouble() / aspectRatio;
                return Offset(dx, dy);
              }).toList();

              pageStrokes[pageId]!.add(Stroke(
                points: strokePoints,
                paint: paint,
                penType: penType,
              ));
            }
          }
        }

        setState(() {});
      }
    } catch (e) {
      debugPrint('_loadAnnotations 오류: $e');
    }
  }




  Future<void> _loadAllAnnotations() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/pdf/annotations/by_pdf/${widget.pdfId}'),
      );

      if (response.statusCode != 200) return;

      final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
      data.sort((a, b) => (a['page_id'] as int).compareTo(b['page_id'] as int));

      for (var annotation in data) {
        final int pageId = annotation['page_id'];
        final double aspectRatio =
            pages.firstWhere((p) => p['page_id'] == pageId)['aspect_ratio'] ?? 0.75;

        final lines = annotation['data']?['lines'];
        if (lines == null || lines.isEmpty) continue;

        // 안전한 초기화
        final strokes = pageStrokes[pageId];
        if (strokes == null) continue;

        for (var line in lines) {
          final stroke = _parseStrokeFromLine(line, aspectRatio);
          if (stroke != null) strokes.add(stroke);
        }
      }

      setState(() {});
    } catch (e) {
      debugPrint('_loadAllAnnotations 오류: $e');
    }
  }

  Stroke? _parseStrokeFromLine(Map<String, dynamic> line, double aspectRatio) {
    try {
      final List points = line['points'];
      if (points.isEmpty) return null;

      final String colorHex = line['color'] ?? 'ff000000';
      final double strokeWidth = (line['strokeWidth'] ?? 3.0).toDouble();
      final String penType = line['penType'] ?? 'pen';

      final Color baseColor = Color(int.parse(colorHex, radix: 16));
      final paint = _buildPaintFromPenType(penType, baseColor, strokeWidth);

      final strokePoints = points.map<Offset>((p) {
        final double dx = (p['x'] as num).toDouble();
        final double dy = (p['y'] as num).toDouble() / aspectRatio;
        return Offset(dx, dy);
      }).toList();

      return Stroke(points: strokePoints, paint: paint, penType: penType);
    } catch (_) {
      return null;
    }
  }

  Paint _buildPaintFromPenType(String penType, Color color, double strokeWidth) {
    final paint = Paint()..strokeWidth = strokeWidth;
    switch (penType) {
      case 'brush':
        return paint
          ..color = color.withOpacity(0.85)
          ..blendMode = BlendMode.srcOver
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0);
      case 'highlighter':
        return paint
          ..color = color.withOpacity(0.25)
          ..blendMode = BlendMode.srcATop
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.butt;
      default:
        return paint
          ..color = color
          ..blendMode = BlendMode.srcOver
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;
    }
  }






  Future<Uint8List?> _captureThumbnailImage(int pageId) async {
    try {
      // 1️. 페이지 정보 불러오기
      final page = pages.firstWhere((p) => p['page_id'] == pageId);
      final pageNumber = page['page_number'];
      final aspectRatio = page['aspect_ratio'] ?? 0.75;  // 기본값 4:3

      // 2️. 렌더링 해상도 계산 (width 고정)
      const double canvasWidth = 1080;
      final double canvasHeight = canvasWidth / aspectRatio;

      // 3️. PDF 렌더링 이미지 URL 생성
      final imageUrl = '$baseUrl/pdf/page-image/${widget.pdfId}/$pageNumber';
      final imageProvider = CachedNetworkImageProvider(imageUrl);
      final completer = Completer<ui.Image>();
      final stream = imageProvider.resolve(const ImageConfiguration());
      stream.addListener(ImageStreamListener((imageInfo, _) {
        completer.complete(imageInfo.image);
      }));
      final pdfImage = await completer.future;

      // 4️. 합성 캔버스 생성
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, canvasWidth, canvasHeight));

      // 5️. PDF 배경 이미지 비율 맞춰서 그림
      canvas.drawImageRect(
        pdfImage,
        Rect.fromLTWH(0, 0, pdfImage.width.toDouble(), pdfImage.height.toDouble()),
        Rect.fromLTWH(0, 0, canvasWidth, canvasHeight),
        Paint(),
      );

      // 6️. 필기 stroke 그리기
      final strokes = pageStrokes[pageId] ?? [];
      for (final stroke in strokes) {
        if (stroke.points.length < 2) continue;

        final path = Path();
        path.moveTo(stroke.points[0].dx, stroke.points[0].dy);
        for (int i = 1; i < stroke.points.length - 1; i++) {
          final p1 = stroke.points[i];
          final p2 = stroke.points[i + 1];
          final mid = Offset((p1.dx + p2.dx) / 2, (p1.dy + p2.dy) / 2);
          path.quadraticBezierTo(p1.dx, p1.dy, mid.dx, mid.dy);
        }
        path.lineTo(stroke.points.last.dx, stroke.points.last.dy);
        canvas.drawPath(path, stroke.paint);
      }

      // 7️. 최종 이미지 생성
      final picture = recorder.endRecording();
      final ui.Image resultImage = await picture.toImage(canvasWidth.toInt(), canvasHeight.toInt());
      final byteData = await resultImage.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint('썸네일 합성 오류: $e');
      return null;
    }
  }




  Future<void> uploadNoteThumbnail(Uint8List imageBytes, int pageId) async {
    try {
      final url = Uri.parse('$baseUrl/pdf/thumbnails'); // baseUrl 활용

      final request = http.MultipartRequest('POST', url)
        ..fields['page_id'] = pageId.toString()
        ..files.add(
          http.MultipartFile.fromBytes(
            'file',
            imageBytes,
            filename: 'thumbnail.png',
            contentType: MediaType('image', 'png'),
          ),
        );

      final response = await request.send();

      if (response.statusCode == 200) {
        debugPrint('썸네일 업로드 성공: page_id $pageId');
      } else {
        final body = await response.stream.bytesToString(); 
        debugPrint('썸네일 업로드 실패: ${response.statusCode} - $body');
      }
    } catch (e) {
      debugPrint('썸네일 업로드 중 예외: $e');
    }
  }


  Widget _buildPenOptions() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _penToolItem('펜', PhosphorIcons.pencilSimple(), 'pen'),
          _penToolItem('브러쉬', PhosphorIcons.paintBrush(), 'brush'),
          _penToolItem('형광펜', PhosphorIcons.highlighterCircle(), 'highlighter'),
          _thicknessSlider(),
          _colorSelector(),
        ],
      ),

    );
  }

  Widget _penToolItem(String label, IconData icon, String type) {
    final isSelected = _selectedPenType == type;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPenType = type;
          currentMode = DrawMode.pen;

          // 선택 도구에 따른 스타일 기본값 설정
          if (type == 'highlighter') {
            currentColor = Colors.yellow.withOpacity(0.5);
            strokeWidth = 10;
          } else {
            currentColor = Colors.black;
            strokeWidth = 3;
          }
        });
      },
      child: Column(
        children: [
          Icon(icon, color: isSelected ? Colors.blue : Colors.grey, size: 28),
          Text(label, style: TextStyle(color: isSelected ? Colors.blue : Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _thicknessSlider() {
    return Column(
      children: [
        const Text('굵기', style: TextStyle(fontSize: 12)),
        Slider(
          min: 1,
          max: 20,
          value: strokeWidth,
          onChanged: (value) => setState(() => strokeWidth = value),
          divisions: 19,
          label: strokeWidth.toInt().toString(),
        ),
      ],
    );
  }

  Widget _colorSelector() {
    final List<Color> colors = [Colors.black, Colors.red, Colors.green, Colors.blue, Colors.orange];

    return Column(
      children: [
        const Text('색상', style: TextStyle(fontSize: 12)),
        Row(
          children: [
            ...colors.map((color) {
              final isSelected = currentColor.value == color.value;
              return GestureDetector(
                onTap: () => setState(() => currentColor = color),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(color: isSelected ? Colors.blue : Colors.grey, width: 2),
                  ),
                ),
              );
            }).toList(),

            // 사용자 정의 색상 선택용 팔레트 버튼
            GestureDetector(
              onTap: _showColorPicker,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: currentColor,
                  border: Border.all(color: Colors.black, width: 1),
                ),
                child: const Icon(Icons.add, size: 16, color: Colors.white),
              ),
            ),
          ],
        ),
      ],
    );
  }



  Path _smoothPathFromPoints(List<Offset> points) {
    final path = Path();
    if (points.isEmpty) return path;
    path.moveTo(points[0].dx, points[0].dy);
    for (int i = 1; i < points.length - 1; i++) {
      final p1 = points[i];
      final p2 = points[i + 1];
      final mid = Offset((p1.dx + p2.dx) / 2, (p1.dy + p2.dy) / 2);
      path.quadraticBezierTo(p1.dx, p1.dy, mid.dx, mid.dy);
    }
    path.lineTo(points.last.dx, points.last.dy);
    return path;
  }

  void _showColorPicker() {
    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text('색상 선택'),
          content: SingleChildScrollView(
            child: ColorPicker(
              pickerColor: currentColor,
              onColorChanged: (color) => setState(() => currentColor = color),
              showLabel: false,
              pickerAreaHeightPercent: 0.8,
            ),
          ),
          actions: [
            TextButton(
              child: const Text('닫기'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }


  Future<void> _ensureWidgetIsRendered(GlobalKey key) async {
    BuildContext? context = key.currentContext;
    if (context == null) return;

    RenderBox? renderBox = key.currentContext?.findRenderObject() as RenderBox?;
    while (renderBox == null || !renderBox.attached || renderBox.size.isEmpty) {
      await Future.delayed(const Duration(milliseconds: 50));
      renderBox = key.currentContext?.findRenderObject() as RenderBox?;
    }
  }



  Widget _buildPdfBackground(String imageUrl, double width, double height) {
    if (imageUrl.isEmpty || imageUrl.contains("null")) {
      return const SizedBox.shrink(); // 빈노트용 처리
    }

    return IgnorePointer( // PDF 이미지는 터치 이벤트 무시
      child: SizedBox(
        width: width,
        height: height,
        child: CachedNetworkImage(
          imageUrl: '$imageUrl?timestamp=${DateTime.now().millisecondsSinceEpoch}',
          cacheKey: imageUrl,
          fit: BoxFit.contain, // 비율 유지하여 정확한 위치 정렬
          placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
          errorWidget: (context, url, error) => const SizedBox.shrink(),
        ),
      ),
    );
  }

  Widget _buildHandwritingLayer(int pageId, double width, double height) {
    return Center(
      child: SizedBox(
        width: width,
        height: height,
        child: GestureDetector(
          behavior: HitTestBehavior.translucent, 
          onTapDown: (details) {
            final local = details.localPosition;
            final scene = _controllers[currentPageIndex].toScene(local);
            final pageId = pages[currentPageIndex]['page_id'];
            final strokes = pageStrokes[pageId]!;

            final selectedPoints = <Offset>[];
            for (final index in selectedIndexes) {
              selectedPoints.addAll(strokes[index].points);
            }

            if (selectedPoints.isEmpty) return;

            final selectionRect = Rect.fromPoints(
              selectedPoints.reduce((a, b) => Offset(
                a.dx < b.dx ? a.dx : b.dx,
                a.dy < b.dy ? a.dy : b.dy,
              )),
              selectedPoints.reduce((a, b) => Offset(
                a.dx > b.dx ? a.dx : b.dx,
                a.dy > b.dy ? a.dy : b.dy,
              )),
            );

            const handleHitBoxSize = 44.0;
            final handles = [
              selectionRect.topLeft,
              selectionRect.topRight,
              selectionRect.bottomLeft,
              selectionRect.bottomRight,
            ];
            final tappedHandle = handles.any((handle) =>
              Rect.fromCenter(center: handle, width: handleHitBoxSize, height: handleHitBoxSize)
                  .contains(scene)
            );

            if (selectionRect.inflate(20).contains(scene) || tappedHandle) return;

            // 약간 지연 후 선택 해제 (LongPress가 먼저 처리되게)
            Future.delayed(const Duration(milliseconds: 150), () {
              if (!mounted) return;
              if (ModalRoute.of(context)?.isCurrent != true) return;

              selectedIndexes.clear();
              currentMode = DrawMode.lasso;
              setState(() {});
            });
          },


          onLongPressStart: (details) {
            final local = details.localPosition;
            final scene = _controllers[currentPageIndex].toScene(local);
            final pageId = pages[currentPageIndex]['page_id'];
            final strokes = pageStrokes[pageId]!;

            // 선택된 필기 stroke들의 bounding box 구하기
            final selectedPoints = <Offset>[];
            for (final index in selectedIndexes) {
              selectedPoints.addAll(strokes[index].points);
            }

            if (selectedPoints.isEmpty) return;

            final selectionRect = Rect.fromPoints(
              selectedPoints.reduce((a, b) => Offset(
                a.dx < b.dx ? a.dx : b.dx,
                a.dy < b.dy ? a.dy : b.dy,
              )),
              selectedPoints.reduce((a, b) => Offset(
                a.dx > b.dx ? a.dx : b.dx,
                a.dy > b.dy ? a.dy : b.dy,
              )),
            );

            // 핸들 hitbox까지 포함해서 체크
            const handleHitBoxSize = 44.0;
            final handles = [
              selectionRect.topLeft,
              selectionRect.topRight,
              selectionRect.bottomLeft,
              selectionRect.bottomRight,
            ];
            final tappedHandle = handles.any((handle) =>
              Rect.fromCenter(center: handle, width: handleHitBoxSize, height: handleHitBoxSize).contains(scene)
            );

            // 바운딩 박스 내부나 핸들 안일 경우만 메뉴 표시
            if (selectionRect.inflate(20).contains(scene) || tappedHandle) {
              _showSelectionMenu(details.globalPosition);
            } else if (copiedStrokes.isNotEmpty) {
              _showPasteMenu(details.globalPosition);
            }
          },
          child: CustomPaint(
            painter: _LassoNotePainter(
              pageStrokes[pageId] ?? [],
              lassoPoints,
              selectedIndexes,
              _controllers[currentPageIndex].value.getMaxScaleOnAxis(),
              _controllers[currentPageIndex], 
            ),
            size: Size(width, height), 
          ),
        ),
      ),
    );
  }

  void _copySelection() {
    final pageId = pages[currentPageIndex]['page_id'];
    final strokes = pageStrokes[pageId]!;

    copiedStrokes = selectedIndexes.map((i) {
      final original = strokes[i];
      return Stroke(
        points: List.from(original.points),
        paint: original.paint,
        penType: original.penType,
      );
    }).toList();

    debugPrint("복사 완료: ${copiedStrokes.length}개 stroke");
  }

  void _pasteSelection() {
    if (copiedStrokes.isEmpty) return;

    final pageId = pages[currentPageIndex]['page_id'];
    final strokes = pageStrokes[pageId]!;

    const Offset offset = Offset(50, 50); 
    final startIndex = strokes.length;

    for (final stroke in copiedStrokes) {
      final newStroke = Stroke(
        points: stroke.points.map((p) => p + offset).toList(),
        paint: stroke.paint,
        penType: stroke.penType,
      );
      strokes.add(newStroke);
    }

    selectedIndexes = List.generate(copiedStrokes.length, (i) => startIndex + i).toSet();

    debugPrint("📋 붙여넣기 완료: ${copiedStrokes.length}개 stroke");
    setState(() {
      currentMode = DrawMode.transform;
    });
  }


  void _showSelectionMenu(Offset globalPosition) {
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        globalPosition.dx, globalPosition.dy, globalPosition.dx, globalPosition.dy),
      items: [
        PopupMenuItem(
          child: const Text('복사'),
          onTap: () {
            Future.delayed(Duration.zero, () {
              if (context.mounted) _copySelection();
            });
          },
        ),
        PopupMenuItem(
          child: const Text('삭제'),
          onTap: () {
            Future.delayed(Duration.zero, () {
              if (context.mounted) _deleteSelection();
            });
          },
        ),
      ],
    );
  }




  void _showPasteMenu(Offset globalPosition) {
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        globalPosition.dx, globalPosition.dy, globalPosition.dx, globalPosition.dy),
      items: [
        PopupMenuItem(
          child: const Text('붙여넣기'),
          onTap: _pasteSelection,
        ),
      ],
    );
  }








}


  class _LassoNotePainter extends CustomPainter {
    final List<Stroke> strokes;
    final List<Offset> lassoPoints;
    final Set<int> selectedIndexes;
    final double scale;
    final TransformationController controller;

    _LassoNotePainter(
      this.strokes,
      this.lassoPoints,
      this.selectedIndexes,
      this.scale,
      this.controller,
    );

    Rect _computeBoundingBox(List<Stroke> strokes, Set<int> selectedIndexes) {
      final selectedPoints = <Offset>[];
      for (var index in selectedIndexes) {
        selectedPoints.addAll(strokes[index].points);
      }
      if (selectedPoints.isEmpty) return Rect.zero;

      double minX = selectedPoints.first.dx;
      double maxX = selectedPoints.first.dx;
      double minY = selectedPoints.first.dy;
      double maxY = selectedPoints.first.dy;

      for (var point in selectedPoints) {
        if (point.dx < minX) minX = point.dx;
        if (point.dx > maxX) maxX = point.dx;
        if (point.dy < minY) minY = point.dy;
        if (point.dy > maxY) maxY = point.dy;
      }

      return Rect.fromLTRB(minX, minY, maxX, maxY);
    }

    Path _smoothPathFromPoints(List<Offset> points) {
      final path = Path();
      if (points.isEmpty) return path;
      path.moveTo(points[0].dx, points[0].dy);
      for (int i = 1; i < points.length - 1; i++) {
        final p1 = points[i];
        final p2 = points[i + 1];
        final mid = Offset((p1.dx + p2.dx) / 2, (p1.dy + p2.dy) / 2);
        path.quadraticBezierTo(p1.dx, p1.dy, mid.dx, mid.dy);
      }
      path.lineTo(points.last.dx, points.last.dy);
      return path;
    }

    @override
    void paint(Canvas canvas, Size size) {
      // 1. 라쏘 경로
      if (lassoPoints.isNotEmpty) {
        final lassoPaint = Paint()
          ..color = Colors.blueAccent
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5 / scale;

        final sceneLassoPoints = lassoPoints.map((p) => controller.toScene(p)).toList();
        final lassoPath = Path()..addPolygon(sceneLassoPoints, false);
        final dashedPath = dashPath(
          lassoPath,
          dashArray: CircularIntervalList<double>(<double>[6.0 / scale, 4.0 / scale]),
        );
        canvas.drawPath(dashedPath, lassoPaint);
      }

      // 2. 선택 사각형 및 핸들
      if (selectedIndexes.isNotEmpty) {
        final box = _computeBoundingBox(strokes, selectedIndexes);

        final dashedRectPath = dashPath(
          Path()..addRect(box),
          dashArray: CircularIntervalList<double>(<double>[6 / scale, 4 / scale]),
        );

        final dashedPaint = Paint()
          ..color = Colors.blue
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5 / scale;

        canvas.drawPath(dashedRectPath, dashedPaint);

       
        final handleVisualSize = 12.0 / scale; 
        final handles = [
          box.topLeft,
          box.topRight,
          box.bottomLeft,
          box.bottomRight,
        ];

        final handlePaint = Paint()..color = Colors.blueAccent;
        for (final handle in handles) {
          canvas.drawRect(
            Rect.fromCenter(center: handle, width: handleVisualSize, height: handleVisualSize),
            handlePaint,
          );
        }
      }

      // 3. 필기 stroke 그리기
      for (int i = 0; i < strokes.length; i++) {
        final stroke = strokes[i];
        if (stroke.points.length < 2) continue;

        final isSelected = selectedIndexes.contains(i);

        final basePaint = Paint()
          ..color = stroke.paint.color
          ..strokeWidth = stroke.paint.strokeWidth
          ..strokeCap = stroke.paint.strokeCap
          ..strokeJoin = StrokeJoin.round
          ..style = stroke.paint.style
          ..isAntiAlias = true
          ..blendMode = stroke.penType == 'highlighter'
              ? BlendMode.srcOver
              : stroke.paint.blendMode;

        // Glow 효과 (선택 시)
        if (isSelected) {
          final glowPaint = Paint()
            ..color = const Color(0xFF90CAF9).withOpacity(0.6) // 연한 하늘색
            ..strokeWidth = basePaint.strokeWidth + 5
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

          final glowPath = stroke.penType == 'brush'
              ? _smoothPathFromPoints(stroke.points)
              : (Path()..addPolygon(stroke.points, false));

          canvas.drawPath(glowPath, glowPaint);
        }

        if (stroke.penType == 'highlighter') {
          final path = Path()..moveTo(stroke.points[0].dx, stroke.points[0].dy);
          for (int j = 1; j < stroke.points.length; j++) {
            path.lineTo(stroke.points[j].dx, stroke.points[j].dy);
          }
          canvas.drawPath(path, basePaint);
        } else if (stroke.penType == 'brush') {
          final path = _smoothPathFromPoints(stroke.points);
          canvas.drawPath(path, basePaint);
        } else {
          for (int j = 0; j < stroke.points.length - 1; j++) {
            canvas.drawLine(stroke.points[j], stroke.points[j + 1], basePaint);
          }
        }
      }
    }

    @override
    bool shouldRepaint(CustomPainter oldDelegate) => true;
  }


class ThumbnailCanvas extends StatelessWidget {
  final List<Stroke> strokes;
  final double width;
  final double height;

  const ThumbnailCanvas({
    super.key,
    required this.strokes,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        painter: _ThumbnailPainter(strokes),
      ),
    );
  }
}

  class _ThumbnailPainter extends CustomPainter {
    final List<Stroke> strokes;

    _ThumbnailPainter(this.strokes);

    @override
    void paint(Canvas canvas, Size size) {
      if (strokes.isEmpty) return;

      // 전체 stroke 좌표 범위를 구함
      double minX = double.infinity;
      double minY = double.infinity;
      double maxX = double.negativeInfinity;
      double maxY = double.negativeInfinity;

      for (final stroke in strokes) {
        for (final p in stroke.points) {
          minX = p.dx < minX ? p.dx : minX;
          minY = p.dy < minY ? p.dy : minY;
          maxX = p.dx > maxX ? p.dx : maxX;
          maxY = p.dy > maxY ? p.dy : maxY;
        }
      }

      final contentWidth = maxX - minX;
      final contentHeight = maxY - minY;

      // 캔버스 크기에 맞게 스케일 비율 계산
      final scaleX = size.width / (contentWidth == 0 ? 1 : contentWidth);
      final scaleY = size.height / (contentHeight == 0 ? 1 : contentHeight);
      final scale = scaleX < scaleY ? scaleX : scaleY;

      // 중앙 정렬을 위한 offset 계산
      final dx = (size.width - contentWidth * scale) / 2;
      final dy = (size.height - contentHeight * scale) / 2;

      for (final stroke in strokes) {
        final paint = Paint()
          ..color = stroke.paint.color.withOpacity(0.9)
          ..strokeWidth = stroke.paint.strokeWidth * 0.5
          ..strokeCap = StrokeCap.round
          ..style = stroke.paint.style;

        for (int i = 0; i < stroke.points.length - 1; i++) {
          final p1 = stroke.points[i];
          final p2 = stroke.points[i + 1];
          canvas.drawLine(
            Offset((p1.dx - minX) * scale + dx, (p1.dy - minY) * scale + dy),
            Offset((p2.dx - minX) * scale + dx, (p2.dy - minY) * scale + dy),
            paint,
          );
        }
      }
    }

    @override
    bool shouldRepaint(covariant _ThumbnailPainter oldDelegate) {
      return oldDelegate.strokes != strokes;
    }
  }


