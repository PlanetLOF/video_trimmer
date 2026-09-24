import 'package:flutter/material.dart';

import '../common/video_session.dart';

/// Displays editable start/end timestamp entries with validation styling and a
/// Trim button. Two-way syncs with [VideoSession] so entries update from
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

  InputDecoration _decoration({required bool hasError}) {
    return InputDecoration(
      border: const UnderlineInputBorder(),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      errorText: hasError ? '' : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 12),
      child: Row(
        children: [
          const Text('Start', style: TextStyle(fontSize: 12)),
          const SizedBox(width: 6),
          Expanded(
            child: TextField(
              controller: _startCtrl,
              onChanged: _onStartChanged,
              decoration: _decoration(hasError: _session.startError),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
            ),
          ),
          const SizedBox(width: 16),
          const Text('End', style: TextStyle(fontSize: 12)),
          const SizedBox(width: 6),
          Expanded(
            child: TextField(
              controller: _endCtrl,
              onChanged: _onEndChanged,
              decoration: _decoration(hasError: _session.endError),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
            ),
          ),
          const SizedBox(width: 16),
          FilledButton.icon(
            onPressed: _session.selectionValid ? widget.onRequestTrim : null,
            icon: const Icon(Icons.content_cut, size: 18),
            label: const Text('Trim'),
          ),
        ],
      ),
    );
  }
}