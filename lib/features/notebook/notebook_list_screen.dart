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
  int _selectedTab = 0; // 0=全部, 1=收藏（预留）

  String _formatDate(DateTime dt) {
    return '${dt.year}/${dt.month}/${dt.day}';
  }

  @override
  Widget build(BuildContext context) {
    final dbAsync = ref.watch(databaseProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('ZNote'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, size: 22),
            onPressed: () {
              // 搜索功能预留
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, size: 22),
            onSelected: (value) {
              if (value == 'settings') {
                _openPluginSettings(context);
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(value: 'settings', child: Text('插件管理')),
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
      floatingActionButton: FloatingActionButton(
        onPressed: () => _createNotebook(),
        child: const Icon(Icons.add, size: 28),
      ),
    );
  }

  Widget _buildBody(AppDatabase db) {
    return Column(
      children: [
        // 分类标签栏
        _buildTabBar(),
        // 笔记本列表
        Expanded(child: _buildNotebookList(db)),
      ],
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          _TabButton(
            title: '全部',
            isSelected: _selectedTab == 0,
            onTap: () => setState(() => _selectedTab = 0),
          ),
          const SizedBox(width: 8),
          _TabButton(
            title: '收藏',
            isSelected: _selectedTab == 1,
            onTap: () => setState(() => _selectedTab = 1),
          ),
          const Spacer(),
          TextButton(
            onPressed: () {
              // 编辑模式预留
            },
            child: const Text('编辑', style: TextStyle(color: Color(0xFF1A73E8), fontSize: 14)),
          ),
        ],
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
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.book_outlined, size: 64, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                Text('还没有笔记本', style: TextStyle(color: Colors.grey.shade500, fontSize: 16)),
                const SizedBox(height: 8),
                Text('点击右下角 + 创建第一个笔记本',
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
          itemCount: notebooks.length,
          itemBuilder: (context, index) => _buildNotebookCard(notebooks[index], db),
        );
      },
    );
  }

  Widget _buildNotebookCard(Notebook nb, AppDatabase db) {
    // 按笔记本标题生成不同的色条颜色
    final accentColor = Color(nb.coverColor);

    return Card(
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => NotebookDetailScreen(notebookId: nb.id),
            ),
          );
        },
        onLongPress: () {
          // 长按删除
          _showDeleteDialog(nb);
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 彩色封面条
            Container(height: 6, color: accentColor),
            // 内容区
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 标题
                    Text(
                      nb.title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF202124),
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    // 日期
                    Text(
                      _formatDate(nb.updatedAt),
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    // 内容预览（预留：后续显示页面数或最后编辑内容）
                    Text(
                      _getPreviewText(db, nb),
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade400,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getPreviewText(AppDatabase db, Notebook nb) {
    // 后续可以查询笔记本中的页面数量并显示
    return '${nb.createdAt.year}/${nb.createdAt.month}/${nb.createdAt.day} 创建';
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
            hintStyle: TextStyle(color: Colors.grey.shade400),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('取消', style: TextStyle(color: Colors.grey.shade600)),
          ),
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
      coverColor: Value(Colors.primaries[id.hashCode % Colors.primaries.length].value),
      createdAt: Value(DateTime.now()),
      updatedAt: Value(DateTime.now()),
      sortOrder: Value(0),
    ));
  }

  Future<void> _showDeleteDialog(Notebook nb) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('删除笔记本'),
        content: Text('确定要删除「${nb.title}」吗？此操作不可撤销。'),
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
    final fs = ref.read(fileStorageProvider).valueOrNull;
    if (fs == null) return;
    await db.deleteNotebook(nb.id);
    await fs.deleteNotebookDirs(nb.id);
  }

  void _openPluginSettings(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('插件设置页面待实现')),
    );
  }
}

// 分类标签按钮
class _TabButton extends StatelessWidget {
  final String title;
  final bool isSelected;
  final VoidCallback onTap;

  const _TabButton({
    required this.title,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE8F0FE) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            color: isSelected ? const Color(0xFF1A73E8) : const Color(0xFF5F6368),
          ),
        ),
      ),
    );
  }
}
