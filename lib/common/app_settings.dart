import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'theme.dart';

/// User-selectable appearance settings, persisted between launches.
class AppSettings {
  const AppSettings({
    this.accent = AppAccent.pink,
    this.themeMode = ThemeMode.system,
  });

  final AppAccent accent;
  final ThemeMode themeMode;

  AppSettings copyWith({AppAccent? accent, ThemeMode? themeMode}) {
    return AppSettings(
      accent: accent ?? this.accent,
      themeMode: themeMode ?? this.themeMode,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AppSettings &&
        other.accent == accent &&
        other.themeMode == themeMode;
  }

  @override
  int get hashCode => Object.hash(accent, themeMode);

  @override
  String toString() => 'AppSettings($accent, $themeMode)';
}

/// Reads and writes [AppSettings].
abstract interface class AppSettingsStore {
  Future<AppSettings> load();

  Future<void> save(AppSettings settings);
}

/// Stores [AppSettings] in `shared_preferences`.
///
/// Values are keyed by enum name. Unknown names fall back to the defaults
/// rather than throwing, so a stale or hand-edited store can never stop the
/// app from starting.
class SharedPreferencesAppSettingsStore implements AppSettingsStore {
  static const _accentKey = 'appearance.accent';
  static const _themeModeKey = 'appearance.themeMode';

  /// Created on first use: the underlying constructor throws when no platform
  /// implementation is registered, which must not happen merely by building
  /// this object.
  SharedPreferencesAsync? _preferences;

  SharedPreferencesAsync get _prefs =>
      _preferences ??= SharedPreferencesAsync();

  @override
  Future<AppSettings> load() async {
    try {
      final accent = await _prefs.getString(_accentKey);
      final themeMode = await _prefs.getString(_themeModeKey);
      return AppSettings(
        accent: _parse(accent, AppAccent.values, AppAccent.pink),
        themeMode: _parse(themeMode, ThemeMode.values, ThemeMode.system),
      );
    } catch (_) {
      return const AppSettings();
    }
  }

  @override
  Future<void> save(AppSettings settings) async {
    await Future.wait([
      _prefs.setString(_accentKey, settings.accent.name),
      _prefs.setString(_themeModeKey, settings.themeMode.name),
    ]);
  }

  static T _parse<T extends Enum>(String? name, List<T> values, T fallback) {
    for (final value in values) {
      if (value.name == name) {
        return value;
      }
    }
    return fallback;
  }
}

/// An [AppSettingsStore] that keeps values in memory only.
class InMemoryAppSettingsStore implements AppSettingsStore {
  InMemoryAppSettingsStore([this._settings = const AppSettings()]);

  AppSettings _settings;

  @override
  Future<AppSettings> load() async => _settings;

  @override
  Future<void> save(AppSettings settings) async {
    _settings = settings;
  }
}
