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
            icon: const Icon(Icons.file_upload_outlined),
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
        child: const Icon(Icons.note_add),
      ),
    );
  }

  Widget _buildTitle(AppDatabase db) {
    return StreamBuilder<List<Notebook>>(
      stream: db.watchAllNotebooks(),
      builder: (context, snapshot) {
        final notebook = snapshot.data?.where((n) => n.id == widget.notebookId).firstOrNull;
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
          return const Center(child: Text('还没有页面，点击 + 创建'));
        }
        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.75,
          ),
          itemCount: pages.length,
          itemBuilder: (context, index) => _buildPageCard(pages[index]),
        );
      },
    );
  }

  Widget _buildPageCard(NotePage page) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => EditorScreen(notebookId: widget.notebookId, pageId: page.id),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(flex: 3, child: Container(color: Color(page.backgroundColor))),
            Expanded(
              flex: 1,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Text(
                  page.title,
                  style: Theme.of(context).textTheme.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createPage() async {
    final db = ref.read(databaseProvider).valueOrNull;
    if (db == null) return;

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
    // Document import via file picker — stub that shows what's needed.
    // Requires file_picker package for Flutter; here we show the flow.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('请从系统文件选择器选择 PDF 或 Word 文档')),
    );
  }
}
