import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:video_trimmer/screen/app.dart';
import 'package:video_trimmer/screen/app_menu.dart';
import 'package:video_trimmer/screen/settings_sheet.dart';
import 'package:video_trimmer/screen/start_end_row.dart';
import 'package:video_trimmer/generated/app_version.g.dart';
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
  await tester.tap(find.byType(PopupMenuButton<AppMenuAction>));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Settings\u2026'));
  await tester.pumpAndSettle();
}

Future<void> _openMenu(WidgetTester tester) async {
  await tester.tap(find.byType(PopupMenuButton<AppMenuAction>));
  await tester.pumpAndSettle();
}

/// The ticks drawn while the menu is open.
///
/// The menu is built into its own route, and the trimming entries are the only
/// thing on screen that draws a tick, so the count is unambiguous. (The menu's
/// own widget tree is private, so it cannot be used to scope the search.)
Finder _menuTicks() => find.byIcon(Icons.check);

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

  testWidgets('settings sheet offers all accents and the three theme modes', (
    tester,
  ) async {
    await _pumpApp(tester);
    await _openSettings(tester);

    expect(find.text('Settings'), findsOneWidget);
    expect(find.byType(BottomSheet), findsOneWidget);
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

    // The app underneath (not just the sheet) adopted the new accent.
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
    // The sheet stays open and shows the new selection.
    expect(find.text('Settings'), findsOneWidget);
  });

  testWidgets('the settings sheet itself restyles when the accent changes', (
    tester,
  ) async {
    await _pumpApp(tester);
    await _openSettings(tester);

    Color primaryInsideSheet() =>
        Theme.of(tester.element(find.byType(SegmentedButton<ThemeMode>)))
            .colorScheme
            .primary;

    final before = primaryInsideSheet();

    await tester.tap(find.byTooltip(AppAccent.purple.label));
    await tester.pumpAndSettle();

    // `showModalBottomSheet` captures and freezes the InheritedThemes between
    // the calling context and the target navigator. `MaterialApp` puts its
    // `Theme` above the navigator, so the `Theme` escapes the capture and the
    // sheet keeps restyling. This pins that: it would fail if a `Navigator`
    // were ever placed above the `Theme`, with the app behind the sheet still
    // looking perfectly correct.
    expect(primaryInsideSheet(), isNot(before));
    expect(
      primaryInsideSheet(),
      buildAppTheme(
        brightness: .light,
        accent: AppAccent.purple,
      ).colorScheme.primary,
    );
  });

  testWidgets('the sheet honours the persisted settings on open', (
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

  testWidgets('every accent is labelled, not only named in a tooltip', (
    tester,
  ) async {
    await _pumpApp(tester);
    await _openSettings(tester);

    for (final accent in AppAccent.values) {
      expect(find.text(accent.label), findsOneWidget, reason: accent.name);
    }
  });

  testWidgets('switching accent leaves exactly one accent ticked', (
    tester,
  ) async {
    await _pumpApp(tester);
    await _openSettings(tester);

    await tester.tap(find.byTooltip(AppAccent.red.label));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.check), findsOneWidget);
    // The tick moved with the selection rather than being left behind.
    expect(
      find.descendant(
        of: find.byTooltip(AppAccent.red.label),
        matching: find.byIcon(Icons.check),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byTooltip(AppAccent.pink.label),
        matching: find.byIcon(Icons.check),
      ),
      findsNothing,
    );
  });

  testWidgets('reset restores the defaults and persists them', (tester) async {
    final store = InMemoryAppSettingsStore();
    await _pumpApp(tester, store: store);
    await _openSettings(tester);

    await tester.tap(find.byTooltip(AppAccent.blue.label));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Reset to defaults'));
    await tester.pumpAndSettle();

    expect(await store.load(), const AppSettings());
    expect(_themeMode(tester), ThemeMode.system);
    expect(
      _colorScheme(tester).primary,
      buildAppTheme(
        brightness: .light,
        accent: AppAccent.pink,
      ).colorScheme.primary,
    );
  });

  testWidgets('the done button dismisses the settings sheet', (tester) async {
    await _pumpApp(tester);
    await _openSettings(tester);

    expect(find.byType(BottomSheet), findsOneWidget);

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsNothing);
  });

  testWidgets('the footer stays on screen when the body has to scroll', (
    tester,
  ) async {
    // Short enough that the body cannot show the header, body and footer at
    // once. The footer lives outside the scroll view, so it must not be the
    // part that gets cut off.
    tester.view.physicalSize = const Size(400, 320);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    // Driven through a bare app rather than `_pumpApp`: at this height the
    // home page behind the sheet overflows on its own, which is a separate
    // concern from the sheet's own layout.
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(brightness: .light, accent: AppAccent.pink),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => showSettingsSheet(
                  context,
                  settings: const AppSettings(),
                  onChanged: (_) {},
                ),
                child: const Text('open settings'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open settings'));
    await tester.pumpAndSettle();

    // The body genuinely does not fit, so the footer being visible can only be
    // down to it sitting outside the scroller.
    final scroller = tester.state<ScrollableState>(find.byType(Scrollable));
    expect(scroller.position.maxScrollExtent, greaterThan(0));

    expect(find.text('Done'), findsOneWidget);
    expect(tester.getBottomLeft(find.text('Done')).dy, lessThanOrEqualTo(320));
    expect(find.text('Reset to defaults'), findsOneWidget);
    expect(
      tester.getBottomLeft(find.text('Reset to defaults')).dy,
      lessThanOrEqualTo(320),
    );
  });

  testWidgets('the menu groups its entries and shows the open shortcut', (
    tester,
  ) async {
    await _pumpApp(tester);
    await _openMenu(tester);

    // Three captions plus five actionable entries, split by two dividers. The
    // entries are private subclasses, so match on the base type rather than by
    // exact runtime type.
    expect(
      find.byWidgetPredicate((w) => w is PopupMenuItem<AppMenuAction>),
      findsNWidgets(8),
    );
    expect(find.byType(PopupMenuDivider), findsNWidgets(2));
    // Section captions, uppercased by the widget itself.
    for (final caption in ['FILE', 'TRIMMING', 'APPLICATION']) {
      expect(find.text(caption), findsOneWidget, reason: caption);
    }
    expect(find.text('Ctrl+O'), findsOneWidget);
    // The icons that give each command a leading glyph. Presence only: the
    // menu route renders its entries more than once, so a count proves nothing.
    expect(find.byIcon(Icons.folder_open), findsWidgets);
    expect(find.byIcon(Icons.tune), findsWidgets);
    expect(find.byIcon(Icons.info_outline), findsWidgets);
  });

  testWidgets(
    'the trimming entries render as checkboxes, unticked by default',
    (tester) async {
      final session = await _pumpApp(tester);
      await _openMenu(tester);

      expect(session.precise, isFalse);
      expect(session.removeAudio, isFalse);
      // A tick means "checked"; the labels are always present either way.
      expect(_menuTicks(), findsNothing);
    },
  );

  testWidgets('ticking a trimming entry flips the session flag', (
    tester,
  ) async {
    final session = await _pumpApp(tester);

    await _openMenu(tester);
    await tester.tap(find.text('Precise (re-encode)'));
    await tester.pumpAndSettle();
    expect(session.precise, isTrue);

    // The menu closes on selection, so reopen it to see the ticked box.
    await _openMenu(tester);
    expect(_menuTicks(), findsOneWidget);
    await tester.tap(find.text('Remove audio'));
    await tester.pumpAndSettle();
    expect(session.removeAudio, isTrue);

    await _openMenu(tester);
    expect(_menuTicks(), findsNWidgets(2));

    // Tapping again unticks.
    await tester.tap(find.text('Precise (re-encode)'));
    await tester.pumpAndSettle();
    expect(session.precise, isFalse);
    await _openMenu(tester);
    expect(_menuTicks(), findsOneWidget);
  });

  testWidgets('the about sheet opens and closes', (tester) async {
    await _pumpApp(tester);

    await tester.tap(find.byType(PopupMenuButton<AppMenuAction>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('About'));
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsOneWidget);
    // The About sheet shows the version only; the build number is not part of
    // the line, and `app_version_test.dart` pins that too.
    expect(find.text('version $appVersion'), findsOneWidget);
    expect(find.text('GPL-3.0'), findsOneWidget);

    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsNothing);
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
