import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/providers.dart';
import '../../core/plugin/plugin_interface.dart';
import '../../core/plugin/plugin_manager.dart';
import '../../core/ink/ink_engine.dart';
import 'widgets/toolbar.dart';
import 'widgets/page_canvas.dart';

class EditorScreen extends ConsumerStatefulWidget {
  final String notebookId;
  final String pageId;

  const EditorScreen({
    super.key,
    required this.notebookId,
    required this.pageId,
  });

  @override
  ConsumerState<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends ConsumerState<EditorScreen> {
  late final PageContext _pageContext;

  @override
  void initState() {
    super.initState();
    _pageContext = PageContext(
      inkEngine: ref.read(inkEngineNotifierProvider),
      notebookId: widget.notebookId,
      pageId: widget.pageId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final inkEngine = ref.watch(inkEngineNotifierProvider);
    final pluginManagerAsync = ref.watch(pluginManagerProvider);

    return pluginManagerAsync.when(
      data: (pm) => _buildEditor(inkEngine, pm),
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('加载失败: $e'))),
    );
  }

  Widget _buildEditor(InkEngine inkEngine, PluginManager pm) {
    return Scaffold(
      body: Column(
        children: [
          // Toolbar at top for landscape, can move to side
          Toolbar(pluginManager: pm, pageContext: _pageContext),
          Expanded(
            child: Listener(
              onPointerDown: (event) {
                final active = pm.activePlugin;
                if (active != null) {
                  active.onPointerDown(_pageContext, event);
                }
              },
              onPointerMove: (event) {
                final active = pm.activePlugin;
                if (active != null) {
                  active.onPointerMove(_pageContext, event);
                }
              },
              onPointerUp: (event) {
                final active = pm.activePlugin;
                if (active != null) {
                  active.onPointerUp(_pageContext, event);
                }
              },
              child: PageCanvas(
                strokes: inkEngine.strokes,
                activeStroke: inkEngine.activeStroke,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
