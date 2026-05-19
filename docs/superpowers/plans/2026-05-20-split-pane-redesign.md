# Split-Pane Redesign & Ink Fix — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace 3-layer navigation with a single split-pane HomeScreen (left tree + right grid) + fullscreen EditorScreen, fix InkEngine handwriting rendering, and add Gaussian blur + animation effects to toolbar buttons.

**Architecture:** InkEngine becomes a ChangeNotifier so PageCanvas can rebuild reactively via ListenableBuilder. HomeScreen uses a Row with a 320px NotebookTreePanel sidebar and an expanded PageGridPanel. EditorScreen gets a blur-glass toolbar with animated buttons. Theme follows system brightness via Material 3.

**Tech Stack:** Flutter, Riverpod, Drift (SQLite), ChangeNotifier, BackdropFilter, implicit animations

---

### Task 1: Make InkEngine a ChangeNotifier with pressure-aware stroke width

**Files:**
- Modify: `lib/core/ink/ink_engine.dart` (full rewrite)
- Modify: `lib/core/ink/stroke_painter.dart:36-43` (pressure-aware width)

The InkEngine must notify listeners on every mutation so the UI knows to repaint. Also add pressure-based line width variation.

- [ ] **Step 1: Rewrite InkEngine as ChangeNotifier**

`lib/core/ink/ink_engine.dart`:

```dart
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'stroke_model.dart';

class InkEngine extends ChangeNotifier {
  static const _uuid = Uuid();

  final List<Stroke> _strokes = [];
  Stroke? _activeStroke;
  List<StrokePoint> _lastSamples = [];

  Color color = Colors.black;
  double width = 2.0;
  PenType type = PenType.pen;
  BlendMode blend = BlendMode.srcOver;

  List<Stroke> get strokes => List.unmodifiable(_strokes);
  Stroke? get activeStroke => _activeStroke;

  void setColor(Color c) {
    color = c;
    notifyListeners();
  }

  void setWidth(double w) {
    width = w;
    notifyListeners();
  }

  void setType(PenType t) {
    type = t;
    blend = t == PenType.highlighter ? BlendMode.multiply : BlendMode.srcOver;
    notifyListeners();
  }

  void onPointerDown(PointerDownEvent event) {
    _activeStroke = Stroke(
      id: _uuid.v4(),
      points: [StrokePoint(x: event.localPosition.dx, y: event.localPosition.dy)],
      color: color,
      width: width,
      type: type,
      blend: blend,
    );
    _lastSamples = [_activeStroke!.points.first];
    notifyListeners();
  }

  void onPointerMove(PointerMoveEvent event) {
    if (_activeStroke == null) return;
    final newPoint = StrokePoint(
      x: event.localPosition.dx,
      y: event.localPosition.dy,
      pressure: event.pressure.clamp(0.0, 1.0),
      timestamp: event.timeStamp.inMicroseconds,
    );
    _lastSamples.add(newPoint);
    _activeStroke = _activeStroke!.copyWith(points: _smoothPoints(_lastSamples));
    notifyListeners();
  }

  List<StrokePoint> _smoothPoints(List<StrokePoint> raw) {
    if (raw.length < 3) return raw;
    final smoothed = <StrokePoint>[raw.first];
    for (int i = 1; i < raw.length - 1; i++) {
      final a = raw[i - 1];
      final b = raw[i];
      final c = raw[i + 1];
      smoothed.add(StrokePoint(
        x: (a.x + b.x + c.x) / 3,
        y: (a.y + b.y + c.y) / 3,
        pressure: b.pressure,
        timestamp: b.timestamp,
      ));
    }
    smoothed.add(raw.last);
    return smoothed;
  }

  void onPointerUp(PointerUpEvent event) {
    if (_activeStroke == null) return;
    final finalStroke = _activeStroke!.copyWith(points: _smoothPoints(_lastSamples));
    _strokes.add(finalStroke);
    _activeStroke = null;
    _lastSamples = [];
    notifyListeners();
  }

  void eraseAt(Offset position, double radius) {
    _strokes.removeWhere((stroke) {
      return stroke.points.any((p) => (p.offset - position).distance <= radius);
    });
    notifyListeners();
  }

  Set<String> selectInRect(ui.Rect rect) {
    final ids = <String>{};
    for (final stroke in _strokes) {
      if (stroke.points.any((p) => rect.contains(p.offset))) {
        ids.add(stroke.id);
      }
    }
    return ids;
  }

  void moveStrokes(Set<String> ids, Offset delta) {
    for (int i = 0; i < _strokes.length; i++) {
      if (ids.contains(_strokes[i].id)) {
        _strokes[i] = _strokes[i].copyWith(
          points: _strokes[i].points
              .map((p) => StrokePoint(
                    x: p.x + delta.dx,
                    y: p.y + delta.dy,
                    pressure: p.pressure,
                    timestamp: p.timestamp,
                  ))
              .toList(),
        );
      }
    }
    notifyListeners();
  }

  void clear() {
    _strokes.clear();
    notifyListeners();
  }

  void undo() {
    if (_strokes.isNotEmpty) {
      _strokes.removeLast();
      notifyListeners();
    }
  }
}
```

