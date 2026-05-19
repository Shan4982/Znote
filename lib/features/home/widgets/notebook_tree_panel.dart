import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/providers.dart';
import '../../../core/storage/database.dart';
import '../../../core/storage/file_storage.dart';
import '../../editor/editor_screen.dart';
import 'package:drift/drift.dart' hide Column;

class NotebookTreePanel extends ConsumerStatefulWidget {
  final String? selectedNotebookId;
  final ValueChanged<String> onNotebookSelected;

  const NotebookTreePanel({
    super.key,
    required this.selectedNotebookId,
    required this.onNotebookSelected,
  });

  @override
  ConsumerState<NotebookTreePanel> createState() => _NotebookTreePanelState();
}

class _NotebookTreePanelState extends ConsumerState<NotebookTreePanel> {
  final Set<String> _expandedNotebooks = {};

  @override
  Widget build(BuildContext context) {
    final dbAsync = ref.watch(databaseProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ClipRect(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 6, sigmaY: 6),
        child: Container(
          width: 320,
          decoration: BoxDecoration(
            color: (isDark ? Colors.grey.shade900 : Colors.grey.shade50).withValues(alpha: 0.85),
            border: Border(
              right: BorderSide(
                color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(isDark),
              const Divider(height: 1),
              Expanded(
                child: dbAsync.when(
                  data: (db) => _buildTree(db, isDark),
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('加载失败: $e')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
      child: Row(
        children: [
          Text(
            '笔记本',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
          ),
          const Spacer(),
          _BlurIconButton(
            icon: Icons.create_new_folder_outlined,
            tooltip: '新建笔记本',
            onTap: () => _createNotebook(),
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildTree(AppDatabase db, bool isDark) {
    return StreamBuilder<List<Notebook>>(
      stream: db.watchAllNotebooks(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final notebooks = snapshot.data!;
        if (notebooks.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                '点击上方图标新建笔记本',
                style: TextStyle(
                  color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
                  fontSize: 13,
                ),
              ),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 4),
          itemCount: notebooks.length,
          itemBuilder: (context, index) => _buildNotebookNode(notebooks[index], db, isDark),
        );
      },
    );
  }

  Widget _buildNotebookNode(Notebook nb, AppDatabase db, bool isDark) {
    final isExpanded = _expandedNotebooks.contains(nb.id);
    final isSelected = widget.selectedNotebookId == nb.id;
    final accentColor = Color(nb.coverColor);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _NotebookListTile(
          notebook: nb,
          accentColor: accentColor,
          isSelected: isSelected,
          isExpanded: isExpanded,
          isDark: isDark,
          onTap: () {
            widget.onNotebookSelected(nb.id);
            setState(() {
              _expandedNotebooks.add(nb.id);
            });
          },
          onExpand: () {
            setState(() {
              if (isExpanded) {
                _expandedNotebooks.remove(nb.id);
              } else {
                _expandedNotebooks.add(nb.id);
              }
            });
          },
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          child: isExpanded
              ? _buildPageList(db, nb.id, accentColor, isDark)
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildPageList(AppDatabase db, String notebookId, Color accentColor, bool isDark) {
    return StreamBuilder<List<NotePage>>(
      stream: db.watchNotebookPages(notebookId),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Padding(
            padding: const EdgeInsets.only(left: 48, bottom: 4),
            child: Text(
              '暂无页面',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
              ),
            ),
          );
        }
        final pages = snapshot.data!;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: pages.map((page) => _buildPageNode(page, accentColor, isDark)).toList(),
        );
      },
    );
  }

  Widget _buildPageNode(NotePage page, Color accentColor, bool isDark) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => EditorScreen(
                notebookId: page.notebookId,
                pageId: page.id,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.only(left: 48, right: 8),
          child: Container(
            height: 36,
            alignment: Alignment.centerLeft,
            child: Row(
              children: [
                Icon(Icons.description_outlined, size: 16, color: accentColor.withValues(alpha: 0.7)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    page.title.isEmpty ? '未命名页面' : page.title,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.grey.shade300 : const Color(0xFF202124),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _createNotebook() async {
    final controller = TextEditingController();
    final title = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('新建笔记本', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: '输入笔记本名称',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.isEmpty ? '未命名笔记本' : controller.text),
            child: const Text('创建'),
          ),
        ],
      ),
    );
    if (title == null) return;
    final db = await ref.read(databaseProvider.future);
    final fs = await ref.read(fileStorageProvider.future);
    final id = FileStorage.generateId();
    await fs.ensureNotebookDirs(id);
    await db.createNotebook(NotebooksCompanion(
      id: Value(id),
      title: Value(title),
      coverColor: Value(Colors.primaries[id.hashCode % Colors.primaries.length].toARGB32()),
      createdAt: Value(DateTime.now()),
      updatedAt: Value(DateTime.now()),
      sortOrder: Value(0),
    ));
    setState(() => _expandedNotebooks.add(id));
  }
}

class _NotebookListTile extends StatelessWidget {
  final Notebook notebook;
  final Color accentColor;
  final bool isSelected;
  final bool isExpanded;
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback onExpand;

  const _NotebookListTile({
    required this.notebook,
    required this.accentColor,
    required this.isSelected,
    required this.isExpanded,
    required this.isDark,
    required this.onTap,
    required this.onExpand,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected
          ? (isDark ? Colors.grey.shade800 : const Color(0xFFE8F0FE))
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: onExpand,
                  child: AnimatedRotation(
                    turns: isExpanded ? 0.25 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.book_outlined, size: 18, color: accentColor),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    notebook.title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.grey.shade200 : const Color(0xFF202124),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BlurIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool isDark;

  const _BlurIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedScale(
          scale: 1.0,
          duration: const Duration(milliseconds: 150),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
          ),
        ),
      ),
    );
  }
}
