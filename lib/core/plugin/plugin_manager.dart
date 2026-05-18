import '../../core/storage/database.dart';
import 'plugin_interface.dart';

class PluginManager {
  final AppDatabase _db;
  final Map<String, NotePlugin> _registry = {};

  NotePlugin? _activePlugin;

  PluginManager(this._db);

  NotePlugin? get activePlugin => _activePlugin;

  /// Register a plugin. Called once on startup for each built-in plugin.
  void register(NotePlugin plugin) {
    _registry[plugin.id] = plugin;
  }

  /// Load enabled states from storage, then apply to registered plugins.
  Future<void> loadStates() async {
    final states = await _db.allPluginStates();
    for (final state in states) {
      final plugin = _registry[state.pluginId];
      if (plugin != null && !plugin.required) {
        plugin.enabled = state.enabled;
      }
    }
  }

  /// Persist a plugin's enabled state and update the in-memory plugin.
  Future<void> setEnabled(String pluginId, bool enabled) async {
    final plugin = _registry[pluginId];
    if (plugin == null || plugin.required) return;
    plugin.enabled = enabled;
    await _db.setPluginEnabled(pluginId, enabled);
  }

  /// Activate a plugin — deactivates the previous one first.
  void activate(String pluginId, PageContext context) {
    _activePlugin?.onDeactivate();
    _activePlugin = _registry[pluginId];
    _activePlugin?.onActivate(context);
  }

  void deactivate() {
    _activePlugin?.onDeactivate();
    _activePlugin = null;
  }

  /// Currently enabled plugins, sorted by order preference.
  List<NotePlugin> get enabledPlugins {
    final plugins = _registry.values.where((p) => p.enabled).toList();
    return plugins;
  }

  /// All registered plugins (for the plugin management settings page).
  List<NotePlugin> get allPlugins => _registry.values.toList();
}
