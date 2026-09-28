import 'package:material_ui/material_ui.dart';

import '../common/video_session.dart';

/// Actions the app bar's overflow menu can return.
///
/// An enum rather than bare strings so the `switch` that handles them is
/// checked for exhaustiveness; a mistyped string case in a `switch` on `String`
/// compiles fine and silently does nothing.
enum AppMenuAction { open, precise, removeAudio, settings, about }

/// Builds the entries for the app bar's overflow menu.
///
/// The two trimming flags are per-video session state rather than persisted
/// settings, which is why they stay in the menu: they reset when another file
/// is opened, and a sheet called "Settings" would imply otherwise.
List<PopupMenuEntry<AppMenuAction>> buildAppMenuEntries(VideoSession session) {
  return [
    _MenuCaption('File'),
    _MenuItem(
      action: AppMenuAction.open,
      icon: Icons.folder_open,
      label: 'Open…',
      // The binding is `control`, not `meta` — see `AppShortcuts`.
      hint: 'Ctrl+O',
    ),
    const PopupMenuDivider(),
    _MenuCaption('Trimming'),
    _MenuCheckItem(
      action: AppMenuAction.precise,
      label: 'Precise (re-encode)',
      checked: session.precise,
    ),
    _MenuCheckItem(
      action: AppMenuAction.removeAudio,
      label: 'Remove audio',
      checked: session.removeAudio,
    ),
    const PopupMenuDivider(),
    _MenuCaption('Application'),
    _MenuItem(
      action: AppMenuAction.settings,
      icon: Icons.tune,
      label: 'Settings…',
    ),
    _MenuItem(
      action: AppMenuAction.about,
      icon: Icons.info_outline,
      label: 'About',
    ),
  ];
}

/// A small muted heading that groups the entries under it.
///
/// Disabled so it cannot be picked: [PopupMenuItem] only wires the tap handler
/// when enabled, and a `null` value is never reported through `onSelected`.
///
/// Not a `const` constructor: Dart forbids a const constructor from building
/// another const object out of its own parameter, which is exactly what the
/// caption label is.
class _MenuCaption extends PopupMenuItem<AppMenuAction> {
  _MenuCaption(String label)
    : super(
        enabled: false,
        value: null,
        height: 30.0,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
        child: _CaptionText(label),
      );
}

class _CaptionText extends StatelessWidget {
  const _CaptionText(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    // Spelled out rather than relying on the inherited style: a disabled item
    // dims its whole subtree, and these are already as muted as they read.
    return Text(
      label.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
      ),
    );
  }
}

/// A command entry: leading icon, label, and an optional right-aligned
/// keyboard hint.
class _MenuItem extends PopupMenuItem<AppMenuAction> {
  _MenuItem({
    required AppMenuAction action,
    required IconData icon,
    required String label,
    String? hint,
  }) : super(
         value: action,
         padding: const EdgeInsets.symmetric(horizontal: 16),
         child: _MenuItemRow(icon: icon, label: label, hint: hint),
       );
}

class _MenuItemRow extends StatelessWidget {
  const _MenuItemRow({required this.icon, required this.label, this.hint});

  final IconData icon;
  final String label;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Row(
      children: [
        Icon(icon, size: 18, color: colorScheme.onSurfaceVariant),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: textTheme.bodyMedium,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (hint != null) ...[
          const SizedBox(width: 16),
          Text(
            hint!,
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

/// A togglable entry drawn as a checkbox in the leading slot.
///
/// [CheckedPopupMenuItem] would animate a tick into the *trailing* slot, which
/// reads as a status rather than a control; a leading box matches the affordance
/// the settings sheet uses for the same kind of choice.
class _MenuCheckItem extends PopupMenuItem<AppMenuAction> {
  _MenuCheckItem({
    required AppMenuAction action,
    required String label,
    required bool checked,
  }) : super(
         value: action,
         padding: const EdgeInsets.symmetric(horizontal: 16),
         child: _MenuCheckRow(label: label, checked: checked),
       );
}

class _MenuCheckRow extends StatelessWidget {
  const _MenuCheckRow({required this.label, required this.checked});

  final String label;
  final bool checked;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Row(
      children: [
        _CheckBox(checked: checked),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: textTheme.bodyMedium,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// A decorative checkbox. Not interactive on its own — the enclosing
/// [PopupMenuItem] handles the tap for the whole row.
class _CheckBox extends StatelessWidget {
  const _CheckBox({required this.checked});

  static const _size = 18.0;

  final bool checked;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    const radius = BorderRadius.all(Radius.circular(4));

    return Container(
      width: _size,
      height: _size,
      decoration: BoxDecoration(
        color: checked ? colorScheme.primary : Colors.transparent,
        borderRadius: radius,
        border: Border.all(
          color: checked
              ? colorScheme.primary
              : colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
          width: 1.5,
        ),
      ),
      child: checked
          ? const Icon(
              Icons.check,
              size: 13,
              // `primary` is a mid-tone seed colour, so the tick stays
              // legible against it in both brightnesses.
              color: Colors.white,
            )
          : null,
    );
  }
}
