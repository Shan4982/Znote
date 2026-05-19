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
