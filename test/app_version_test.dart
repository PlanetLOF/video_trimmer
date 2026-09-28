import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:video_trimmer/generated/app_version.g.dart';
import 'package:video_trimmer/screen/about_dialog.dart';

import '../tool/pubspec_version.dart';

void main() {
  group('readPubspecVersion', () {
    test('splits the build number off the build name', () {
      final version = readPubspecVersion('name: x\nversion: 1.0.2+1\n');
      expect(version.buildName, '1.0.2');
      expect(version.buildNumber, '1');
    });

    test('tolerates quotes and a trailing comment', () {
      final version = readPubspecVersion("version: '2.0.0+7'  # shipped\n");
      expect(version.buildName, '2.0.0');
      expect(version.buildNumber, '7');
    });

    test('leaves a build number of null when there is no + suffix', () {
      expect(readPubspecVersion('version: 3.1.0\n').buildNumber, isNull);
    });

    test('ignores an indented version key from a nested block', () {
      expect(
        () => readPubspecVersion('name: x\ndependencies:\n  version: 9.9.9\n'),
        throwsFormatException,
      );
    });

    test('throws when the key is missing or empty', () {
      expect(() => readPubspecVersion('name: x\n'), throwsFormatException);
      expect(() => readPubspecVersion('version:\n'), throwsFormatException);
    });
  });

  test('generated constants match the version in pubspec.yaml', () {
    final pubspec = readPackageVersion();

    expect(appVersion, pubspec.buildName);
    expect(appBuildNumber, pubspec.buildNumber);
  });

  testWidgets('about dialog shows the current version', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showVideoTrimmerAboutDialog(context),
            child: const Text('Open about'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open about'));
    await tester.pumpAndSettle();

    expect(find.text('version $appVersion'), findsOneWidget);
  });
}
