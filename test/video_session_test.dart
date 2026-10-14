import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:video_trimmer/common/video_session.dart';
import 'package:video_trimmer/util/probe.dart';

/// Records what the session asked the player to do, so the selection logic
/// can be exercised without a video backend.
class _FakeDriver implements PlayerDriver {
  final List<Playable> opened = [];
  final List<Duration> seeks = [];
  final List<int> pauses = [];
  final List<int> plays = [];

  /// When set, the next [open] throws, the way a player refuses a file it
  /// cannot read.
  bool failNextOpen = false;

  @override
  Future<void> open(Playable playable, {bool play = true}) async {
    if (failNextOpen) {
      failNextOpen = false;
      throw StateError('cannot open $playable');
    }
    opened.add(playable);
  }

  @override
  Future<void> pause() async => pauses.add(1);

  @override
  Future<void> play() async => plays.add(1);

  @override
  Future<void> seek(Duration position) async => seeks.add(position);
}

/// A probe whose runs stay pending until the test resolves them, so a result
/// can be delivered after another file has been opened.
class _FakeProbe extends Probe {
  final List<Completer<ProbeResult>> _runs = [];

  int get runCount => _runs.length;

  @override
  Future<ProbeResult> run(String path) {
    final completer = Completer<ProbeResult>();
    _runs.add(completer);
    return completer.future;
  }

  /// Delivers [result] to the [index]th run and lets [VideoSession] react.
  Future<void> resolve(int index, ProbeResult result) async {
    _runs[index].complete(result);
    await pumpEventQueue();
  }
}

const _pcm = ProbeResult(
  hasPcmAudio: true,
  frameTime: Duration(milliseconds: 41),
);
const _aac = ProbeResult(
  hasPcmAudio: false,
  frameTime: Duration(milliseconds: 25),
);

