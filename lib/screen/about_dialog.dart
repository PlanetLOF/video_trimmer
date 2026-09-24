import 'package:flutter/material.dart';

const _appVersion = '1.0.0';

Future<void> showVideoTrimmerAboutDialog(BuildContext context) {
  final colorScheme = Theme.of(context).colorScheme;
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Row(
        children: [Expanded(child: Text('About Video Trimmer'))],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.movie,
                  size: 28,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Video Trimmer',
                    style: Theme.of(dialogContext).textTheme.titleMedium,
                  ),
                  Text(
                    'version $_appVersion',
                    style: Theme.of(dialogContext).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'GPL-3.0',
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Text(
            'Trim videos quickly, without re-encoding.',
            style: Theme.of(dialogContext).textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'A reimplementation of the GNOME Video Trimmer for Windows and '
            'Linux. Uses ffmpeg for trimming and libmpv (media_kit) for '
            'preview.',
            style: Theme.of(dialogContext).textTheme.bodyMedium
                ?.copyWith(color: colorScheme.onSurfaceVariant),
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