- [ ] **Step 2: Update StrokePainter for pressure-based width**

In `lib/core/ink/stroke_painter.dart`, update `_paintStroke` to vary width by pressure. Replace the `_paintStroke` method:

```dart
void _paintStroke(Canvas canvas, Stroke stroke) {
  if (stroke.points.isEmpty) return;
  if (stroke.points.length == 1) {
    final p = stroke.points.first;
    final effectiveWidth = stroke.width * (0.3 + 0.7 * p.pressure);
    canvas.drawCircle(
      Offset(p.x, p.y),
      effectiveWidth / 2,
      Paint()
        ..color = stroke.color
        ..blendMode = stroke.blend
        ..isAntiAlias = true,
    );
    return;
  }

  final paints = <double, Paint>{};
  Paint _paintForWidth(double w) {
    return paints.putIfAbsent(w, () => Paint()
      ..color = stroke.color
      ..strokeWidth = w
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true
      ..blendMode = stroke.blend);
  }

  for (int i = 0; i < stroke.points.length - 1; i++) {
    final p0 = stroke.points[i];
    final p1 = stroke.points[i + 1];
    final effectiveWidth = stroke.width * (0.3 + 0.7 * ((p0.pressure + p1.pressure) / 2));
    canvas.drawLine(p0.offset, p1.offset, _paintForWidth(effectiveWidth));
  }
}
```

- [ ] **Step 3: Commit**

```bash
git add lib/core/ink/ink_engine.dart lib/core/ink/stroke_painter.dart
git commit -m "fix: make InkEngine a ChangeNotifier with pressure-aware stroke width"
```

---

### Task 2: Create NotebookTreePanel (left sidebar)

**Files:**
- Create: `lib/features/home/widgets/notebook_tree_panel.dart`

- [ ] **Step 1: Write NotebookTreePanel**

`lib/features/home/widgets/notebook_tree_panel.dart`:

```dart
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
        filter: const ui.ImageFilter.blur(sigmaX: 6, sigmaY: 6),
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
          // handled by parent via Navigator.push to EditorScreen
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
      coverColor: Value(Colors.primaries[id.hashCode % Colors.primaries.length].value),
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
```

- [ ] **Step 2: Commit**

```bash
git add lib/features/home/widgets/notebook_tree_panel.dart
git commit -m "feat: add NotebookTreePanel with blur-glass sidebar and expandable tree"
```

---

### Task 3: Create PageGridPanel (right thumbnail area)

**Files:**
- Create: `lib/features/home/widgets/page_grid_panel.dart`

- [ ] **Step 1: Write PageGridPanel**

