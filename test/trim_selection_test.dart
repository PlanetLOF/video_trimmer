import 'package:flutter_test/flutter_test.dart';
import 'package:video_trimmer/common/trim_selection.dart';

const _nineSeconds = Duration(seconds: 9);

void main() {
  group('applyDefaultEntries', () {
    test('fills both entries with the middle third of the video', () {
      final trim = TrimSelection();

      trim.applyDefaultEntries(_nineSeconds);

      expect(trim.startText, '0:03.0');
      expect(trim.endText, '0:06.0');
      expect(trim.startMs, 3000);
      expect(trim.endMs, 6000);
      expect(trim.selection, (3000, 6000));
      expect(trim.selectionValid, isTrue);
      expect(trim.startError, isFalse);
      expect(trim.endError, isFalse);
    });

    test('does nothing before a duration is known', () {
      final trim = TrimSelection();

      trim.applyDefaultEntries(Duration.zero);

      expect(trim.startText, isNull);
      expect(trim.endText, isNull);
      expect(trim.selection, isNull);
    });

    test('keeps a start that is already set and ends on the video', () {
      final trim = TrimSelection()..setStartText('0:01.0');

      trim.applyDefaultEntries(_nineSeconds);

      expect(trim.startText, '0:01.0');
      expect(trim.endText, '0:09.0');
      expect(trim.selection, (1000, 9000));
    });

    test('keeps an end that is already set and starts at zero', () {
      final trim = TrimSelection()..setEndText('0:08.0');

      trim.applyDefaultEntries(_nineSeconds);

      expect(trim.startText, '0:00.0');
      expect(trim.endText, '0:08.0');
      expect(trim.selection, (0, 8000));
    });

    test('leaves both entries alone once both are set', () {
      final trim = TrimSelection()
        ..setStartText('0:01.0')
        ..setEndText('0:02.0');

      trim.applyDefaultEntries(_nineSeconds);

      expect(trim.selection, (1000, 2000));
    });
  });

  group('validation', () {
    test('rejects text that is not a timestamp', () {
      final trim = TrimSelection()
        ..setStartText('not a time')
        ..setEndText('0:05.0');

      expect(trim.startMs, isNull);
      expect(trim.startError, isTrue);
      expect(trim.endError, isFalse);
      expect(trim.selectionValid, isFalse);
      expect(trim.selection, isNull);
    });

    test('rejects a range that does not go forward', () {
      final trim = TrimSelection()
        ..setStartText('0:05.0')
        ..setEndText('0:05.0');

      expect(trim.endError, isTrue);
      expect(trim.startError, isFalse);
      expect(trim.selection, isNull);

      trim.setStartText('0:06.0');
      expect(trim.endError, isTrue);
      expect(trim.selectionValid, isFalse);
    });

    test('clears the error once the text parses', () {
      final trim = TrimSelection()..setStartText('not a time');
      expect(trim.startError, isTrue);

      trim.setStartText('0:01.0');
      expect(trim.startError, isFalse);
      expect(trim.startMs, 1000);
    });

    test('an empty entry marks both sides as errors', () {
      final trim = TrimSelection();
      expect(trim.startError, isFalse);
      expect(trim.endError, isFalse);

      trim.setStartText('');
      expect(trim.startError, isTrue);
      expect(trim.endError, isTrue);
    });
  });

  group('updateStartMs and updateEndMs', () {
    test('write the entry text the millisecond value renders as', () {
      final trim = TrimSelection();

      trim.updateStartMs(1234);
      trim.updateEndMs(60000);

      expect(trim.startText, '0:01.2');
      expect(trim.endText, '1:00.0');
      expect(trim.selection, (1200, 60000));
    });
  });

  group('reset', () {
    test('clears the entries, which then default again for the new file', () {
      final trim = TrimSelection();
      trim.applyDefaultEntries(_nineSeconds);

      trim.reset();
      expect(trim.startText, isNull);
      expect(trim.endText, isNull);
      // Still the parsed values of the previous file until the next duration
      // arrives and refills them.
      expect(trim.startMs, 3000);
      expect(trim.endMs, 6000);

      trim.applyDefaultEntries(_nineSeconds);
      expect(trim.selection, (3000, 6000));
    });

    test('leaves the error flags alone for the same reason', () {
      final trim = TrimSelection()..setStartText('not a time');
      expect(trim.startError, isTrue);

      trim.reset();
      expect(trim.startError, isTrue);
    });
  });

  group('notifications', () {
    test('the setters notify once per real change', () {
      final trim = TrimSelection();
      var notified = 0;
      trim.addListener(() => notified++);
      addTearDown(trim.dispose);

      trim.setStartText('0:01.0');
      expect(notified, 1);
      trim.setStartText('0:01.0');
      expect(notified, 1);

      trim.setEndText('0:02.0');
      expect(notified, 2);

      trim.updateStartMs(5000);
      expect(notified, 3);
      trim.updateEndMs(7000);
      expect(notified, 4);
    });

    test('reset and the defaults stay silent for the caller to notify', () {
      final trim = TrimSelection();
      var notified = 0;
      trim.addListener(() => notified++);
      addTearDown(trim.dispose);

      trim.reset();
      trim.applyDefaultEntries(_nineSeconds);

      expect(notified, 0);
    });
  });
}
