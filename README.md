# ZNote

平板手写笔记应用，基于 Flutter 构建。

## 技术栈

| 层 | 技术 |
|---|---|
| 框架 | Flutter 3.27+, Dart 3.6+ |
| 状态管理 | Riverpod |
| 数据库 | Drift (SQLite) |
| 路由 | Navigator 2.0 |

## 快速开始

```bash
flutter pub get
dart run build_runner build
flutter run
```

推荐使用 Windows 桌面端或平板模拟器（应用为触控笔输入设计）。

## 项目结构

```
lib/
├── main.dart              # 入口
├── app.dart               # MaterialApp 配置 / 主题
├── core/
│   ├── ink/               # 手写笔迹引擎
│   ├── storage/           # Drift 数据库 + 文件存储
│   └── plugin/            # 插件系统（笔/橡皮擦/套索）
├── features/
│   ├── home/              # 主页（双面板：笔记本树 + 页面网格）
│   ├── editor/            # 编辑器（A4 画布 + 工具栏）
│   └── notebook/          # 笔记本列表 + 详情
└── shared/                # Riverpod providers
```

## 文档

详见 [docs/](docs/)：

- [架构概览](docs/architecture/overview.md)
- [数据流](docs/architecture/data-flow.md)
- [手写编辑器](docs/features/handwriting-editor.md)
- [笔迹引擎](docs/core/ink-engine.md)
- [存储层](docs/core/storage.md)
- [插件系统](docs/core/plugin-system.md)
- [开发环境](docs/development/setup.md)

## 已知限制

- 搜索功能未实现
- DOCX→PDF 转换未实现
- 撤销仅支持单步
- 页面删除不清理关联笔画文件
