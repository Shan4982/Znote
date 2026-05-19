import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/providers.dart';
import '../../core/storage/database.dart';
import '../../core/storage/file_storage.dart';
import 'package:drift/drift.dart' hide Column;
import 'widgets/notebook_tree_panel.dart';
import 'widgets/page_grid_panel.dart';
import '../editor/editor_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String? _selectedNotebookId;

  @override
  Widget build(BuildContext context) {
    final dbAsync = ref.watch(databaseProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('ZNote'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, size: 22),
            onPressed: () {},
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, size: 22),
            onSelected: (value) {
              if (value == 'sort') {
                // sort placeholder
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(value: 'sort', child: Text('排序')),
            ],
          ),
        ],
      ),
      body: dbAsync.when(
        data: (db) => _buildBody(db),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败: $e')),
      ),
      floatingActionButton: _selectedNotebookId == null
          ? FloatingActionButton(
              onPressed: () => _createQuickPage(),
              child: const Icon(Icons.add, size: 28),
            )
          : null,
    );
  }

  Widget _buildBody(AppDatabase db) {
    // Auto-select first notebook if none selected
    if (_selectedNotebookId == null) {
      db.allNotebooks().then((notebooks) {
        if (notebooks.isNotEmpty && mounted) {
          setState(() => _selectedNotebookId = notebooks.first.id);
        }
      });
    }

    return Row(
      children: [
        NotebookTreePanel(
          selectedNotebookId: _selectedNotebookId,
          onNotebookSelected: (id) => setState(() => _selectedNotebookId = id),
        ),
        Expanded(
          child: _selectedNotebookId != null
              ? PageGridPanel(notebookId: _selectedNotebookId!)
              : _buildEmptyState(),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.book_outlined, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            '选择或创建一个笔记本',
            style: TextStyle(
              color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _createQuickPage() async {
    final db = await ref.read(databaseProvider.future);
    final fs = await ref.read(fileStorageProvider.future);

    // Create a default notebook if none exists
    final notebooks = await db.allNotebooks();
    String notebookId;
    if (notebooks.isEmpty) {
      notebookId = FileStorage.generateId();
      await fs.ensureNotebookDirs(notebookId);
      await db.createNotebook(NotebooksCompanion(
        id: Value(notebookId),
        title: const Value('我的笔记本'),
        coverColor: Value(Colors.primaries[0].toARGB32()),
        createdAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
        sortOrder: Value(0),
      ));
    } else {
      notebookId = notebooks.first.id;
    }

    final pageCount = (await db.notebookPages(notebookId)).length;
    final pageId = FileStorage.generateId();
    await db.createPage(PagesCompanion(
      id: Value(pageId),
      notebookId: Value(notebookId),
      title: const Value(''),
      paperType: const Value('blank'),
      backgroundColor: const Value(0xFFFFFFFF),
      createdAt: Value(DateTime.now()),
      updatedAt: Value(DateTime.now()),
      sortOrder: Value(pageCount),
    ));

    setState(() => _selectedNotebookId = notebookId);

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => EditorScreen(notebookId: notebookId, pageId: pageId),
        ),
      );
    }
  }
}
