import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' hide Column;
import 'notebook_detail_screen.dart';
import '../../shared/providers.dart';
import '../../core/storage/database.dart';
import '../../core/storage/file_storage.dart';
import '../editor/editor_screen.dart';

class NotebookListScreen extends ConsumerStatefulWidget {
  const NotebookListScreen({super.key});

  @override
  ConsumerState<NotebookListScreen> createState() => _NotebookListScreenState();
}

class _NotebookListScreenState extends ConsumerState<NotebookListScreen> {
  @override
  Widget build(BuildContext context) {
    final dbAsync = ref.watch(databaseProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('笔记本'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => _openPluginSettings(context),
          ),
        ],
      ),
      body: dbAsync.when(
        data: (db) => _buildNotebookList(db),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败: $e')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _createNotebook(),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildNotebookList(AppDatabase db) {
    return StreamBuilder<List<Notebook>>(
      stream: db.watchAllNotebooks(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final notebooks = snapshot.data!;
        if (notebooks.isEmpty) {
          return const Center(child: Text('还没有笔记本，点击 + 创建'));
        }
        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.75,
          ),
          itemCount: notebooks.length,
          itemBuilder: (context, index) => _buildNotebookCard(notebooks[index], db),
        );
      },
    );
  }

  Widget _buildNotebookCard(Notebook nb, AppDatabase db) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => NotebookDetailScreen(notebookId: nb.id),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 3,
              child: Container(color: Color(nb.coverColor)),
            ),
            Expanded(
              flex: 1,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Text(nb.title, style: Theme.of(context).textTheme.labelLarge),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createNotebook() async {
    final controller = TextEditingController();
    final title = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('新建笔记本'),
        content: TextField(controller: controller, autofocus: true, decoration: const InputDecoration(hintText: '笔记本名称')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
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
      coverColor: Value(Colors.primaries[id.hashCode % Colors.primaries.length].value),
      createdAt: Value(DateTime.now()),
      updatedAt: Value(DateTime.now()),
      sortOrder: Value(0),
    ));
  }

  void _openPluginSettings(BuildContext context) {
    // Navigate to plugin settings — stub for now
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('插件设置页面待实现')));
  }
}
