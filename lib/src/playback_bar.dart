import 'package:flutter/material.dart';

import 'video_session.dart';

/// Play/pause button and current-time label.
class PlaybackBar extends StatefulWidget {
  const PlaybackBar({super.key, required this.session});

  final VideoSession session;

  @override
  State<PlaybackBar> createState() => _PlaybackBarState();
}

class _PlaybackBarState extends State<PlaybackBar> {
  VideoSession get session => widget.session;

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

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: session,
      builder: (context, child) {
        final playing = session.playing;
        final position = session.position;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              IconButton(
                icon: Icon(
                  playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                ),
                tooltip: 'Play / Pause',
                onPressed: session.togglePlay,
              ),
              const SizedBox(width: 8),
              Text(
                _formatPosition(position),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontFamily: 'monospace',
                    ),
              ),
            ],
          ),
        );
      },
    );
  }
}