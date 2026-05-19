# Split-Pane Redesign & Ink Fix

## Summary

将现有 3 层导航（笔记本列表 → 页面列表 → 编辑器）重构为单一主屏幕（左侧树状侧栏 + 右侧缩略图网格）+ 全屏编辑器的布局。同时修复手写笔迹不渲染的问题，并为工具栏按钮添加高斯模糊和交互动效。

## Architecture

### New Screen Structure

```
lib/
├── app.dart                              # home 改为 HomeScreen, 跟随系统 Brightness
├── features/
│   ├── home/
│   │   ├── home_screen.dart              # 新增: 主分栏屏幕
│   │   └── widgets/
│   │       ├── notebook_tree_panel.dart   # 新增: 左侧 320px 树状侧栏
│   │       └── page_grid_panel.dart       # 新增: 右侧缩略图网格
│   ├── editor/
│   │   ├── editor_screen.dart            # 修改: ListenableBuilder 修复渲染
│   │   └── widgets/
│   │       ├── page_canvas.dart          # 修改: ListenableBuilder 监听
│   │       └── toolbar.dart              # 修改: 高斯模糊 + 动效
│   └── notebook/                         # 保留, 不再作为入口
├── core/
│   └── ink/
│       └── ink_engine.dart               # 修改: ChangeNotifier, 压感线宽
```

### Data Flow

- `HomeScreen` → `ref.watch(databaseProvider)` 获取 DB → stream 笔记本和页面
- 左侧树和右侧网格共享 `selectedNotebookId` state
- 点击页面 → `Navigator.push(EditorScreen)`
- `InkEngine` 作为 `ChangeNotifier`，笔画变化通知 `PageCanvas` 重绘

## UI Layout

### HomeScreen Split Pane

```
┌──────────────────────────────────────────────┐
│  AppBar: ZNote                  [搜索] [更多] │
├──────────────┬───────────────────────────────┤
│  左侧 320px   │       右侧 (剩余空间)          │
│              │                               │
│  树状笔记本   │  选中笔记本 → 页面缩略图网格    │
│  可展开/折叠  │  点击缩略图 → 进入编辑器        │
│              │                               │
│ [+新建笔记本] │        [+新建页面 FAB]          │
└──────────────┴───────────────────────────────┘
```

### 动效规格

- 树节点展开/折叠: `AnimatedSize` 200ms ease-out
- 选中高亮滑动: `AnimatedPositioned` 200ms
- 网格入场: stagger, 每个卡片延迟 40ms
- 页面卡片 hover: scale 1.02 + 轻微阴影 150ms

## Ink Engine Fix

### Root Cause

`InkEngine` 直接变异内部 `_strokes`/`_activeStroke` 字段，Riverpod `InkEngineNotifier` 的 state 引用不变，`ref.watch` 不触发重绘。

### Solution

1. `InkEngine extends ChangeNotifier` — 每个变异方法末尾调用 `notifyListeners()`
2. `PageCanvas` 用 `ListenableBuilder(listenable: inkEngine)` 监听
3. 压感线宽: `effectiveWidth = stroke.width * (0.3 + 0.7 * point.pressure)`

## Toolbar 高斯模糊 + 动效

- 背景: `BackdropFilter(blur(sigmaX: 10, sigmaY: 10))` + 半透明底色
- 按钮按下: `AnimatedScale` 0.92 → 1.0 spring 回弹 150ms
- 激活态: 蓝色发光 + scale 1.05
- 工具切换指示器: `AnimatedSlide`

## Theme

- 跟随系统 `Brightness` (light/dark)
- Material 3 色彩系统
- 蓝色系强调色 (`#1A73E8`)
