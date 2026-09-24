import 'package:flutter_test/flutter_test.dart';
import 'package:video_trimmer/util/timecode.dart';

void main() {
  group('timestamp', () {
    test('parses valid timestamps', () {
      expect(timestamp('1'), 1000);
      expect(timestamp('1:23:45.678'), 5025678);
      expect(timestamp('2.43'), 2430);
      expect(timestamp('2:03'), 123000);
      expect(timestamp('99:00:00'), 356400000);
    });

    test('rejects invalid timestamps', () {
      expect(timestamp('1.'), isNull);
      expect(timestamp('60'), isNull);
      expect(timestamp(':3'), isNull);
      expect(timestamp('2:'), isNull);
      expect(timestamp('2:3'), isNull);
      expect(timestamp('100:00:00'), isNull);
      expect(timestamp('1:02:03:04'), isNull);
      expect(timestamp('1.2.3'), isNull);
      expect(timestamp('1.2345'), isNull);
      expect(timestamp(''), isNull);
    });
  });

  group('timeToEntryText', () {
    test('formats durations rounded to tenths', () {
      expect(timeToEntryText(const Duration(milliseconds: 1234)), '0:01.2');
      expect(timeToEntryText(const Duration(milliseconds: 2000)), '0:02.0');
      expect(timeToEntryText(const Duration(milliseconds: 67890)), '1:07.9');
      expect(timeToEntryText(const Duration(milliseconds: 3600000)), '1:00:00.0');
    });
  });

  group('timeForFilename', () {
    test('strips trailing fractional zeros', () {
      expect(timeForFilename('0:32.0'), '0:32');
      expect(timeForFilename('1:05.300'), '1:05.3');
      expect(timeForFilename('1:05.2'), '1:05.2');
      expect(timeForFilename('1:05'), '1:05');
      expect(timeForFilename('1:00:00.000'), '1:00:00');
      expect(timeForFilename('10:00.0'), '10:00');
      expect(timeForFilename('0:00.0'), '0:00');
    });
  });
}