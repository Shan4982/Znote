import 'package:flutter/material.dart';
import '../../../core/ink/stroke_model.dart';
import '../../../core/ink/stroke_painter.dart';

class PageCanvas extends StatelessWidget {
  final List<Stroke> strokes;
  final Stroke? activeStroke;

  const PageCanvas({
    super.key,
    required this.strokes,
    this.activeStroke,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: StrokePainter(strokes: strokes, activeStroke: activeStroke),
        size: Size.infinite,
      ),
    );
  }
}
