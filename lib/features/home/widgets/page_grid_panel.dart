import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/providers.dart';
import '../../../core/storage/database.dart';
import '../../editor/editor_screen.dart';

class PageGridPanel extends ConsumerStatefulWidget {
  final String notebookId;

  const PageGridPanel({super.key, required this.notebookId});

  @override
  ConsumerState<PageGridPanel> createState() => _PageGridPanelState();
}

class _PageGridPanelState extends ConsumerState<PageGridPanel> {
  String _formatDate(DateTime dt) => '${dt.year}/${dt.month}/${dt.day}';

  @override
  Widget build(BuildContext context) {
    final dbAsync = ref.watch(databaseProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return dbAsync.when(
      data: (db) => _buildContent(db, isDark),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('加载失败: $e')),
    );
  }

  Widget _buildContent(AppDatabase db, bool isDark) {
    return StreamBuilder<List<NotePage>>(
      stream: db.watchNotebookPages(widget.notebookId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final pages = snapshot.data!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildTitleBar(isDark, db),
            const Divider(height: 1),
            if (pages.isEmpty)
              Expanded(child: _buildEmptyState(isDark))
            else
              Expanded(child: _buildPageGrid(pages, isDark, db)),
          ],
        );
      },
    );
  }

  Widget _buildTitleBar(bool isDark, AppDatabase db) {
    return FutureBuilder<List<Notebook>>(
      future: db.allNotebooks(),
      builder: (context, snapshot) {
        final notebook = snapshot.data?.firstWhere(
          (n) => n.id == widget.notebookId,
          orElse: () => snapshot.data!.first,
        );
        final title = notebook?.title ?? '笔记本';
        final accentColor = notebook != null ? Color(notebook.coverColor) : const Color(0xFF1A73E8);

        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 16, 12),
          child: Row(
            children: [
              Container(
                width: 4, height: 20,
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w600,
                  color: isDark ? Colors.grey.shade100 : const Color(0xFF202124),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.note_add_outlined, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            '还没有页面',
            style: TextStyle(
              color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '点击右上角按钮创建第一页',
            style: TextStyle(
              color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPageGrid(List<NotePage> pages, bool isDark, AppDatabase db) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 80),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.78,
      ),
      itemCount: pages.length,
      itemBuilder: (context, index) => _AnimatedPageCard(
        index: index,
        child: _buildPageCard(pages[index], isDark, db),
      ),
    );
  }

  Widget _buildPageCard(NotePage page, bool isDark, AppDatabase db) {
    final accentColor = const Color(0xFF1A73E8);
    return Card(
      elevation: isDark ? 2 : 1,
      shadowColor: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
      color: isDark ? Colors.grey.shade800 : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => EditorScreen(notebookId: widget.notebookId, pageId: page.id),
            ),
          ).then((_) => setState(() {}));
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(height: 4, color: accentColor),
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey.shade700 : Color(page.backgroundColor),
                  border: Border.all(
                    color: isDark ? Colors.grey.shade600 : Colors.grey.shade200,
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    page.title.isEmpty ? '未命名页面' : page.title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.grey.shade200 : const Color(0xFF202124),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatDate(page.updatedAt),
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.grey.shade500 : Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

}

class _AnimatedPageCard extends StatefulWidget {
  final int index;
  final Widget child;

  const _AnimatedPageCard({required this.index, required this.child});

  @override
  State<_AnimatedPageCard> createState() => _AnimatedPageCardState();
}

class _AnimatedPageCardState extends State<_AnimatedPageCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _opacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _slide = Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    Future.delayed(Duration(milliseconds: 40 * widget.index), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}
