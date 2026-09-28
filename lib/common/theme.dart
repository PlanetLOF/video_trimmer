import 'package:material_ui/material_ui.dart';

import 'typography.dart';

/// The accent colours the user can pick from in the settings dialog.
///
/// [seed] is fed to [ColorScheme.fromSeed]; [label] is only used for the
/// tooltip on the settings swatch.
enum AppAccent {
  pink(Colors.pink, 'Pink'),
  red(Colors.red, 'Red'),
  orange(Colors.orange, 'Orange'),
  yellow(Colors.yellow, 'Yellow'),
  green(Colors.green, 'Green'),
  teal(Colors.teal, 'Teal'),
  blue(Colors.blue, 'Blue'),
  purple(Colors.purple, 'Purple'),
  brown(Colors.brown, 'Brown');

  const AppAccent(this.seed, this.label);

  final Color seed;
  final String label;
}

ThemeData buildAppTheme({
  required Brightness brightness,
  required AppAccent accent,
}) {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: accent.seed,
    brightness: brightness,
    dynamicSchemeVariant: .vibrant,
  );
  // The seed scheme is passed down so the colors the text theme picks up come
  // from the same scheme as the rest of the app.
  final base = ThemeData(brightness: brightness, colorScheme: colorScheme);
  final textTheme = buildAppTextTheme(base.textTheme);

  return ThemeData(
    colorScheme: colorScheme,
    fontFamily: kUiFontFamily,
    fontFamilyFallback: kFontFamilyFallback,
    textTheme: textTheme,
    visualDensity: VisualDensity.compact,
    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    appBarTheme: AppBarTheme(
      backgroundColor: colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: textTheme.titleLarge?.copyWith(
        color: colorScheme.onSurface,
      ),
      iconTheme: IconThemeData(color: colorScheme.onSurfaceVariant),
      actionsIconTheme: IconThemeData(color: colorScheme.onSurfaceVariant),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 40),
        shape: RoundedRectangleBorder(borderRadius: .circular(10)),
        padding: const EdgeInsets.symmetric(horizontal: 20),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 40),
        shape: RoundedRectangleBorder(borderRadius: .circular(10)),
        padding: const EdgeInsets.symmetric(horizontal: 16),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: .circular(8)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: .circular(10),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: .circular(10),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: .circular(10),
        borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: .circular(10),
        borderSide: BorderSide(color: colorScheme.error, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: .circular(10),
        borderSide: BorderSide(color: colorScheme.error, width: 1.5),
      ),
      labelStyle: textTheme.bodySmall?.copyWith(
        color: colorScheme.onSurfaceVariant,
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: colorScheme.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: .circular(16)),
      titleTextStyle: textTheme.titleLarge?.copyWith(
        color: colorScheme.onSurface,
      ),
    ),
    // Mirrors `dialogTheme` so sheets and dialogs read as the same surface.
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: colorScheme.surfaceContainerLow,
      modalBackgroundColor: colorScheme.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: .only(topLeft: .circular(16), topRight: .circular(16)),
      ),
      showDragHandle: true,
      dragHandleColor: colorScheme.onSurfaceVariant,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: colorScheme.primary,
      contentTextStyle: textTheme.bodyMedium?.copyWith(
        color: colorScheme.onPrimary,
      ),
      actionTextColor: colorScheme.onPrimary,
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: colorScheme.inverseSurface,
        borderRadius: .circular(6),
      ),
      textStyle: textTheme.bodySmall?.copyWith(
        color: colorScheme.onInverseSurface,
      ),
      waitDuration: const Duration(milliseconds: 400),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: colorScheme.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: .circular(10)),
    ),
    dividerTheme: DividerThemeData(
      color: colorScheme.outlineVariant.withValues(alpha: 0.5),
      thickness: 1,
    ),
  );
}
