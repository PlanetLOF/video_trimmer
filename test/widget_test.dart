import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:video_trimmer/screen/app.dart';
import 'package:video_trimmer/screen/start_end_row.dart';
import 'package:video_trimmer/common/typography.dart';
import 'package:video_trimmer/common/app_settings.dart';
import 'package:video_trimmer/common/theme.dart';
import 'package:video_trimmer/common/video_session.dart';

Widget _wrap(Widget child) {
  return MaterialApp(home: Scaffold(body: child));
}

Future<VideoSession> _pumpApp(
  WidgetTester tester, {
  AppSettings initialSettings = const AppSettings(),
  AppSettingsStore? store,
}) async {
  final session = VideoSession(initOnConstruct: false);
  addTearDown(session.dispose);
  await tester.pumpWidget(
    VideoTrimmerApp(
      session: session,
      initialSettings: initialSettings,
      settingsStore: store,
    ),
  );
  await tester.pumpAndSettle();
  return session;
}

Future<void> _openSettings(WidgetTester tester) async {
  await tester.tap(find.byType(PopupMenuButton<String>));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Settings\u2026'));
  await tester.pumpAndSettle();
}

ColorScheme _colorScheme(WidgetTester tester) =>
    tester.widget<MaterialApp>(find.byType(MaterialApp)).theme!.colorScheme;

ThemeMode _themeMode(WidgetTester tester) =>
    tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode!;

void main() {
  testWidgets('app shows the open prompt when nothing is open', (tester) async {
    await _pumpApp(tester);

    expect(find.text('Video Trimmer'), findsOneWidget);
    expect(find.text('Open'), findsWidgets);
    expect(find.byIcon(Icons.movie_outlined), findsOneWidget);
    expect(find.text('Trim'), findsNothing);
  });

  testWidgets('settings dialog offers all accents and the three theme modes', (
    tester,
  ) async {
    await _pumpApp(tester);
    await _openSettings(tester);

    expect(find.text('Settings'), findsOneWidget);
    for (final accent in AppAccent.values) {
      expect(find.byTooltip(accent.label), findsOneWidget, reason: accent.name);
    }
    for (final mode in ['Light', 'Dark', 'System']) {
      expect(find.text(mode), findsOneWidget, reason: mode);
    }
  });

  testWidgets('picking an accent recolours the app and persists it', (
    tester,
  ) async {
    final store = InMemoryAppSettingsStore();
    await _pumpApp(tester, store: store);
    await _openSettings(tester);

    final before = _colorScheme(tester).primary;
    await tester.tap(find.byTooltip(AppAccent.blue.label));
    await tester.pumpAndSettle();

    // The app underneath (not just the dialog) adopted the new accent.
    final after = _colorScheme(tester).primary;
    expect(after, isNot(before));
    expect(
      after,
      buildAppTheme(
        brightness: .light,
        accent: AppAccent.blue,
      ).colorScheme.primary,
    );
    expect(await store.load(), const AppSettings(accent: AppAccent.blue));
  });

  testWidgets('the accent choice survives a theme mode change', (tester) async {
    final store = InMemoryAppSettingsStore();
    await _pumpApp(tester, store: store);
    await _openSettings(tester);

    await tester.tap(find.byTooltip(AppAccent.teal.label));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();

    // Both halves of the settings are kept, and the mode is applied.
    expect(
      await store.load(),
      const AppSettings(accent: AppAccent.teal, themeMode: ThemeMode.dark),
    );
    expect(_themeMode(tester), ThemeMode.dark);
    // The dialog stays open and shows the new selection.
    expect(find.text('Settings'), findsOneWidget);
  });

  testWidgets('the dialog honours the persisted settings on open', (
    tester,
  ) async {
    await _pumpApp(
      tester,
      initialSettings: const AppSettings(
        accent: AppAccent.green,
        themeMode: ThemeMode.light,
      ),
    );

    expect(_themeMode(tester), ThemeMode.light);
    expect(
      _colorScheme(tester).primary,
      buildAppTheme(
        brightness: .light,
        accent: AppAccent.green,
      ).colorScheme.primary,
    );

    await _openSettings(tester);
    // A single check mark marks the active accent.
    expect(find.byIcon(Icons.check), findsOneWidget);
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
  test('AppSettings.copyWith merges only the given fields', () {
    const base = AppSettings(accent: AppAccent.purple);
    expect(base.copyWith(themeMode: ThemeMode.dark).accent, AppAccent.purple);
    expect(base.copyWith(themeMode: ThemeMode.dark).themeMode, ThemeMode.dark);
    expect(base.copyWith(accent: AppAccent.red).themeMode, ThemeMode.system);
  });
}
