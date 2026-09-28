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
///
/// The header and footer sit outside the scroll view so they stay put when the
/// window is too short for the whole body.
Future<void> showSettingsSheet(
  BuildContext context, {
  required AppSettings settings,
  required ValueChanged<AppSettings> onChanged,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    // Without a cap the sheet shrink-wraps its content and reads as a narrow
    // strip floating in a wide window. Only the width is constrained; the route
    // still bounds the height, which is what `isScrollControlled` relies on.
    constraints: const BoxConstraints(maxWidth: 520),
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

  bool get _isDefault => _settings == const AppSettings();

  void _update(AppSettings settings) {
    setState(() => _settings = settings);
    widget.onChanged(settings);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildHeader(context),
        const Divider(height: 1),
        // `isScrollControlled: true` hands the sheet the full window height, so
        // the body has to be able to scroll rather than overflow. `Flexible`
        // (rather than `Expanded`) keeps the sheet shrink-wrapped when the body
        // is shorter than the space left over.
        Flexible(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SettingsSection(
                    icon: Icons.palette_outlined,
                    title: 'Accent colour',
                    description:
                        'Sets the colour of buttons and of the selected '
                        'range on the timeline.',
                    child: _AccentGrid(
                      selected: _settings.accent,
                      onSelected: (accent) =>
                          _update(_settings.copyWith(accent: accent)),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Divider(height: 1),
                  const SizedBox(height: 24),
                  _SettingsSection(
                    icon: Icons.brightness_6_outlined,
                    title: 'Theme',
                    description:
                        'Follow the desktop setting, or lock the app to one '
                        'of the two.',
                    child: SegmentedButton<ThemeMode>(
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
                      onSelectionChanged: (selection) => _update(
                        _settings.copyWith(themeMode: selection.first),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const Divider(height: 1),
        _buildFooter(context),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      // The drag handle already supplies the top inset. The trailing inset
      // matches the body's so the title lines up with the section headings;
      // closing is the footer's job, along with tapping outside or Escape.
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
      child: Text('Settings', style: Theme.of(context).textTheme.titleLarge),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        // `spaceBetween` rather than a `Spacer`, which cannot be combined with
        // the `Flexible` below: two flexible children would each be offered a
        // share of the free space, so `Spacer` would not push Done all the way
        // to the trailing edge. This keeps Done flush right while still letting
        // the reset label shrink instead of overflowing in a narrow window.
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: TextButton.icon(
              // Disabled while already at the defaults, so a stray click cannot
              // look like it did something.
              onPressed: _isDefault ? null : () => _update(const AppSettings()),
              icon: const Icon(Icons.restart_alt),
              label: const Text(
                'Reset to defaults',
                softWrap: false,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
}

/// A titled group of related controls, with a one-line explanation of what the
/// setting actually does.
class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.icon,
    required this.title,
    required this.description,
    required this.child,
  });

  final IconData icon;
  final String title;
  final String description;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: colorScheme.onSurfaceVariant),
            const SizedBox(width: 8),
            Text(
              title,
              style: textTheme.titleSmall?.copyWith(
                color: colorScheme.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          description,
          style: textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 14),
        child,
      ],
    );
  }
}

/// The accent swatches, as labelled chips.
///
/// A bare row of circles only named the colours inside a tooltip, which needs a
/// hover to read, and left the selected one identifiable solely by a tick. The
/// label sits in the chip so the choice is readable at a glance.
class _AccentGrid extends StatelessWidget {
  const _AccentGrid({required this.selected, required this.onSelected});

  static const _dotSize = 18.0;
  static const _spacing = 8.0;

  final AppAccent selected;
  final ValueChanged<AppAccent> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: _spacing,
      runSpacing: _spacing,
      children: [
        for (final accent in AppAccent.values)
          _AccentChip(
            accent: accent,
            selected: accent == selected,
            onSelected: onSelected,
          ),
      ],
    );
  }
}

class _AccentChip extends StatelessWidget {
  const _AccentChip({
    required this.accent,
    required this.selected,
    required this.onSelected,
  });

  final AppAccent accent;
  final bool selected;
  final ValueChanged<AppAccent> onSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    const radius = BorderRadius.all(Radius.circular(8));

    return Tooltip(
      message: accent.label,
      child: Material(
        // Supplies the ink the `InkWell` paints. Without it the highlight and
        // splash would land on the sheet behind the chip, unclipped.
        type: MaterialType.transparency,
        child: InkWell(
          onTap: () => onSelected(accent),
          borderRadius: radius,
          child: Container(
            padding: const EdgeInsets.fromLTRB(10, 7, 12, 7),
            decoration: BoxDecoration(
              color: selected
                  ? colorScheme.secondaryContainer
                  : Colors.transparent,
              borderRadius: radius,
              border: Border.all(
                color: selected
                    ? colorScheme.primary
                    : colorScheme.outlineVariant.withValues(alpha: 0.5),
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: _AccentGrid._dotSize,
                  height: _AccentGrid._dotSize,
                  decoration: BoxDecoration(
                    color: accent.seed,
                    shape: BoxShape.circle,
                  ),
                  // The only tick on screen marks the active accent.
                  child: selected
                      ? Icon(
                          Icons.check,
                          size: 12,
                          color: accent.seed.computeLuminance() > 0.5
                              ? Colors.black
                              : Colors.white,
                        )
                      : null,
                ),
                const SizedBox(width: 8),
                Text(accent.label, style: textTheme.labelLarge),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
