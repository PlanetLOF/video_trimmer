import 'package:material_ui/material_ui.dart';

/// Family used for all UI text. Bundled in `assets/fonts` (see `pubspec.yaml`)
/// so Linux, macOS and Windows render identically instead of falling back to
/// whatever the host system provides.
const String kUiFontFamily = 'Inter';

/// Family used for timecodes, the ffmpeg log and other fixed-width content.
const String kMonoFontFamily = 'JetBrains Mono';

/// Last-resort fallbacks for [kUiFontFamily], so a glyph missing from Inter
/// (emoji, symbols) still renders instead of showing a tofu box.
const List<String> kFontFamilyFallback = <String>[
  'Segoe UI',
  'Cantarell',
  'DejaVu Sans',
  'Noto Sans',
  'Noto Color Emoji',
  'Noto Sans Symbols 2',
];

/// Last-resort fallbacks for [kMonoFontFamily].
const List<String> kMonoFontFamilyFallback = <String>[
  'Cascadia Mono',
  'Consolas',
  'Menlo',
  'DejaVu Sans Mono',
  'Noto Sans Mono',
];

/// Builds the app [TextTheme] from the platform default [base].
///
/// Applies the bundled UI family everywhere, then tightens the Material 3
/// (2021) scale for a compact desktop layout: the M3 sizes are tuned for touch
/// and are noticeably large for a dense toolbar. The display/headline slots are
/// left as-is — the app does not use them — but still get the new family.
TextTheme buildAppTextTheme(TextTheme base) {
  final themed = base.apply(
    fontFamily: kUiFontFamily,
    fontFamilyFallback: kFontFamilyFallback,
  );

  return themed.copyWith(
    titleLarge: themed.titleLarge?.copyWith(
      fontSize: 18,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.2,
      height: 1.3,
    ),
    titleMedium: themed.titleMedium?.copyWith(
      fontSize: 15,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.1,
      height: 1.35,
    ),
    titleSmall: themed.titleSmall?.copyWith(
      fontSize: 13.5,
      fontWeight: FontWeight.w600,
      height: 1.35,
    ),
    bodyLarge: themed.bodyLarge?.copyWith(
      fontSize: 14.5,
      letterSpacing: 0,
      height: 1.45,
    ),
    bodyMedium: themed.bodyMedium?.copyWith(
      fontSize: 13.5,
      letterSpacing: 0.1,
      height: 1.45,
    ),
    bodySmall: themed.bodySmall?.copyWith(
      fontSize: 12,
      letterSpacing: 0.1,
      height: 1.4,
    ),
    labelLarge: themed.labelLarge?.copyWith(
      fontSize: 13.5,
      letterSpacing: 0.1,
      height: 1.3,
    ),
    labelMedium: themed.labelMedium?.copyWith(
      fontSize: 12,
      letterSpacing: 0.2,
      height: 1.3,
    ),
    labelSmall: themed.labelSmall?.copyWith(letterSpacing: 0.3, height: 1.3),
  );
}

/// Builds a fixed-width [TextStyle] for timecodes and log output.
///
/// Deliberately context-free so it can also be used from a [CustomPainter],
/// which has no [BuildContext]. Pair it with the themed colour and size of the
/// surrounding text, e.g. `monoStyle(fontSize: 13, fontWeight: FontWeight.w600)`.
TextStyle monoStyle({
  double? fontSize,
  FontWeight? fontWeight,
  Color? color,
  double? letterSpacing,
  double? height,
}) {
  return TextStyle(
    fontFamily: kMonoFontFamily,
    fontFamilyFallback: kMonoFontFamilyFallback,
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
    letterSpacing: letterSpacing,
    height: height,
  );
}