`lib/features/home/widgets/page_grid_panel.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' hide Column;
import '../../../shared/providers.dart';
import '../../../core/storage/database.dart';
import '../../../core/storage/file_storage.dart';
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
    return StreamBuilder<Notebook>(
      stream: db.watchAllNotebooks().map((list) => list.firstWhere((n) => n.id == widget.notebookId)),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final notebook = snapshot.data!;
        final accentColor = Color(notebook.coverColor);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildTitleBar(notebook.title, accentColor, isDark),
            const Divider(height: 1),
            Expanded(child: _buildPageGrid(db, accentColor, isDark)),
          ],
        );
      },
    );
  }

  Widget _buildTitleBar(String title, Color accentColor, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 16, 12),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              color: accentColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.grey.shade100 : const Color(0xFF202124),
            ),
          ),
          const Spacer(),
          _GlassButton(
            icon: Icons.add,
            label: '新建页面',
            isDark: isDark,
            onTap: () => _createPage(db),
          ),
        ],
      ),
    );
  }

  Widget _buildPageGrid(AppDatabase db, Color accentColor, bool isDark) {
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
            child: _buildPageCard(pages[index], accentColor, isDark),
          ),
        );
      },
    );
  }

  Widget _buildPageCard(NotePage page, Color accentColor, bool isDark) {
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

  Future<void> _createPage(AppDatabase db) async {
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
}

class _GlassButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isDark;
  final VoidCallback onTap;

  const _GlassButton({
    required this.icon,
    required this.label,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.primary,
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
```

- [ ] **Step 2: Commit**

```bash
git add lib/features/home/widgets/page_grid_panel.dart
git commit -m "feat: add PageGridPanel with staggered entrance animations"
```

---

### Task 4: Create HomeScreen (split-pane root)

**Files:**
- Create: `lib/features/home/home_screen.dart`

- [ ] **Step 1: Write HomeScreen**

`lib/features/home/home_screen.dart`:

```dart
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
        coverColor: Value(Colors.primaries[0].value),
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
```

- [ ] **Step 2: Commit**

```bash
git add lib/features/home/home_screen.dart
git commit -m "feat: add HomeScreen with split-pane layout (tree + grid)"
```

---

### Task 5: Update EditorScreen, PageCanvas, and Toolbar

**Files:**
- Modify: `lib/features/editor/editor_screen.dart`
- Modify: `lib/features/editor/widgets/page_canvas.dart`
- Rewrite: `lib/features/editor/widgets/toolbar.dart`

- [ ] **Step 1: Update EditorScreen with ListenableBuilder**

`lib/features/editor/editor_screen.dart`:

```dart
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
    final inkEngine = ref.read(inkEngineNotifierProvider);
    _pageContext = PageContext(
      inkEngine: inkEngine,
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
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('编辑'),
      ),
      body: Column(
        children: [
          Toolbar(pluginManager: pm, pageContext: _pageContext, inkEngine: inkEngine),
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
              child: ListenableBuilder(
                listenable: inkEngine,
                builder: (context, _) => PageCanvas(
                  strokes: inkEngine.strokes,
                  activeStroke: inkEngine.activeStroke,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Update PageCanvas — no structural change needed**

`PageCanvas` stays as-is. The `ListenableBuilder` in EditorScreen handles reactivity. No file changes needed for `page_canvas.dart`.

- [ ] **Step 3: Rewrite Toolbar with blur glass and animations**

`lib/features/editor/widgets/toolbar.dart`:

```dart
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../../core/plugin/plugin_interface.dart';
import '../../../core/plugin/plugin_manager.dart';
import '../../../core/ink/ink_engine.dart';

class Toolbar extends StatelessWidget {
  final PluginManager pluginManager;
  final PageContext pageContext;
  final InkEngine inkEngine;

  const Toolbar({
    super.key,
    required this.pluginManager,
    required this.pageContext,
    required this.inkEngine,
  });

