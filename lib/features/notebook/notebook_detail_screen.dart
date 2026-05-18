import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' hide Column;
import '../../shared/providers.dart';
import '../../core/storage/database.dart';
import '../../core/storage/file_storage.dart';
import '../editor/editor_screen.dart';

class NotebookDetailScreen extends ConsumerStatefulWidget {
  final String notebookId;

  const NotebookDetailScreen({super.key, required this.notebookId});

  @override
  ConsumerState<NotebookDetailScreen> createState() => _NotebookDetailScreenState();
}

class _NotebookDetailScreenState extends ConsumerState<NotebookDetailScreen> {
  late String _currentNotebookId;
  Color _accentColor = const Color(0xFF1A73E8);

  String _formatDate(DateTime dt) => '${dt.year}/${dt.month}/${dt.day}';

  @override
  void initState() {
    super.initState();
    _currentNotebookId = widget.notebookId;
  }

  @override
  Widget build(BuildContext context) {
    final dbAsync = ref.watch(databaseProvider);

    return Scaffold(
      appBar: AppBar(
        title: dbAsync.when(
          data: (db) => _buildTitle(db),
          loading: () => const Text('加载中...'),
          error: (_, __) => const Text('错误'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, size: 22),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.file_upload_outlined, size: 22),
            tooltip: '导入文档',
            onPressed: () => _importDocument(),
          ),
        ],
      ),
      body: dbAsync.when(
        data: (db) => _buildPageList(db),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败: $e')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _createPage(),
        child: const Icon(Icons.add, size: 28),
      ),
    );
  }

  Widget _buildTitle(AppDatabase db) {
    return StreamBuilder<List<Notebook>>(
      stream: db.watchAllNotebooks(),
      builder: (context, snapshot) {
        final notebook = snapshot.data?.where((n) => n.id == widget.notebookId).firstOrNull;
        if (notebook != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() => _accentColor = Color(notebook.coverColor));
            }
          });
        }
        return Text(notebook?.title ?? '笔记本');
      },
    );
  }

  Widget _buildPageList(AppDatabase db) {
    return StreamBuilder<List<NotePage>>(
      stream: db.watchNotebookPages(widget.notebookId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final pages = snapshot.data!;
        if (pages.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.note_add_outlined, size: 64, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                Text('还没有页面', style: TextStyle(color: Colors.grey.shade500, fontSize: 16)),
                const SizedBox(height: 8),
                Text('点击右下角 + 创建第一页',
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
              ],
            ),
          );
        }
        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.85,
          ),
          itemCount: pages.length,
          itemBuilder: (context, index) => _buildPageCard(pages[index]),
        );
      },
    );
  }

  Widget _buildPageCard(NotePage page) {
    return Card(
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => EditorScreen(notebookId: widget.notebookId, pageId: page.id),
            ),
          );
        },
        onLongPress: () => _showDeletePageDialog(page),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 页面对应笔记本色的顶部条
            Container(height: 6, color: _accentColor),
            // 页面内容区 — 显示纸张样式
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Color(page.backgroundColor),
                  border: Border.all(color: Colors.grey.shade200),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: CustomPaint(
                  painter: _PaperStylePainter(paperType: page.paperType),
                  size: Size.infinite,
                ),
              ),
            ),
            // 底部信息
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    page.title.isEmpty ? '未命名页面' : page.title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF202124),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatDate(page.updatedAt),
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createPage() async {
    final db = await ref.read(databaseProvider.future);
    final pageCount = (await db.notebookPages(widget.notebookId)).length;
    final id = FileStorage.generateId();
    await db.createPage(PagesCompanion(
      id: Value(id),
      notebookId: Value(widget.notebookId),
      title: const Value(''),
      paperType: const Value('blank'),
      backgroundColor: const Value(0xFFFFFFFF),
      createdAt: Value(DateTime.now()),
      updatedAt: Value(DateTime.now()),
      sortOrder: Value(pageCount),
    ));
  }

  Future<void> _importDocument() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('请从系统文件选择器选择 PDF 或 Word 文档')),
    );
  }

  Future<void> _showDeletePageDialog(NotePage page) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('删除页面'),
        content: Text('确定要删除此页面吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('取消', style: TextStyle(color: Colors.grey.shade600)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    final db = ref.read(databaseProvider).valueOrNull;
    if (db == null) return;
    await db.deletePage(page.id);
  }
}

// 纸张背景绘制（空白、横线、网格）
class _PaperStylePainter extends CustomPainter {
  final String paperType;

  _PaperStylePainter({required this.paperType});

  @override
  void paint(Canvas canvas, Size size) {
    if (paperType == 'blank') return;

    final paint = Paint()
      ..color = const Color(0xFFE0E0E0)
      ..strokeWidth = 0.5;

    if (paperType == 'ruled') {
      const spacing = 12.0;
      for (double y = spacing; y < size.height; y += spacing) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      }
    } else if (paperType == 'grid') {
      const spacing = 16.0;
      for (double x = spacing; x < size.width; x += spacing) {
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
      }
      for (double y = spacing; y < size.height; y += spacing) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
