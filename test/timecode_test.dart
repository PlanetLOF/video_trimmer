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
      expect(
        timeToEntryText(const Duration(milliseconds: 3600000)),
        '1:00:00.0',
      );
    });
  });

  group('roundToTenthMs', () {
    test('rounds to the nearest tenth of a second', () {
      expect(roundToTenthMs(0), 0);
      expect(roundToTenthMs(49), 0);
      expect(roundToTenthMs(50), 100);
      expect(roundToTenthMs(149), 100);
      expect(roundToTenthMs(150), 200);
      expect(roundToTenthMs(999), 1000);
      expect(roundToTenthMs(1234), 1200);
      expect(roundToTenthMs(1235), 1200);
      expect(roundToTenthMs(9999), 10000);
      expect(roundToTenthMs(3600049), 3600000);
      expect(roundToTenthMs(3600050), 3600100);
    });

    test('agrees with the entry text it exists to match', () {
      for (final ms in [
        0,
        1,
        49,
        50,
        51,
        99,
        100,
        149,
        150,
        250,
        999,
        1000,
        1234,
        1235,
        9999,
        59999,
        60000,
        3599999,
        3600000,
        3600049,
        3600050,
        86399999,
      ]) {
        expect(
          timestamp(timeToEntryText(Duration(milliseconds: ms))),
          roundToTenthMs(ms),
          reason: 'at $ms ms',
        );
      }
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
