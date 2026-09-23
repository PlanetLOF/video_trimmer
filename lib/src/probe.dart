import 'dart:convert';
import 'dart:io';

/// ffprobe wrapper and JSON parsing, ported from the original Rust
/// `window.rs` logic.
class ProbeResult {
  const ProbeResult({required this.hasPcmAudio, this.frameTime});

  /// True when any audio stream uses a PCM codec (invalid in MP4 containers,
  /// so the default output extension must be switched away from `.mp4`).
  final bool hasPcmAudio;

  /// Approximate time of a single video frame, derived from the
  /// `r_frame_rate` of the first video stream.
  final Duration? frameTime;
}

class Probe {
  Probe({this.executable = 'ffprobe'});

  final String executable;

  static bool hasPcmAudio(Object? json) {
    final streams = _streams(json);
    for (final stream in streams) {
      if (stream['codec_type'] == 'audio') {
        final name = stream['codec_name'];
        if (name is String && name.startsWith('pcm_')) {
          return true;
        }
      }
    }
    return false;
  }

  static Duration? frameTimeFromJson(Object? json) {
    for (final stream in _streams(json)) {
      if (stream['codec_type'] != 'video') {
        continue;
      }
      final rate = stream['r_frame_rate'];
      if (rate is! String) {
        return null;
      }
      final parts = rate.split('/');
      if (parts.length != 2) {
        return null;
      }
      final numerator = double.tryParse(parts[0]);
      final denominator = double.tryParse(parts[1]);
      if (numerator == null ||
          denominator == null ||
          numerator <= 0 ||
          denominator <= 0) {
        return null;
      }
      return Duration(
        microseconds: (denominator / numerator * 1e6).round(),
      );
    }
    return null;
  }

  static Iterable<Map<String, dynamic>> _streams(Object? json) sync* {
    if (json is! Map) {
      return;
    }
    final streams = json['streams'];
    if (streams is! List) {
      return;
    }
    for (final stream in streams) {
      if (stream is Map) {
        yield Map<String, dynamic>.from(stream);
      }
    }
  }

  /// Runs ffprobe on [path]. Returns an empty result when probing fails.
  Future<ProbeResult> run(String path) async {
    final args = ['-print_format', 'json', '-show_streams', path];
    Process process;
    try {
      process = await Process.start(executable, args);
    } catch (_) {
      return const ProbeResult(hasPcmAudio: false);
    }
    final output = StringBuffer();
    await for (final line
        in process.stdout.transform(utf8.decoder).transform(const LineSplitter())) {
      output.writeln(line);
    }
    final exitCode = await process.exitCode;
    if (exitCode != 0) {
      return const ProbeResult(hasPcmAudio: false);
    }
    try {
      final json = jsonDecode(output.toString());
      return ProbeResult(
        hasPcmAudio: hasPcmAudio(json),
        frameTime: frameTimeFromJson(json),
      );
    } catch (_) {
      return const ProbeResult(hasPcmAudio: false);
    }
  }
}