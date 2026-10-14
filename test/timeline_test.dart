import 'package:flutter_test/flutter_test.dart';
import 'package:video_trimmer/screen/timeline.dart';

void main() {
  group('dragMove', () {
    const duration = Duration(seconds: 10);
    const selection = (2000, 5000);

    test('dragging start past end swaps the handles', () {
      final move = dragMove(
        duration: duration,
        fraction: 0.9,
        selection: selection,
        handle: HandleKind.start,
      )!;
      expect(move.positionUs, 9000000);
      expect(move.drag, (start: 5000, end: 9000, handle: HandleKind.end));
    });

    test('dragging end before start swaps the handles', () {
      final move = dragMove(
        duration: duration,
        fraction: 0.1,
        selection: selection,
        handle: HandleKind.end,
      )!;
      expect(move.positionUs, 1000000);
      expect(move.drag, (start: 1000, end: 2000, handle: HandleKind.start));
    });

    test('dragging between the handles moves only the dragged one', () {
      final move = dragMove(
        duration: duration,
        fraction: 0.3,
        selection: selection,
        handle: HandleKind.start,
      )!;
      expect(move.drag, (start: 3000, end: 5000, handle: HandleKind.start));
    });

    test('dragging a handle onto the other one is ignored', () {
      final move = dragMove(
        duration: duration,
        fraction: 0.5,
        selection: selection,
        handle: HandleKind.start,
      )!;
      expect(move.positionUs, 5000000);
      expect(move.drag, isNull);
    });

    test('the handle snaps to tenths while the playhead does not', () {
      final move = dragMove(
        duration: duration,
        fraction: 0.9567,
        selection: selection,
        handle: HandleKind.end,
      )!;
      expect(move.positionUs, 9567000);
      expect(move.drag, (start: 2000, end: 9600, handle: HandleKind.end));
    });

    test('dragging empty track only seeks', () {
      final move = dragMove(
        duration: duration,
        fraction: 0.25,
        selection: selection,
        handle: null,
      )!;
      expect(move.positionUs, 2500000);
      expect(move.drag, isNull);
    });

    test('dragging without a selection only seeks', () {
      final move = dragMove(
        duration: duration,
        fraction: 0.25,
        selection: null,
        handle: HandleKind.start,
      )!;
      expect(move.positionUs, 2500000);
      expect(move.drag, isNull);
    });

    test('a timeline with no duration ignores the drag', () {
      expect(
        dragMove(
          duration: Duration.zero,
          fraction: 0.5,
          selection: selection,
          handle: HandleKind.start,
        ),
        isNull,
      );
    });
  });
}
