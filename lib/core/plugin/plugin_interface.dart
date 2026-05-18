import 'package:flutter/material.dart';
import '../ink/ink_engine.dart';

class PageContext {
  final InkEngine inkEngine;
  final String notebookId;
  final String pageId;

  const PageContext({
    required this.inkEngine,
    required this.notebookId,
    required this.pageId,
  });
}

abstract class NotePlugin {
  String get id;
  String get name;
  IconData get icon;
  bool get required => false;

  /// Whether the plugin is shown in the toolbar. Non-required plugins
  /// read their initial state from storage via [PluginManager].
  bool enabled = true;

  Widget? buildToolPanel(BuildContext context);

  void onActivate(PageContext context) {}
  void onDeactivate() {}
  void onPointerDown(PageContext context, PointerDownEvent event) {}
  void onPointerMove(PageContext context, PointerMoveEvent event) {}
  void onPointerUp(PageContext context, PointerUpEvent event) {}
}