void main() {
  group('open', () {
    test(
      'resets the selection, the playback state and the error flag',
      () async {
        final probe = _FakeProbe();
        final driver = _FakeDriver();
        final session = VideoSession(
          initOnConstruct: false,
          probe: probe,
          driver: driver,
        );
        addTearDown(session.dispose);

        // Dirty everything open() is meant to clear.
        await session.open('dirty.mp4');
        await probe.resolve(0, _pcm);
        expect(session.doNotDefaultToMp4, isTrue);

        session.setStartText('0:04.0');
        session.setEndText('0:02.0');
        session.setRemoveAudio(true);
        await session.seek(const Duration(seconds: 3));

        driver.failNextOpen = true;
        await session.open('broken.mp4');
        expect(session.hasError, isTrue);
        expect(session.startText, isNull);
        expect(session.position, Duration.zero);

        await session.open('a.mp4');
        expect(session.startText, isNull);
        expect(session.endText, isNull);
        expect(session.position, Duration.zero);
        expect(session.duration, Duration.zero);
        expect(session.doNotDefaultToMp4, isFalse);
        expect(session.hasError, isFalse);
        expect(session.loading, isTrue);
        expect(session.isOpen, isTrue);
        expect(session.inputPath, 'a.mp4');
        expect(session.displayName, 'a.mp4');
        expect(driver.opened, hasLength(2));
        expect((driver.opened.last as Media).uri.toString(), contains('a.mp4'));
      },
    );

    test('bumps fileId for every file', () async {
      final session = VideoSession(
        initOnConstruct: false,
        probe: _FakeProbe(),
        driver: _FakeDriver(),
      );
      addTearDown(session.dispose);

      expect(session.fileId, 0);
      await session.open('a.mp4');
      expect(session.fileId, 1);
      await session.open('b.mp4');
      expect(session.fileId, 2);
    });

    test('leaves the error flags until the next duration arrives', () async {
      final session = VideoSession(
        initOnConstruct: false,
        probe: _FakeProbe(),
        driver: _FakeDriver(),
      );
      addTearDown(session.dispose);

      session.setStartText('0:04.0');
      session.setEndText('0:02.0');
      expect(session.endError, isTrue);

      await session.open('a.mp4');
      // The entry text is cleared, but nothing revalidates until the player
      // reports a duration, which is when _applyDefaultEntries runs.
      expect(session.endText, isNull);
      expect(session.endError, isTrue);
    });
  });

  group('probe', () {
    test('applies the result for the file that is open', () async {
      final probe = _FakeProbe();
      final session = VideoSession(
        initOnConstruct: false,
        probe: probe,
        driver: _FakeDriver(),
      );
      addTearDown(session.dispose);

      await session.open('a.mp4');
      expect(probe.runCount, 1);
      expect(session.frameTime, isNull);

      await probe.resolve(0, _pcm);
      expect(session.doNotDefaultToMp4, isTrue);
      expect(session.frameTime, const Duration(milliseconds: 41));
    });

    test('ignores a result for a file that was replaced', () async {
      final probe = _FakeProbe();
      final session = VideoSession(
        initOnConstruct: false,
        probe: probe,
        driver: _FakeDriver(),
      );
      addTearDown(session.dispose);

      await session.open('a.mp4');
      await session.open('b.mp4');
      expect(probe.runCount, 2);

      await probe.resolve(0, _pcm);
      expect(session.doNotDefaultToMp4, isFalse);
      expect(session.frameTime, isNull);

      await probe.resolve(1, _aac);
      expect(session.doNotDefaultToMp4, isFalse);
      expect(session.frameTime, const Duration(milliseconds: 25));
    });
  });

  group('setStartAsPosition and setEndAsPosition', () {
    test('take the current position', () async {
      final session = VideoSession(
        initOnConstruct: false,
        probe: _FakeProbe(),
        driver: _FakeDriver(),
      );
      addTearDown(session.dispose);

      session.seek(const Duration(seconds: 3, milliseconds: 400));

      session.setStartAsPosition();
      expect(session.startText, '0:03.4');
      expect(session.startMs, 3400);

      session.seek(const Duration(minutes: 1, milliseconds: 240));
      session.setEndAsPosition();
      expect(session.endText, '1:00.2');
      expect(session.endMs, 60200);
    });
  });

  group('step', () {
    test('does nothing without a frame time', () async {
      final driver = _FakeDriver();
      final session = VideoSession(
        initOnConstruct: false,
        probe: _FakeProbe(),
        driver: driver,
      );
      addTearDown(session.dispose);

      await session.open('a.mp4');
      await session.stepForward();

      expect(session.position, Duration.zero);
      expect(driver.seeks, isEmpty);
    });

    test('does nothing without a player', () async {
      final probe = _FakeProbe();
      final session = VideoSession(initOnConstruct: false, probe: probe);
      addTearDown(session.dispose);

      await session.open('a.mp4');
      await probe.resolve(0, _pcm);
      expect(session.frameTime, const Duration(milliseconds: 41));

      await session.stepForward();
      expect(session.position, Duration.zero);
    });

    test('moves by a frame in each direction', () async {
      final probe = _FakeProbe();
      final driver = _FakeDriver();
      final session = VideoSession(
        initOnConstruct: false,
        probe: probe,
        driver: driver,
      );
      addTearDown(session.dispose);

      await session.open('a.mp4');
      await probe.resolve(0, _pcm);
      session.seek(const Duration(seconds: 1));
      driver.seeks.clear();

      await session.stepForward();
      expect(session.position, const Duration(milliseconds: 1041));
      await session.stepBack();
      expect(session.position, const Duration(seconds: 1));
      expect(driver.seeks, [
        const Duration(milliseconds: 1041),
        const Duration(seconds: 1),
      ]);
    });

    test('clamps to the start of the video', () async {
      final probe = _FakeProbe();
      final driver = _FakeDriver();
      final session = VideoSession(
        initOnConstruct: false,
        probe: probe,
        driver: driver,
      );
      addTearDown(session.dispose);

      await session.open('a.mp4');
      await probe.resolve(0, _pcm);
      session.seek(const Duration(milliseconds: 10));
      driver.seeks.clear();

      await session.stepBack();
      expect(session.position, Duration.zero);
      expect(driver.seeks, [Duration.zero]);
    });
  });

  group('trimming flags', () {
    test('notify only when the value changes', () {
      final session = VideoSession(
        initOnConstruct: false,
        probe: _FakeProbe(),
        driver: _FakeDriver(),
      );
      addTearDown(session.dispose);

      var notifications = 0;
      session.addListener(() => notifications++);

      session.setPrecise(true);
      expect(notifications, 1);
      session.setPrecise(true);
      expect(notifications, 1);
      session.setPrecise(false);
      expect(notifications, 2);

      session.setRemoveAudio(true);
      expect(notifications, 3);
      session.setRemoveAudio(true);
      expect(notifications, 3);

      expect(session.precise, isFalse);
      expect(session.removeAudio, isTrue);
    });
  });
}
