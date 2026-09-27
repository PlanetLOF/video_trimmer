import 'package:material_ui/material_ui.dart';

import '../util/ffmpeg.dart';
import '../util/platform_util.dart';

const _kCancelRequested = -2;
const _kSpawnFailed = -1;

/// Outcome of one trim run. Exit code 0 means the video was saved successfully;
/// any other value should be shown to the user as a failure.
class TrimOutcome {
  const TrimOutcome(this.exitCode, this.stderr);

  final int exitCode;
  final String stderr;
}

/// Opens the "Trimming…" dialog, runs ffmpeg, and reports the result to the
/// user (success SnackBar / error dialog). The dialog can be cancelled, which
/// kills the subprocess.
Future<void> runTrimFlow(
  BuildContext context, {
  required Ffmpeg ffmpeg,
  required String inputPath,
  required String outputPath,
  required String start,
  required String end,
  required bool reencode,
  required bool noAudio,
}) {
  final messenger = ScaffoldMessenger.of(context);

  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => _TrimmingDialog(
      ffmpeg: ffmpeg,
      inputPath: inputPath,
      outputPath: outputPath,
      start: start,
      end: end,
      reencode: reencode,
      noAudio: noAudio,
      onFinished: (outcome) =>
          _handleOutcome(dialogContext, messenger, outputPath, outcome),
    ),
  );
}

void _handleOutcome(
  BuildContext dialogContext,
  ScaffoldMessengerState messenger,
  String outputPath,
  TrimOutcome outcome,
) {
  final messenger2 = messenger;
  final name = _fileName(outputPath);
  switch (outcome.exitCode) {
    case 0:
      final colorScheme = Theme.of(dialogContext).colorScheme;
      messenger2.showSnackBar(
        SnackBar(
          duration: Duration(seconds: 60),
          backgroundColor: colorScheme.inverseSurface,
          content: Text('$name has been saved'),
          action: SnackBarAction(
            textColor: colorScheme.onInverseSurface,
            label: 'Show in Files',
            onPressed: () => PlatformUtil.showInFiles(outputPath),
          ),
        ),
      );
      Navigator.of(dialogContext).pop();
    case _kCancelRequested:
      Navigator.of(dialogContext).pop();
    case _kSpawnFailed:
      showDialog<void>(
        context: dialogContext,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Could not run ffmpeg'),
          content: Text(
            outcome.stderr.isEmpty
                ? 'Make sure ffmpeg is installed and available on your PATH '
                      'and that you have permission to write to the destination '
                      'folder.'
                : outcome.stderr,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    default:
      showDialog<void>(
        context: dialogContext,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Could not trim video'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Please attach the following information to your issue '
                  'report.',
                ),
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 240),
                  child: Container(
                    width: double.maxFinite,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(dialogContext)
                          .colorScheme
                          .surfaceContainerLow,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: SingleChildScrollView(
                      child: SelectableText(
                        outcome.stderr,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
  }
}

String _fileName(String path) {
  return path.split(RegExp(r'[\\/]')).last;
}

class _TrimmingDialog extends StatefulWidget {
  const _TrimmingDialog({
    this.ffmpeg,
    this.inputPath,
    this.outputPath,
    this.start,
    this.end,
    this.reencode,
    this.noAudio,
    this.onFinished,
  });

  final Ffmpeg? ffmpeg;
  final String? inputPath;
  final String? outputPath;
  final String? start;
  final String? end;
  final bool? reencode;
  final bool? noAudio;
  final void Function(TrimOutcome)? onFinished;

  @override
  State<_TrimmingDialog> createState() => _TrimmingDialogState();
}

class _TrimmingDialogState extends State<_TrimmingDialog> {
  bool _cancelled = false;
  FfmpegProcess? _process;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    final ffmpeg = widget.ffmpeg!;
    final FfmpegProcess process;
    try {
      process = await ffmpeg.start(
        inputPath: widget.inputPath!,
        outputPath: widget.outputPath!,
        start: widget.start!,
        end: widget.end!,
        reencode: widget.reencode!,
        noAudio: widget.noAudio!,
      );
    } catch (_) {
      widget.onFinished!(TrimOutcome(_kSpawnFailed, ''));
      return;
    }
    if (!mounted) {
      await process.cancel();
      return;
    }
    if (_cancelled) {
      await process.cancel();
      return;
    }
    _process = process;
    final result = await process.result;
    if (!mounted) {
      return;
    }
    _finish(TrimOutcome(result.exitCode, result.stderr));
  }

  void _finish(TrimOutcome outcome) {
    if (_cancelled && outcome.exitCode != _kSpawnFailed) {
      widget.onFinished!(TrimOutcome(_kCancelRequested, ''));
      return;
    }
    widget.onFinished!(outcome);
  }

  void _requestCancel() {
    if (_cancelled) {
      return;
    }
    _cancelled = true;
    _process?.cancel().ignore();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.content_cut),
          SizedBox(width: 12),
          Text('Trimming…'),
        ],
      ),
      content: SizedBox(
        width: 340,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              const Text(
                'Please wait while your video is being trimmed.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _fileName(widget.outputPath ?? ''),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            if (_cancelled) {
              return;
            }
            _requestCancel();
          },
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
