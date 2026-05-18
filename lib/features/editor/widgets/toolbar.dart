import 'package:flutter/material.dart';
import '../../../core/plugin/plugin_interface.dart';
import '../../../core/plugin/plugin_manager.dart';

class Toolbar extends StatelessWidget {
  final PluginManager pluginManager;
  final PageContext pageContext;
  final Axis direction; // horizontal by default

  const Toolbar({
    super.key,
    required this.pluginManager,
    required this.pageContext,
    this.direction = Axis.horizontal,
  });

  @override
  Widget build(BuildContext context) {
    final plugins = pluginManager.enabledPlugins;

    return Container(
      height: direction == Axis.horizontal ? 56 : null,
      width: direction == Axis.vertical ? 56 : null,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: ListView.separated(
        scrollDirection: direction,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        itemCount: plugins.length,
        separatorBuilder: (_, __) => const SizedBox(width: 4),
        itemBuilder: (context, index) {
          final plugin = plugins[index];
          final isActive = pluginManager.activePlugin?.id == plugin.id;

          return Tooltip(
            message: plugin.name,
            child: IconButton(
              icon: Icon(plugin.icon),
              isSelected: isActive,
              color: isActive
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurface,
              onPressed: () {
                if (isActive) {
                  pluginManager.deactivate();
                } else {
                  pluginManager.activate(plugin.id, pageContext);
                }
              },
            ),
          );
        },
      ),
    );
  }
}
