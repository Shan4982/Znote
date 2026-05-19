import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'stroke_model.dart';

class InkEngine extends ChangeNotifier {
  static const _uuid = Uuid();

  final List<Stroke> _strokes = [];
  Stroke? _activeStroke;
  List<StrokePoint> _lastSamples = [];

  Color color = Colors.black;
  double width = 2.0;
  PenType type = PenType.pen;
  BlendMode blend = BlendMode.srcOver;

  List<Stroke> get strokes => List.unmodifiable(_strokes);
  Stroke? get activeStroke => _activeStroke;

  void setColor(Color c) {
    color = c;
    notifyListeners();
  }

  void setWidth(double w) {
    width = w;
    notifyListeners();
  }

  void setType(PenType t) {
    type = t;
    blend = t == PenType.highlighter ? BlendMode.multiply : BlendMode.srcOver;
    notifyListeners();
  }

  void onPointerDown(PointerDownEvent event) {
    _activeStroke = Stroke(
      id: _uuid.v4(),
      points: [StrokePoint(x: event.localPosition.dx, y: event.localPosition.dy)],
      color: color,
      width: width,
      type: type,
      blend: blend,
    );
    _lastSamples = [_activeStroke!.points.first];
    notifyListeners();
  }

  void onPointerMove(PointerMoveEvent event) {
    if (_activeStroke == null) return;
    final newPoint = StrokePoint(
      x: event.localPosition.dx,
      y: event.localPosition.dy,
      pressure: event.pressure.clamp(0.0, 1.0),
      timestamp: event.timeStamp.inMicroseconds,
    );
    _lastSamples.add(newPoint);
    _activeStroke = _activeStroke!.copyWith(points: _smoothPoints(_lastSamples));
    notifyListeners();
  }

  List<StrokePoint> _smoothPoints(List<StrokePoint> raw) {
    if (raw.length < 3) return raw;
    final smoothed = <StrokePoint>[raw.first];
    for (int i = 1; i < raw.length - 1; i++) {
      final a = raw[i - 1];
      final b = raw[i];
      final c = raw[i + 1];
      smoothed.add(StrokePoint(
        x: (a.x + b.x + c.x) / 3,
        y: (a.y + b.y + c.y) / 3,
        pressure: b.pressure,
        timestamp: b.timestamp,
      ));
    }
    smoothed.add(raw.last);
    return smoothed;
  }

  void onPointerUp(PointerUpEvent event) {
    if (_activeStroke == null) return;
    final finalStroke = _activeStroke!.copyWith(points: _smoothPoints(_lastSamples));
    _strokes.add(finalStroke);
    _activeStroke = null;
    _lastSamples = [];
    notifyListeners();
  }

  void eraseAt(Offset position, double radius) {
    _strokes.removeWhere((stroke) {
      return stroke.points.any((p) => (p.offset - position).distance <= radius);
    });
    notifyListeners();
  }

  Set<String> selectInRect(ui.Rect rect) {
    final ids = <String>{};
    for (final stroke in _strokes) {
      if (stroke.points.any((p) => rect.contains(p.offset))) {
        ids.add(stroke.id);
      }
    }
    return ids;
  }

  void moveStrokes(Set<String> ids, Offset delta) {
    for (int i = 0; i < _strokes.length; i++) {
      if (ids.contains(_strokes[i].id)) {
        _strokes[i] = _strokes[i].copyWith(
          points: _strokes[i].points
              .map((p) => StrokePoint(
                    x: p.x + delta.dx,
                    y: p.y + delta.dy,
                    pressure: p.pressure,
                    timestamp: p.timestamp,
                  ))
              .toList(),
        );
      }
    }
    notifyListeners();
  }

  void clear() {
    _strokes.clear();
    notifyListeners();
  }

  void undo() {
    if (_strokes.isNotEmpty) {
      _strokes.removeLast();
      notifyListeners();
    }
  }
}
