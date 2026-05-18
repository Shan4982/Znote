import 'package:flutter/material.dart';
import '../plugin_interface.dart';

class EraserTool extends NotePlugin {
  static const double _eraseRadius = 20.0;

  @override
  String get id => 'eraser';

  @override
  String get name => '橡皮擦';

  @override
  IconData get icon => Icons.auto_fix_high;

  @override
  bool get required => true;

  @override
  Widget? buildToolPanel(BuildContext context) => null;

  @override
  void onActivate(PageContext context) {
    // visual feedback handled by cursor style in editor screen
  }

  @override
  void onPointerDown(PageContext context, PointerDownEvent event) {
    context.inkEngine.eraseAt(event.localPosition, _eraseRadius);
  }

  @override
  void onPointerMove(PageContext context, PointerMoveEvent event) {
    context.inkEngine.eraseAt(event.localPosition, _eraseRadius);
  }
}
