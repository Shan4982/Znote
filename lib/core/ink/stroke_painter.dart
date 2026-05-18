import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'stroke_model.dart';

class StrokePainter extends CustomPainter {
  final List<Stroke> strokes;
  final Stroke? activeStroke;

  const StrokePainter({
    required this.strokes,
    this.activeStroke,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final stroke in [...strokes, if (activeStroke != null) activeStroke!]) {
      _paintStroke(canvas, stroke);
    }
  }

  void _paintStroke(Canvas canvas, Stroke stroke) {
    if (stroke.points.isEmpty) return;
    if (stroke.points.length == 1) {
      final p = stroke.points.first;
      canvas.drawCircle(
        Offset(p.x, p.y),
        stroke.width / 2,
        Paint()
          ..color = stroke.color
          ..blendMode = stroke.blend
          ..isAntiAlias = true,
      );
      return;
    }

    final paint = Paint()
      ..color = stroke.color
      ..strokeWidth = stroke.width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true
      ..blendMode = stroke.blend;

    final path = _buildPath(stroke.points);
    canvas.drawPath(path, paint);
  }

  Path _buildPath(List<StrokePoint> points) {
    final path = Path();
    path.moveTo(points.first.x, points.first.y);

    for (int i = 1; i < points.length - 1; i++) {
      final p0 = points[i - 1];
      final p1 = points[i];
      final p2 = points[i + 1];
      final mid1 = Offset(
        (p0.x + p1.x) / 2,
        (p0.y + p1.y) / 2,
      );
      final mid2 = Offset(
        (p1.x + p2.x) / 2,
        (p1.y + p2.y) / 2,
      );
      path.cubicTo(p1.x, p1.y, mid1.dx, mid1.dy, mid2.dx, mid2.dy);
    }

    if (points.length >= 2) {
      final last = points.last;
      path.lineTo(last.x, last.y);
    }

    return path;
  }

  @override
  bool shouldRepaint(covariant StrokePainter oldDelegate) {
    return oldDelegate.activeStroke != activeStroke ||
        oldDelegate.strokes.length != strokes.length;
  }

  @override
  bool get isComplex => true;
}