  @override
  Widget build(BuildContext context) {
    final plugins = pluginManager.enabledPlugins;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ClipRect(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: (isDark ? Colors.grey.shade900 : Colors.white).withValues(alpha: 0.75),
            border: Border(
              bottom: BorderSide(
                color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
              ),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: plugins.map((plugin) {
              final isActive = pluginManager.activePlugin?.id == plugin.id;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: _ToolButton(
                  plugin: plugin,
                  isActive: isActive,
                  isDark: isDark,
                  onTap: () {
                    if (isActive) {
                      pluginManager.deactivate();
                    } else {
                      pluginManager.activate(plugin.id, pageContext);
                    }
                  },
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

class _ToolButton extends StatefulWidget {
  final NotePlugin plugin;
  final bool isActive;
  final bool isDark;
  final VoidCallback onTap;

  const _ToolButton({
    required this.plugin,
    required this.isActive,
    required this.isDark,
    required this.onTap,
  });

  @override
  State<_ToolButton> createState() => _ToolButtonState();
}

class _ToolButtonState extends State<_ToolButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pressController;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _pressController.forward(),
      onTapUp: (_) {
        _pressController.reverse();
        widget.onTap();
      },
      onTapCancel: () => _pressController.reverse(),
      child: AnimatedBuilder(
        animation: _scaleAnim,
        builder: (context, child) => Transform.scale(
          scale: _scaleAnim.value,
          child: child,
        ),
        child: Tooltip(
          message: widget.plugin.name,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: widget.isActive
                  ? (widget.isDark
                      ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.25)
                      : Theme.of(context).colorScheme.primary.withValues(alpha: 0.12))
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              widget.plugin.icon,
              size: 22,
              color: widget.isActive
                  ? Theme.of(context).colorScheme.primary
                  : (widget.isDark ? Colors.grey.shade400 : const Color(0xFF5F6368)),
            ),
          ),
        ),
      ),
    );
  }
}

class AnimatedBuilder extends AnimatedWidget {
  final Widget? child;
  final Widget Function(BuildContext context, Widget? child) builder;

  const AnimatedBuilder({
    super.key,
    required super.listenable,
    required this.builder,
    this.child,
  });

  @override
  Widget build(BuildContext context) => builder(context, child);
}
```

- [ ] **Step 4: Commit**

```bash
git add lib/features/editor/editor_screen.dart lib/features/editor/widgets/toolbar.dart
git commit -m "feat: fix ink reactivity with ListenableBuilder, add blur-glass animated toolbar"
```

---

### Task 6: Update app.dart — HomeScreen entry + system theme

**Files:**
- Modify: `lib/app.dart`

- [ ] **Step 1: Update app.dart**

`lib/app.dart`:

```dart
import 'package:flutter/material.dart';
import 'features/home/home_screen.dart';

class NoteApp extends StatelessWidget {
  const NoteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ZNote',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1A73E8),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF8F9FA),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF202124),
          elevation: 0.5,
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: Color(0xFF202124),
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 1,
          shadowColor: Colors.black.withValues(alpha: 0.08),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          color: Colors.white,
          clipBehavior: Clip.antiAlias,
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Color(0xFF1A73E8),
          foregroundColor: Colors.white,
          elevation: 4,
          shape: CircleBorder(),
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1A73E8),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF121212),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E1E1E),
          foregroundColor: Colors.white,
          elevation: 0.5,
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 2,
          shadowColor: Colors.black.withValues(alpha: 0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          color: const Color(0xFF2D2D2D),
          clipBehavior: Clip.antiAlias,
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Color(0xFF1A73E8),
          foregroundColor: Colors.white,
          elevation: 4,
          shape: CircleBorder(),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/app.dart
git commit -m "feat: switch to HomeScreen, add dark theme, follow system brightness"
```

---

### Task 7: Final integration — build and verify

**Files:** (none modified, verification only)

- [ ] **Step 1: Run build_runner to regenerate providers**

```bash
cd D:/note/note_app && dart run build_runner build --delete-conflicting-outputs
```
Expected: BUILD SUCCESS

- [ ] **Step 2: Run Flutter analyze**

```bash
cd D:/note/note_app && flutter analyze
```
Expected: No issues found (or only pre-existing issues)

- [ ] **Step 3: Commit any generated changes**

```bash
git add -A && git status
# If generated files changed:
git commit -m "chore: regenerate providers after architecture changes"
```

---

### Implementation Order

```
Task 1 (InkEngine) → Task 2 (TreePanel) → Task 3 (GridPanel)
                                              ↓
Task 6 (app.dart) ← Task 4 (HomeScreen) ← -----+
    ↓
Task 5 (EditorScreen + Toolbar)
    ↓
Task 7 (Verify)
```

Tasks 2 and 3 can run in parallel. Task 4 depends on 2 and 3. Task 5 depends on 1. Task 6 depends on 4. Task 7 runs last.
