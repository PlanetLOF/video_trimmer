import 'package:flutter/material.dart';

const _appVersion = '1.0.0';

Future<void> showVideoTrimmerAboutDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.movie, size: 40),
          SizedBox(width: 12),
          Expanded(child: Text('About Video Trimmer')),
        ],
      ),
      content: const Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Video Trimmer version $_appVersion'),
          SizedBox(height: 4),
          Text(
            'GPL-3.0',
            style: TextStyle(fontSize: 12),
          ),
          SizedBox(height: 8),
          Text('Trim videos quickly, without re-encoding.'),
          SizedBox(height: 8),
          Text(
            'A reimplementation of the GNOME Video Trimmer for Windows and '
            'Linux. Uses ffmpeg for trimming and libmpv (media_kit) for '
            'preview.',
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}