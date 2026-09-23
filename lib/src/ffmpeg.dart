import 'dart:convert';
import 'dart:io';

/// Builds ffmpeg trim arguments and runs the ffmpeg subprocess.
///
/// The argument sequence is a faithful port of the original Rust code:
///
/// ```
/// ffmpeg -loglevel error -ss <start> -to <end> -i <input> -map 0 -dn
///        -avoid_negative_ts make_zero -y
///        [-c copy]
///        [-c:v <encoder>]      (re-encode, mp4/mkv only)
///        [-an]                 (remove audio)
///        [-movflags +faststart] (mp4 only)
///        <output>
/// ```
class Ffmpeg {
  Ffmpeg({this.executable = 'ffmpeg'});

  final String executable;

  bool? _hasLibx264;

  static String extensionOf(String path) {
    final index = path.lastIndexOf('.');
    if (index == -1) {
      return '';
    }
    return path.substring(index + 1).toLowerCase();
  }

  static List<String> buildTrimArgs({
    required String inputPath,
    required String outputPath,
    required String start,
    required String end,
    required bool reencode,
    required bool noAudio,
    String? encoder,
  }) {
    final outputExtension = extensionOf(outputPath);

    final args = <String>[
      '-loglevel',
      'error',
      '-ss',
      start,
      '-to',
      end,
      '-i',
      inputPath,
      // By default FFmpeg selects only a single ("best") stream of each type.
      // We'd rather include all of them; this also fixes trimmed-down FFmpeg
      // builds dropping the subtitle track.
      '-map',
      '0',
      // GoPro recordings include data streams with a "none" tag which FFmpeg
      // fails to process, even when simply copying them.
      '-dn',
      // The output can only start from a keyframe when copying. Placing
      // -ss before -i starts from the earliest keyframe before the start
      // timestamp. Without this flag some players ignore negative timestamps
      // and show frames from before the start.
      '-avoid_negative_ts',
      'make_zero',
      '-y',
    ];

    if (!reencode) {
      args.addAll(['-c', 'copy']);
    }

    if (reencode && (outputExtension == 'mp4' || outputExtension == 'mkv')) {
      args.addAll(['-c:v', encoder ?? 'libvpx-vp9']);
    }

    if (noAudio) {
      args.add('-an');
    }

    if (outputExtension == 'mp4') {
      args.addAll(['-movflags', '+faststart']);
    }

    args.add(outputPath);
    return args;
  }

  /// Picks a video encoder for re-encoding: `libx264` when available in the
  /// ffmpeg build, otherwise `libvpx-vp9`.
  Future<String> resolveEncoder() async {
    if (_hasLibx264 != null) {
      return _hasLibx264! ? 'libx264' : 'libvpx-vp9';
    }
    var has = false;
    try {
      final process = await Process.start(executable, ['-encoders']);
      final encoders = await utf8.decodeStream(process.stdout);
      await process.exitCode;
      has = encoders.contains('libx264 V.') ||
          RegExp(r'\blibx264\b').hasMatch(encoders);
    } catch (_) {
      has = false;
    }
    _hasLibx264 = has;
    return has ? 'libx264' : 'libvpx-vp9';
  }

  /// Starts the ffmpeg trim subprocess. Callers receive a handle that can be
  /// used to cancel (kill) the process and to await the final result.
  Future<FfmpegProcess> start({
    required String inputPath,
    required String outputPath,
    required String start,
    required String end,
    required bool reencode,
    required bool noAudio,
  }) async {
    String? encoder;
    final outputExtension = extensionOf(outputPath);
    if (reencode && (outputExtension == 'mp4' || outputExtension == 'mkv')) {
      encoder = await resolveEncoder();
    }

    final args = buildTrimArgs(
      inputPath: inputPath,
      outputPath: outputPath,
      start: start,
      end: end,
      reencode: reencode,
      noAudio: noAudio,
      encoder: encoder,
    );

    final process = await Process.start(executable, args);
    final stderrFuture = utf8.decodeStream(process.stderr);
    final exitCodeFuture = process.exitCode;
    return FfmpegProcess._(process, exitCodeFuture, stderrFuture);
  }
}

/// A running ffmpeg subprocess.
class FfmpegProcess {
  FfmpegProcess._(this._process, this._exitCodeFuture, this._stderrFuture);

  final Process _process;
  final Future<int> _exitCodeFuture;
  final Future<String> _stderrFuture;

  /// Kills the subprocess (used by the cancel button).
  Future<void> cancel() async {
    _process.kill();
  }

  /// The exit code and stderr output once the process has finished.
  Future<FfmpegResult> get result async {
    final exitCode = await _exitCodeFuture;
    final stderr = await _stderrFuture;
    return FfmpegResult(exitCode: exitCode, stderr: stderr);
  }
}

class FfmpegResult {
  const FfmpegResult({required this.exitCode, required this.stderr});

  final int exitCode;
  final String stderr;

  bool get succeeded => exitCode == 0;
}
