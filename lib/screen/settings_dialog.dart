import 'package:material_ui/material_ui.dart';

import '../common/app_settings.dart';
import '../common/theme.dart';

/// Opens the "Settings" dialog.
///
/// Every change is reported through [onChanged] immediately, so the surrounding
/// app restyles live. The dialog keeps its own copy of the selection because a
/// pushed route is not rebuilt when the enclosing `MaterialApp` rebuilds — only
/// its `Theme` dependencies are.
Future<void> showSettingsDialog(
  BuildContext context, {
  required AppSettings settings,
  required ValueChanged<AppSettings> onChanged,
}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) =>
        _SettingsDialog(initialSettings: settings, onChanged: onChanged),
  );
}

class _SettingsDialog extends StatefulWidget {
  const _SettingsDialog({
    required this.initialSettings,
    required this.onChanged,
  });

  final AppSettings initialSettings;
  final ValueChanged<AppSettings> onChanged;

  @override
  State<_SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<_SettingsDialog> {
  late AppSettings _settings = widget.initialSettings;

  void _update(AppSettings settings) {
    setState(() => _settings = settings);
    widget.onChanged(settings);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final labelStyle = Theme.of(context).textTheme.titleSmall
        ?.copyWith(color: colorScheme.onSurfaceVariant);

    return AlertDialog(
      title: const Text('Settings'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Accent colour', style: labelStyle),
          const SizedBox(height: 12),
          _AccentGrid(
            selected: _settings.accent,
            onSelected: (accent) => _update(_settings.copyWith(accent: accent)),
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
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
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
    // Fixing the width to exactly three swatches plus two gaps keeps the grid
    // at 3x3 instead of letting it stretch into a single row.
    return SizedBox(
      // width: _columns * _swatchSize + (_columns - 1) * _spacing,
      child: Wrap(
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
      ),
    );
  }

  static Color _borderColor(BuildContext context, bool isSelected) {
    final colorScheme = Theme.of(context).colorScheme;
    return isSelected
        ? colorScheme.onSurface
        : colorScheme.outlineVariant.withValues(alpha: 0.5);
  }
}
