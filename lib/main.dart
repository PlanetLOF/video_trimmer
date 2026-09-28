import 'package:material_ui/material_ui.dart';
import 'package:media_kit/media_kit.dart';

import 'common/app_settings.dart';
import 'screen/app.dart';
import 'util/platform_util.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  final missing = await _checkBinaries();
  // Loaded before the first frame so the app never flashes the default theme.
  final settingsStore = SharedPreferencesAppSettingsStore();
  final settings = await settingsStore.load();
  runApp(
    VideoTrimmerApp(
      binariesMissing: missing,
      initialSettings: settings,
      settingsStore: settingsStore,
    ),
  );
}

Future<List<String>> _checkBinaries() async {
  final missing = <String>[];
  for (final name in ['ffmpeg', 'ffprobe']) {
    if (!await PlatformUtil.binaryRuns(name)) {
      missing.add(name);
    }
  }
  return missing;
}
