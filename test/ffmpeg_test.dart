import 'package:flutter_test/flutter_test.dart';
import 'package:video_trimmer/util/ffmpeg.dart';

void main() {
  group('buildTrimArgs', () {
    test('common base arguments always present', () {
      final args = Ffmpeg.buildTrimArgs(
        inputPath: r'C:\input.mp4',
        outputPath: r'C:\output.mp4',
        start: '0:32.0',
        end: '1:06.5',
        reencode: false,
        noAudio: false,
      );
      expect(args.take(16), [
        '-loglevel',
        'error',
        '-ss',
        '0:32.0',
        '-to',
        '1:06.5',
        '-i',
        r'C:\input.mp4',
        '-map',
        '0',
        '-dn',
        '-avoid_negative_ts',
        'make_zero',
        '-y',
        '-c',
        'copy',
      ]);
    });

    test('copy mode and mp4 faststart', () {
      final args = Ffmpeg.buildTrimArgs(
        inputPath: r'C:\input.mp4',
        outputPath: r'C:\output.mp4',
        start: '0:00.0',
        end: '0:10.0',
        reencode: false,
        noAudio: false,
      );
      expect(args.contains('-c'), isTrue);
      expect(args.indexOf('-c') + 1, args.indexOf('copy'));
      expect(args[args.length - 3], '-movflags');
      expect(args[args.length - 2], '+faststart');
      expect(args.last, r'C:\output.mp4');
    });

    test('re-encode selects libx264 for mp4 when provided', () {
      final args = Ffmpeg.buildTrimArgs(
        inputPath: '/tmp/in.mp4',
        outputPath: '/tmp/out.mp4',
        start: '0:00.0',
        end: '0:10.0',
        reencode: true,
        noAudio: false,
        encoder: 'libx264',
      );
      expect(args.contains('-c'), isFalse);
      final i = args.indexOf('-c:v');
      expect(i, isNot(-1));
      expect(args[i + 1], 'libx264');
      expect(args.contains('+faststart'), isTrue);
    });

    test('re-encode falls back to libvpx-vp9 for mkv', () {
      final args = Ffmpeg.buildTrimArgs(
        inputPath: '/tmp/in.mkv',
        outputPath: '/tmp/out.mkv',
        start: '0:00.0',
        end: '0:10.0',
        reencode: true,
        noAudio: false,
        encoder: 'libvpx-vp9',
      );
      final i = args.indexOf('-c:v');
      expect(args[i + 1], 'libvpx-vp9');
      expect(args.contains('+faststart'), isFalse);
    });

    test('re-encode without a known extension uses no encoder', () {
      final args = Ffmpeg.buildTrimArgs(
        inputPath: '/tmp/in.mov',
        outputPath: '/tmp/out.mov',
        start: '0:00.0',
        end: '0:10.0',
        reencode: true,
        noAudio: false,
      );
      expect(args.contains('-c:v'), isFalse);
      expect(args.contains('-c'), isFalse);
    });

    test('noAudio adds -an', () {
      final args = Ffmpeg.buildTrimArgs(
        inputPath: '/tmp/in.mp4',
        outputPath: '/tmp/out.mp4',
        start: '0:00.0',
        end: '0:10.0',
        reencode: false,
        noAudio: true,
      );
      expect(args.contains('-an'), isTrue);
      expect(args.contains('-c'), isTrue);
    });

    test('full re-encode + no audio + mp4 ordering', () {
      final args = Ffmpeg.buildTrimArgs(
        inputPath: '/tmp/in.mp4',
        outputPath: '/tmp/out.mp4',
        start: '0:00.0',
        end: '0:10.0',
        reencode: true,
        noAudio: true,
        encoder: 'libx264',
      );
      expect(args, [
        '-loglevel',
        'error',
        '-ss',
        '0:00.0',
        '-to',
        '0:10.0',
        '-i',
        '/tmp/in.mp4',
        '-map',
        '0',
        '-dn',
        '-avoid_negative_ts',
        'make_zero',
        '-y',
        '-c:v',
        'libx264',
        '-an',
        '-movflags',
        '+faststart',
        '/tmp/out.mp4',
      ]);
    });
  });

  group('extensionOf', () {
    test('lowercases and extracts extension', () {
      expect(Ffmpeg.extensionOf(r'C:\foo\MY VIDEO.MKV'), 'mkv');
      expect(Ffmpeg.extensionOf('/tmp/video'), '');
    });
  });
}