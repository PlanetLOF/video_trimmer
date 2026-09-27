import 'package:material_ui/material_ui.dart';

import '../common/video_session.dart';

/// Bottom toolbar combining playback controls (step back / play-pause / step
/// forward), the current/total time readout, editable start/end timestamp
/// entries, and the Trim button — all in one row.
///
/// The time entries two-way sync with [VideoSession] so entries update from
/// timeline drags and timeline handles update from the entries.
class StartEndRow extends StatefulWidget {
  const StartEndRow({
    super.key,
    required this.session,
    required this.onRequestTrim,
  });

  final VideoSession session;
  final VoidCallback onRequestTrim;

  @override
  State<StartEndRow> createState() => _StartEndRowState();
}

class _StartEndRowState extends State<StartEndRow> {
  late final TextEditingController _startCtrl;
  late final TextEditingController _endCtrl;
  bool _syncing = false;

  VideoSession get _session => widget.session;

  @override
  void initState() {
    super.initState();
    _startCtrl = TextEditingController(text: _session.startText ?? '');
    _endCtrl = TextEditingController(text: _session.endText ?? '');
    _session.addListener(_onSessionChanged);
  }

  @override
  void dispose() {
    _session.removeListener(_onSessionChanged);
    _startCtrl.dispose();
    _endCtrl.dispose();
    super.dispose();
  }

  void _onSessionChanged() {
    if (!mounted) {
      return;
    }
    _syncFromSession();
    setState(() {});
  }

  void _syncFromSession() {
    final sessionStart = _session.startText ?? '';
    if (sessionStart != _startCtrl.text) {
      _syncing = true;
      _startCtrl.text = sessionStart;
      _syncing = false;
    }
    final sessionEnd = _session.endText ?? '';
    if (sessionEnd != _endCtrl.text) {
      _syncing = true;
      _endCtrl.text = sessionEnd;
      _syncing = false;
    }
  }

  void _onStartChanged(String value) {
    if (_syncing) {
      return;
    }
    _session.setStartText(value);
  }

  void _onEndChanged(String value) {
    if (_syncing) {
      return;
    }
    _session.setEndText(value);
  }

  String _formatPosition(Duration position) {
    final hours = position.inHours;
    final minutes = (position.inMinutes % 60).toString();
    final seconds = (position.inSeconds % 60).toString().padLeft(2, '0');
    if (hours == 0) {
      return '$minutes:$seconds';
    }
    final h = hours.toString();
    final m = (position.inMinutes % 60).toString().padLeft(2, '0');
    return '$h:$m:$seconds';
  }

  InputDecoration _decoration({
    required String label,
    required IconData icon,
    required bool hasError,
    required VoidCallback onSetFromPlayhead,
    required String setTooltip,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 18),
      prefixIconConstraints: const BoxConstraints(minWidth: 32),
      suffixIcon: IconButton(
        icon: const Icon(Icons.my_location, size: 18),
        tooltip: setTooltip,
        onPressed: onSetFromPlayhead,
      ),
      suffixIconConstraints: const BoxConstraints(minWidth: 32),
      errorText: hasError ? '' : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final mono = Theme.of(context).textTheme.bodyMedium
        ?.copyWith(fontFamily: 'monospace');

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          borderRadius: .circular(12),
          border: .all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          children: [
            IconButton.filled(
              iconSize: 24,
              icon: Icon(
                _session.playing
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
              ),
              tooltip: 'Play / Pause (Space)',
              onPressed: _session.togglePlay,
            ),
            const SizedBox(width: 4),
            Container(width: 1, height: 20, color: colorScheme.outlineVariant),
            const SizedBox(width: 10),
            Text(
              _formatPosition(_session.position),
              style: mono?.copyWith(fontWeight: FontWeight.w600),
            ),
            Text(
              ' / ${_formatPosition(_session.duration)}',
              style: mono?.copyWith(color: colorScheme.outline),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: TextField(
                controller: _startCtrl,
                onChanged: _onStartChanged,
                decoration: _decoration(
                  label: 'Start',
                  icon: Icons.flag_outlined,
                  hasError: _session.startError,
                  onSetFromPlayhead: _session.setStartAsPosition,
                  setTooltip: 'Set start to current position (I)',
                ),
                style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _endCtrl,
                onChanged: _onEndChanged,
                decoration: _decoration(
                  label: 'End',
                  icon: Icons.flag_rounded,
                  hasError: _session.endError,
                  onSetFromPlayhead: _session.setEndAsPosition,
                  setTooltip: 'Set end to current position (O)',
                ),
                style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
              ),
            ),
            const SizedBox(width: 14),
            FilledButton.icon(
              onPressed: _session.selectionValid ? widget.onRequestTrim : null,
              icon: const Icon(Icons.content_cut, size: 18),
              label: const Text('Trim'),
            ),
          ],
        ),
      ),
    );
  }
}
