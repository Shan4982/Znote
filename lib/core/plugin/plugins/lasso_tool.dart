import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../plugin_interface.dart';

class LassoTool extends NotePlugin {
  Offset? _start;
  Offset? _current;
  Set<String> _selectedIds = {};
  bool _isDragging = false;

  @override
  String get id => 'lasso';

  @override
  String get name => '套索';

  @override
  IconData get icon => Icons.highlight_alt;

  @override
  bool get required => true;

  @override
  Widget? buildToolPanel(BuildContext context) => null;

  @override
  void onPointerDown(PageContext context, PointerDownEvent event) {
    _start = event.localPosition;
    _current = event.localPosition;
  }

  @override
  void onPointerMove(PageContext context, PointerMoveEvent event) {
    _current = event.localPosition;
    final rect = ui.Rect.fromPoints(_start!, _current!);
    _selectedIds = context.inkEngine.selectInRect(rect);
  }

  @override
  void onPointerUp(PageContext context, PointerUpEvent event) {
    _current = null;
    _start = null;
  }

  Set<String> get selectedIds => _selectedIds;

  void clearSelection() => _selectedIds = {};
}
