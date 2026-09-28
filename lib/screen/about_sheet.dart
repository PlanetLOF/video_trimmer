import 'package:material_ui/material_ui.dart';

import '../generated/app_version.g.dart';

Future<void> showVideoTrimmerAboutSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) {
      final colorScheme = Theme.of(sheetContext).colorScheme;
      final textTheme = Theme.of(sheetContext).textTheme;
      return SingleChildScrollView(
        // `isScrollControlled: true` hands the sheet the full window height, so
        // without this a short window would overflow instead of scrolling.
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('About Video Trimmer', style: textTheme.titleLarge),
              const SizedBox(height: 20),
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
                      Text('Video Trimmer', style: textTheme.titleMedium),
                      Text('version $appVersion', style: textTheme.bodySmall),
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
                style: textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'A reimplementation of the GNOME Video Trimmer for Linux, '
                'macOS and Windows. Uses ffmpeg for trimming and libmpv (media_kit) for '
                'preview.',
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(sheetContext).pop(),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
