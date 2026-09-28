// Regenerates lib/generated/app_version.g.dart from the `version:` key in
// pubspec.yaml, so the About dialog shows the version the app is built from
// instead of a hand-maintained copy of it.
//
//   dart run tool/generate_version.dart

import 'dart:io';

import 'package:path/path.dart' as p;

import 'pubspec_version.dart';

const String _outputPath = 'lib/generated/app_version.g.dart';

const String _regenerateHint = 'dart run tool/generate_version.dart';

void main() {
  final version = readPackageVersion();
  final buildNumber = version.buildNumber;
  if (buildNumber == null) {
    throw StateError(
      'pubspec.yaml version "${version.buildName}" has no build suffix. '
      'Write it as <major>.<minor>.<patch>+<build>, e.g. '
      '${version.buildName}+1.',
    );
  }

  final root = findPackageRoot();
  final target = File(p.join(root.path, p.joinAll(_outputPath.split('/'))));
  final contents = _render(version.buildName, buildNumber);

  final current = target.existsSync() ? target.readAsStringSync() : null;
  if (current == contents) {
    stdout.writeln('$_outputPath is up to date (${version.buildName})');
    return;
  }

  target.parent.createSync(recursive: true);
  target.writeAsStringSync(contents);
  stdout.writeln('wrote $_outputPath (${version.buildName})');
}

String _render(String buildName, String buildNumber) {
  final buffer = StringBuffer()
    ..writeln('// GENERATED CODE - DO NOT MODIFY BY HAND.')
    ..writeln('//')
    ..writeln('// Source: the `version:` key in pubspec.yaml.')
    ..writeln('// Regenerate: $_regenerateHint')
    ..writeln()
    ..writeln('/// Build name from the `version:` key in pubspec.yaml, before')
    ..writeln('/// the `+`.')
    ..writeln("const String appVersion = '$buildName';")
    ..writeln()
    ..writeln('/// Build number from the `+N` suffix of the `version:` key in')
    ..writeln('/// pubspec.yaml.')
    ..writeln("const String appBuildNumber = '$buildNumber';");
  return buffer.toString();
}
