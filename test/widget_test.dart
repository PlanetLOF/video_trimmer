import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:video_trimmer/screen/app.dart';
import 'package:video_trimmer/screen/start_end_row.dart';
import 'package:video_trimmer/common/typography.dart';
import 'package:video_trimmer/common/video_session.dart';

Widget _wrap(Widget child) {
  return MaterialApp(home: Scaffold(body: child));
}

void main() {
  testWidgets('app shows the open prompt when nothing is open', (tester) async {
    final session = VideoSession(initOnConstruct: false);
    addTearDown(session.dispose);

    await tester.pumpWidget(VideoTrimmerApp(session: session));
    await tester.pumpAndSettle();

    expect(find.text('Video Trimmer'), findsOneWidget);
    expect(find.text('Open'), findsWidgets);
    expect(find.byIcon(Icons.movie_outlined), findsOneWidget);
    expect(find.text('Trim'), findsNothing);
  });

  testWidgets('theme toggle switches between light and dark', (tester) async {
    final session = VideoSession(initOnConstruct: false);
    addTearDown(session.dispose);

    await tester.pumpWidget(VideoTrimmerApp(session: session));
    await tester.pumpAndSettle();

    final toggle = find.byTooltip('Toggle theme');
    expect(toggle, findsOneWidget);

    Icon iconOf() => tester.widget<Icon>(
      find.descendant(of: toggle, matching: find.byType(Icon)),
    );

    // Test environment defaults to a light platform brightness.
    expect(iconOf().icon, Icons.light_mode_outlined);

    await tester.tap(toggle);
    await tester.pumpAndSettle();

    expect(iconOf().icon, Icons.dark_mode_outlined);
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.dark);
  });

  testWidgets('trim button is disabled until a valid selection exists', (
    tester,
  ) async {
    final session = VideoSession(initOnConstruct: false);
    addTearDown(session.dispose);

    session.setStartText('not a time');
    session.setEndText('0:00:05');

    await tester.pumpWidget(
      _wrap(StartEndRow(session: session, onRequestTrim: () {})),
    );
    await tester.pumpAndSettle();

    var trimButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Trim'),
    );
    expect(trimButton.onPressed, isNull);

    session.setStartText('0:00:01');
    await tester.pump();

    trimButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Trim'),
    );
    expect(trimButton.onPressed, isNotNull);
  });

  testWidgets('text resolves to the bundled UI and mono families', (
    tester,
  ) async {
    final session = VideoSession(initOnConstruct: false);
    addTearDown(session.dispose);

    await tester.pumpWidget(VideoTrimmerApp(session: session));
    await tester.pumpAndSettle();

    final theme = Theme.of(tester.element(find.text('Video Trimmer')));
    expect(theme.textTheme.bodyMedium?.fontFamily, kUiFontFamily);
    expect(theme.textTheme.bodyMedium?.fontSize, 13.5);
    expect(theme.textTheme.titleLarge?.fontWeight, FontWeight.w600);
  });

  testWidgets('time entries use the bundled mono family', (tester) async {
    final session = VideoSession(initOnConstruct: false);
    addTearDown(session.dispose);

    await tester.pumpWidget(
      _wrap(StartEndRow(session: session, onRequestTrim: () {})),
    );
    await tester.pumpAndSettle();

    for (final field in tester.widgetList<TextField>(find.byType(TextField))) {
      expect(field.style?.fontFamily, kMonoFontFamily);
    }
  });
}
