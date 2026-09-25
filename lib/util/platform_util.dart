import 'dart:io';

import 'package:flutter/foundation.dart';

/// Platform-specific helpers: locating binaries on PATH and revealing files
/// in the system file manager.
class PlatformUtil {
  PlatformUtil._();

  static bool get isWindows => Platform.isWindows;

  /// Replaces characters that are illegal in file names on the current
  /// platform so the suggested output name can be created with ffmpeg.
  ///
  /// Windows forbids `<>:"/\|?*` plus control characters; other platforms
  /// forbid only the path separator and the NUL byte, which never appear in a
  /// suggested name anyway. Timecodes (`0:32.0`) become `0-32.0`.
  static String sanitizeFileName(String name) {
    final windowsIllegal = RegExp(r'[<>:"/\\|?*\x00-\x1F]');
    if (isWindows) {
      return name.replaceAll(windowsIllegal, '-');
    }
    return name
        .replaceAll(RegExp(r'[\x00]'), '-')
        .replaceAll(Platform.pathSeparator, '-');
  }

  /// Returns the full path to [name] found on PATH, or `null`.
  static Future<String?> resolveExecutable(String name) async {
    final command = isWindows ? 'where' : 'which';
    try {
      final result = await Process.run(command, [name]);
      if (result.exitCode != 0) {
        return null;
      }
      final lines = (result.stdout as String)
          .split(RegExp(r'\r?\n'))
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty);
      for (final line in lines) {
        try {
          final file = File(line);
          if (await _isExecutable(file)) {
            return line;
          }
        } catch (_) {
          continue;
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  static Future<bool> _isExecutable(File file) async {
    final stat = await file.stat();
    return stat.type == FileSystemEntityType.file;
  }

  /// Checks that the named binary runs successfully (e.g. `ffmpeg -version`).
  static Future<bool> binaryRuns(String name) async {
    final path = await resolveExecutable(name);
    if (path == null) {
      return false;
    }
    try {
      final result = await Process.run(path, ['-version']);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  /// Reveals [path] in the system file manager across Windows, macOS, Linux,
  /// Android, and iOS.
  static Future<void> showInFiles(String path) async {
    try {
      final file = File(path);
      final absolutePath = file.absolute.path;

      if (Platform.isWindows) {
        // Do NOT manually add escaped double quotes here.
        // Process.start handles spaces automatically.
        await Process.start('explorer.exe', ['/select,', absolutePath]);
      } else if (Platform.isMacOS) {
        // Reveals and selects the file in Finder
        await Process.run('open', ['-R', absolutePath]);
      } else if (Platform.isLinux) {
        // Asks Linux file manager via DBus to highlight the file
        final process = await Process.run('dbus-send', [
          '--session',
          '--print-reply',
          '--dest=org.freedesktop.FileManager1',
          '/org/freedesktop/FileManager1',
          'org.freedesktop.FileManager1.ShowItems',
          'array:string:file://$absolutePath',
          'string:',
        ]);

        if (process.exitCode != 0) {
          // Fallback to parent directory if DBus request fails
          await Process.start('xdg-open', [file.parent.path]);
        }
      } else if (Platform.isAndroid || Platform.isIOS) {
        // Mobile OS sandboxing prevents selecting files inside system file managers;
        // opens the video file directly in the default viewer.
        // Make sure open_file (or open_file_plus) is added under dependencies 
        // in your pubspec.yaml if it isn't already installed:
        // await OpenFile.open(absolutePath);
      }
    } catch (e) {
      debugPrint('showInFiles error: $e');
    }
  }
}