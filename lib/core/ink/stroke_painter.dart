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
      final effectiveWidth = stroke.width * (0.3 + 0.7 * p.pressure);
      canvas.drawCircle(
        Offset(p.x, p.y),
        effectiveWidth / 2,
        Paint()
          ..color = stroke.color
          ..blendMode = stroke.blend
          ..isAntiAlias = true,
      );
      return;
    }

    final paints = <double, Paint>{};
    Paint _paintForWidth(double w) {
      return paints.putIfAbsent(w, () => Paint()
        ..color = stroke.color
        ..strokeWidth = w
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke
        ..isAntiAlias = true
        ..blendMode = stroke.blend);
    }

    for (int i = 0; i < stroke.points.length - 1; i++) {
      final p0 = stroke.points[i];
      final p1 = stroke.points[i + 1];
      final effectiveWidth = stroke.width * (0.3 + 0.7 * ((p0.pressure + p1.pressure) / 2));
      canvas.drawLine(p0.offset, p1.offset, _paintForWidth(effectiveWidth));
    }
  }

  @override
  bool shouldRepaint(covariant StrokePainter oldDelegate) {
    return oldDelegate.activeStroke != activeStroke ||
        oldDelegate.strokes.length != strokes.length;
  }

  @override
  bool get isComplex => true;
}
