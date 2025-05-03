// 📄 note_page.dart
import 'package:flutter/material.dart';
import 'package:path_drawing/path_drawing.dart'; // 추가


enum DrawMode { pen, highlighter, eraser, lasso }

class NotePage extends StatefulWidget {
  const NotePage({super.key});

  @override
  State<NotePage> createState() => _NotePageState();
}

class _NotePageState extends State<NotePage> {
  List<Offset?> points = [];
  List<Paint> paints = [];

  DrawMode currentMode = DrawMode.pen;
  Color currentColor = Colors.black;
  double strokeWidth = 3.0;

  // lasso 관련
  List<Offset> lassoPoints = [];
  Set<int> selectedIndexes = {};
  Offset? dragStart;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('노트'),
        actions: [
          IconButton(
            icon: Icon(Icons.edit, color: currentMode == DrawMode.pen ? Colors.blue : Colors.black),
            onPressed: () => _setMode(DrawMode.pen),
          ),
          IconButton(
            icon: Icon(Icons.highlight, color: currentMode == DrawMode.highlighter ? Colors.blue : Colors.black),
            onPressed: () => _setMode(DrawMode.highlighter),
          ),
          IconButton(
            icon: Icon(Icons.auto_fix_normal, color: currentMode == DrawMode.eraser ? Colors.blue : Colors.black),
            onPressed: () => _setMode(DrawMode.eraser),
          ),
          IconButton(
            icon: Icon(Icons.all_inclusive, color: currentMode == DrawMode.lasso ? Colors.blue : Colors.black),
            onPressed: () => _setMode(DrawMode.lasso),
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _deleteSelection,
          ),
        ],
      ),
      body: GestureDetector(
        onPanStart: (details) {
          if (currentMode == DrawMode.lasso) {
            if (selectedIndexes.isNotEmpty) {
              dragStart = details.localPosition;
            } else {
              lassoPoints.clear();
              selectedIndexes.clear();
            }
          } else if (currentMode == DrawMode.pen || currentMode == DrawMode.highlighter || currentMode == DrawMode.eraser) {
            points.add(details.localPosition);
            paints.add(_createPaint());
          }
        },
        onPanUpdate: (details) {
          setState(() {
            if (currentMode == DrawMode.lasso) {
              if (dragStart != null && selectedIndexes.isNotEmpty) {
                final Offset diff = details.localPosition - dragStart!;
                _moveSelection(diff);
                dragStart = details.localPosition;
              } else {
                lassoPoints.add(details.localPosition);
              }
            } else if (currentMode == DrawMode.pen || currentMode == DrawMode.highlighter || currentMode == DrawMode.eraser) {
              points.add(details.localPosition);
              paints.add(_createPaint());
            }
          });
        },
        onPanEnd: (details) {
          if (currentMode == DrawMode.lasso) {
            if (selectedIndexes.isEmpty) {
              _selectByLasso();
            }
            dragStart = null;
          } else {
            points.add(null);
            paints.add(Paint());
          }
        },
        onPanCancel: () => dragStart = null,
        child: CustomPaint(
          painter: _LassoNotePainter(points, paints, lassoPoints, selectedIndexes),
          size: Size.infinite,
        ),
      ),
    );
  }

  Paint _createPaint() {
    return Paint()
      ..color = currentMode == DrawMode.eraser ? Colors.transparent : currentColor
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..blendMode = currentMode == DrawMode.eraser ? BlendMode.clear : BlendMode.srcOver;
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
      } else if (mode == DrawMode.eraser) {
        strokeWidth = 20.0;
      }
    });
  }

  void _selectByLasso() {
    Path lassoPath = Path()..addPolygon(lassoPoints, true);
    selectedIndexes.clear();
    for (int i = 0; i < points.length; i++) {
      final p = points[i];
      if (p != null && lassoPath.contains(p)) {
        selectedIndexes.add(i);
      }
    }
    setState(() {});
  }

  void _moveSelection(Offset offset) {
    for (int index in selectedIndexes) {
      points[index] = points[index]! + offset;
    }
    setState(() {});
  }

  void _deleteSelection() {
    for (int index in selectedIndexes) {
      paints[index] = Paint()..blendMode = BlendMode.clear;
    }
    selectedIndexes.clear();
    setState(() {});
  }
}

class _LassoNotePainter extends CustomPainter {
  final List<Offset?> points;
  final List<Paint> paints;
  final List<Offset> lasso;
  final Set<int> selected;

  _LassoNotePainter(this.points, this.paints, this.lasso, this.selected);

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty || paints.isEmpty || points.length < 2 || paints.length < 2 || points.length != paints.length) return;
    
    for (int i = 0; i + 1 < points.length; i++) {
      if (points[i] != null && points[i + 1] != null) {
        final paint = paints[i];
        final isSelected = selected.contains(i) || selected.contains(i + 1);
        final Paint drawPaint = Paint()
          ..color = paint.color
          ..strokeWidth = paint.strokeWidth
          ..strokeCap = paint.strokeCap
          ..blendMode = paint.blendMode;

        if (isSelected && paint.blendMode != BlendMode.clear) {
          drawPaint.color = Colors.red; // 강조 표시
        }

        canvas.drawLine(points[i]!, points[i + 1]!, drawPaint);
      }
    }

    if (lasso.isNotEmpty) {
      final lassoPaint = Paint()
        ..color = Colors.blueAccent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;

      final path = Path()..addPolygon(lasso, true);
      final dashedPath = dashPath(path, dashArray: CircularIntervalList<double>(<double>[6.0, 4.0]));
      canvas.drawPath(dashedPath, lassoPaint);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}
