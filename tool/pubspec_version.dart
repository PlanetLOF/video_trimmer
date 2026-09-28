/// Reads the app version out of a `pubspec.yaml` without taking a dependency
/// on a YAML parser.
///
/// The `version` key is a top-level scalar, and top-level keys are never
/// indented, so a match anchored to the start of a line can only ever be the
/// real key: indented `version:` lines belong to some nested block, and
/// `#version:` comments cannot match.
library;

import 'dart:io';

import 'package:path/path.dart' as p;

const String _packageName = 'video_trimmer';

final RegExp _versionLine = RegExp(r'^version:[ \t]*(.*)$', multiLine: true);

/// The `version:` value of a `pubspec.yaml`, split around its `+` suffix.
class PubspecVersion {
  const PubspecVersion(this.buildName, this.buildNumber);

  /// The part before the `+`, e.g. `1.0.2` for `1.0.2+1`.
  final String buildName;

  /// The part after the `+`, e.g. `1` for `1.0.2+1`, or `null` when the
  /// value carries no `+` suffix.
  final String? buildNumber;
}

/// Parses the top-level `version:` of [yamlText].
///
/// Tolerates a trailing comment and surrounding quotes, so `version: 1.0.2+1`,
/// `version: "1.0.2+1" # bumped` and `version: '1.0.2'` all parse.
///
/// Throws a [FormatException] when the key is missing or its value is empty.
PubspecVersion readPubspecVersion(String yamlText) {
  final match = _versionLine.firstMatch(yamlText);
  if (match == null) {
    throw const FormatException('pubspec.yaml has no top-level version: key');
  }
  final value = _value(match[1]!);
  if (value.isEmpty) {
    throw const FormatException('pubspec.yaml has an empty version: value');
  }
  final plus = value.indexOf('+');
  if (plus == -1) {
    return PubspecVersion(value, null);
  }
  return PubspecVersion(value.substring(0, plus), value.substring(plus + 1));
}

/// Returns the directory holding this package's `pubspec.yaml`, found by
/// walking up from [start] (the current directory by default).
///
/// The name check keeps the walk from stopping on a parent directory that has
/// a `pubspec.yaml` of its own, such as a pub workspace root.
Directory findPackageRoot([Directory? start]) {
  var dir = (start ?? Directory.current).absolute;
  while (true) {
    final pubspec = File(p.join(dir.path, 'pubspec.yaml'));
    if (pubspec.existsSync() &&
        RegExp(
          '^name:[ \\t]*$_packageName[ \\t]*\$',
          multiLine: true,
        ).hasMatch(pubspec.readAsStringSync())) {
      return dir;
    }
    final parent = dir.parent;
    if (parent.path == dir.path) {
      throw StateError(
        'No pubspec.yaml declaring $_packageName found at or above '
        '${dir.path}',
      );
    }
    dir = parent;
  }
}

/// Reads this package's version straight from its `pubspec.yaml`.
PubspecVersion readPackageVersion([Directory? start]) {
  final root = findPackageRoot(start);
  return readPubspecVersion(
    File(p.join(root.path, 'pubspec.yaml')).readAsStringSync(),
  );
}

/// Reduces the text after `version:` to the bare value.
///
/// A quoted value ends at its closing quote, so a `#` inside the quotes stays
/// part of the value and anything after them is a comment. An unquoted value
/// is cut at the first `#`, since YAML only starts a comment there.
String _value(String raw) {
  final trimmed = raw.trim();
  final quote = trimmed.isEmpty ? '' : trimmed[0];
  if (quote == '"' || quote == "'") {
    final end = trimmed.indexOf(quote, 1);
    if (end != -1) {
      return trimmed.substring(1, end);
    }
  }
  final hash = trimmed.indexOf('#');
  return hash == -1 ? trimmed : trimmed.substring(0, hash).trim();
}
