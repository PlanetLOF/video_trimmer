import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import 'video_session.dart';

class _PlayPauseIntent extends Intent {
  const _PlayPauseIntent();
}

class _SetStartIntent extends Intent {
  const _SetStartIntent();
}

class _SetEndIntent extends Intent {
  const _SetEndIntent();
}

class _StepForwardIntent extends Intent {
  const _StepForwardIntent();
}

class _StepBackIntent extends Intent {
  const _StepBackIntent();
}

class _TrimIntent extends Intent {
  const _TrimIntent();
}

class _OpenIntent extends Intent {
  const _OpenIntent();
}

class _QuitIntent extends Intent {
  const _QuitIntent();
}

/// Wraps the app subtree in a [Shortcuts]/[Actions] tree that maps global key
/// bindings matching the original GNOME Video Trimmer.
class AppShortcuts extends StatelessWidget {
  const AppShortcuts({
    super.key,
    required this.session,
    required this.onTrim,
    required this.onOpen,
    required this.child,
  });

  final VideoSession session;
  final VoidCallback onTrim;
  final VoidCallback onOpen;
  final Widget child;

  bool get _inTextField {
    final focus = FocusManager.instance.primaryFocus;
    return focus?.context?.widget is EditableText;
  }

  void _guard(VoidCallback action) {
    if (_inTextField) {
      return;
    }
    action();
  }

  @override
  Widget build(BuildContext context) {
    return Actions(
      actions: <Type, Action<Intent>>{
        _PlayPauseIntent: CallbackAction<Intent>(
          onInvoke: (_) => _guard(session.togglePlay),
        ),
        _SetStartIntent: CallbackAction<Intent>(
          onInvoke: (_) => _guard(session.setStartAsPosition),
        ),
        _SetEndIntent: CallbackAction<Intent>(
          onInvoke: (_) => _guard(session.setEndAsPosition),
        ),
        _StepForwardIntent: CallbackAction<Intent>(
          onInvoke: (_) => _guard(session.stepForward),
        ),
        _StepBackIntent: CallbackAction<Intent>(
          onInvoke: (_) => _guard(session.stepBack),
        ),
        _TrimIntent: CallbackAction<Intent>(onInvoke: (_) => onTrim()),
        _OpenIntent: CallbackAction<Intent>(onInvoke: (_) => onOpen()),
        _QuitIntent: CallbackAction<Intent>(onInvoke: (_) => exit(0)),
      },
      child: Shortcuts(
        shortcuts: <ShortcutActivator, Intent>{
          // Play/pause
          const SingleActivator(LogicalKeyboardKey.space):
              const _PlayPauseIntent(),
          const SingleActivator(LogicalKeyboardKey.keyP):
              const _PlayPauseIntent(),
          const SingleActivator(LogicalKeyboardKey.keyK):
              const _PlayPauseIntent(),
          const SingleActivator(LogicalKeyboardKey.space, control: true):
              const _PlayPauseIntent(),
          // Set start / end as current position
          const SingleActivator(LogicalKeyboardKey.keyI):
              const _SetStartIntent(),
          const SingleActivator(LogicalKeyboardKey.keyO): const _SetEndIntent(),
          // Frame stepping
          const SingleActivator(LogicalKeyboardKey.period):
              const _StepForwardIntent(),
          const SingleActivator(LogicalKeyboardKey.comma):
              const _StepBackIntent(),
          // Trim
          const SingleActivator(LogicalKeyboardKey.keyS, control: true):
              const _TrimIntent(),
          // Open
          const SingleActivator(LogicalKeyboardKey.keyO, control: true):
              const _OpenIntent(),
          // Quit
          const SingleActivator(LogicalKeyboardKey.keyQ, control: true):
              const _QuitIntent(),
        },
        child: child,
      ),
    );
  }
}
