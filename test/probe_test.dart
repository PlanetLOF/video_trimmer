import 'package:flutter_test/flutter_test.dart';
import 'package:video_trimmer/src/probe.dart';

void main() {
  group('hasPcmAudio', () {
    test('detects PCM audio streams', () {
      final json = {
        'streams': [
          {
            'codec_type': 'video',
            'codec_name': 'h264',
            'r_frame_rate': '30000/1001',
          },
          {'codec_type': 'audio', 'codec_name': 'pcm_s16le'},
        ],
      };
      expect(Probe.hasPcmAudio(json), isTrue);
    });

    test('does not flag non-PCM audio', () {
      final json = {
        'streams': [
          {'codec_type': 'audio', 'codec_name': 'aac'},
        ],
      };
      expect(Probe.hasPcmAudio(json), isFalse);
    });

    test('returns false for missing streams', () {
      expect(Probe.hasPcmAudio(null), isFalse);
      expect(Probe.hasPcmAudio({}), isFalse);
    });
  });

  group('frameTimeFromJson', () {
    test('computes frame time from r_frame_rate', () {
      final json = {
        'streams': [
          {
            'codec_type': 'video',
            'codec_name': 'h264',
            'r_frame_rate': '30000/1001',
          },
        ],
      };
      final frameTime = Probe.frameTimeFromJson(json);
      expect(frameTime, isNotNull);
      // 1001/30000 s in microseconds.
      expect(frameTime!.inMicroseconds, (1001 / 30000 * 1e6).round());
    });

    test('uses only the first video stream', () {
      final json = {
        'streams': [
          {'codec_type': 'video', 'r_frame_rate': '0/0'},
          {'codec_type': 'video', 'r_frame_rate': '25/1'},
        ],
      };
      expect(Probe.frameTimeFromJson(json), isNull);
    });

    test('returns null without a video stream or frame rate', () {
      expect(Probe.frameTimeFromJson({'streams': []}), isNull);
      expect(
        Probe.frameTimeFromJson({
          'streams': [
            {'codec_type': 'audio', 'r_frame_rate': '1/1'},
          ],
        }),
        isNull,
      );
      expect(
        Probe.frameTimeFromJson({
          'streams': [
            {'codec_type': 'video'},
          ],
        }),
        isNull,
      );
    });
  });
}