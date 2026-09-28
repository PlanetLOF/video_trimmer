import 'package:material_ui/material_ui.dart';

import '../common/app_settings.dart';
import '../common/theme.dart';

/// Opens the "Settings" bottom sheet.
///
/// Every change is reported through [onChanged] immediately, so the surrounding
/// app restyles live. That relies on two things, both easy to break:
///
///  * The sheet keeps its own copy of the selection. A pushed route is not
///    rebuilt when the enclosing `MaterialApp` rebuilds, so reading a [settings]
///    field during build would freeze on the value it had when the sheet opened.
///  * [showModalBottomSheet] captures the [InheritedTheme]s between the calling
///    context and the target navigator, and captured themes are frozen — the
///    sheet would stop restyling. [MaterialApp] installs its `Theme` *above* the
///    navigator, so the `Theme` itself never falls inside the captured range and
///    the sheet stays a descendant of the live one. A [Navigator] placed above
///    the `Theme` would break this.
Future<void> showSettingsSheet(
  BuildContext context, {
  required AppSettings settings,
  required ValueChanged<AppSettings> onChanged,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) =>
        _SettingsSheet(initialSettings: settings, onChanged: onChanged),
  );
}

class _SettingsSheet extends StatefulWidget {
  const _SettingsSheet({
    required this.initialSettings,
    required this.onChanged,
  });

  final AppSettings initialSettings;
  final ValueChanged<AppSettings> onChanged;

  @override
  State<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<_SettingsSheet> {
  late AppSettings _settings = widget.initialSettings;

  void _update(AppSettings settings) {
    setState(() => _settings = settings);
    widget.onChanged(settings);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final labelStyle = textTheme.titleSmall?.copyWith(
      color: colorScheme.onSurfaceVariant,
    );

    return SingleChildScrollView(
      // `isScrollControlled: true` hands the sheet the full window height, so
      // without this a short window would overflow instead of scrolling.
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Settings', style: textTheme.titleLarge),
            const SizedBox(height: 20),
            Text('Accent colour', style: labelStyle),
            const SizedBox(height: 12),
            _AccentGrid(
              selected: _settings.accent,
              onSelected: (accent) =>
                  _update(_settings.copyWith(accent: accent)),
            ),
            const SizedBox(height: 24),
            Text('Theme', style: labelStyle),
            const SizedBox(height: 12),
            SegmentedButton<ThemeMode>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: ThemeMode.light,
                  icon: Icon(Icons.light_mode_outlined),
                  label: Text('Light'),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  icon: Icon(Icons.dark_mode_outlined),
                  label: Text('Dark'),
                ),
                ButtonSegment(
                  value: ThemeMode.system,
                  icon: Icon(Icons.brightness_auto_outlined),
                  label: Text('System'),
                ),
              ],
              selected: {_settings.themeMode},
              onSelectionChanged: (selection) =>
                  _update(_settings.copyWith(themeMode: selection.first)),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Done'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccentGrid extends StatelessWidget {
  const _AccentGrid({required this.selected, required this.onSelected});

  static const _swatchSize = 34.0;
  static const _spacing = 10.0;

  final AppAccent selected;
  final ValueChanged<AppAccent> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: _spacing,
      runSpacing: _spacing,
      children: [
        for (final accent in AppAccent.values)
          Tooltip(
            message: accent.label,
            child: InkWell(
              onTap: () => onSelected(accent),
              customBorder: const CircleBorder(),
              child: Container(
                width: _swatchSize,
                height: _swatchSize,
                decoration: BoxDecoration(
                  color: accent.seed,
                  shape: BoxShape.circle,
                  border: .all(
                    color: _borderColor(context, accent == selected),
                    width: accent == selected ? 3 : 1.5,
                  ),
                ),
                child: accent == selected
                    ? Icon(
                        Icons.check,
                        size: 18,
                        color: accent.seed.computeLuminance() > 0.5
                            ? Colors.black
                            : Colors.white,
                      )
                    : null,
              ),
            ),
          ),
      ],
    );
  }

  static Color _borderColor(BuildContext context, bool isSelected) {
    final colorScheme = Theme.of(context).colorScheme;
    return isSelected
        ? colorScheme.onSurface
        : colorScheme.outlineVariant.withValues(alpha: 0.5);
  }
}
