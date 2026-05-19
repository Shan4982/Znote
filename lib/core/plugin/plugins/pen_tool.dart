import 'package:flutter/material.dart';
import '../plugin_interface.dart';
import '../../ink/stroke_model.dart';

class PenTool extends NotePlugin {
  @override
  String get id => 'pen';

  @override
  String get name => '笔';

  @override
  IconData get icon => Icons.edit;

  @override
  bool get required => true;

  @override
  Widget? buildToolPanel(BuildContext context) {
    return const _PenPanel();
  }

  @override
  void onActivate(PageContext context) {
    context.inkEngine.setType(PenType.pen);
  }

  @override
  void onPointerDown(PageContext context, PointerDownEvent event) {
    context.inkEngine.onPointerDown(event);
  }

  @override
  void onPointerMove(PageContext context, PointerMoveEvent event) {
    context.inkEngine.onPointerMove(event);
  }

  @override
  void onPointerUp(PageContext context, PointerUpEvent event) {
    context.inkEngine.onPointerUp(event);
  }
}

class _PenPanel extends StatelessWidget {
  const _PenPanel();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(height: 48, child: Center(child: Text('笔工具')));
  }
}
