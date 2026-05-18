import 'dart:ui';

enum PenType { pen, highlighter, eraser }

class StrokePoint {
  final double x;
  final double y;
  final double pressure;
  final int timestamp;

  const StrokePoint({
    required this.x,
    required this.y,
    this.pressure = 1.0,
    this.timestamp = 0,
  });

  Offset get offset => Offset(x, y);

  StrokePoint lerpTo(StrokePoint other, double t) => StrokePoint(
        x: x + (other.x - x) * t,
        y: y + (other.y - y) * t,
        pressure: pressure + (other.pressure - pressure) * t,
        timestamp: timestamp + ((other.timestamp - timestamp) * t).round(),
      );
}

class Stroke {
  final String id;
  final List<StrokePoint> points;
  final Color color;
  final double width;
  final PenType type;
  final BlendMode blend;

  const Stroke({
    required this.id,
    required this.points,
    required this.color,
    this.width = 2.0,
    this.type = PenType.pen,
    this.blend = BlendMode.srcOver,
  });

  Stroke copyWith({
    List<StrokePoint>? points,
    Color? color,
    double? width,
    PenType? type,
  }) =>
      Stroke(
        id: id,
        points: points ?? this.points,
        color: color ?? this.color,
        width: width ?? this.width,
        type: type ?? this.type,
        blend: blend,
      );
}
