import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../util/timecode.dart';
import '../common/typography.dart';
import '../common/video_session.dart';

const _tolerance = 8.0;
const _trackHeight = 74.0;

enum _DragType { scrub, start, end }

/// Which edge of the selection the pointer is holding. The two edges swap
/// rather than cross, so an edge that walks into the other one hands the
/// pointer over instead of the pointer losing the edge it grabbed.
enum HandleKind { start, end }

/// The selection one drag move leaves behind, and the handle the drag stays
/// attached to, which is the other one once they have swapped.
typedef HandleDrag = ({int start, int end, HandleKind handle});

/// What one drag move on the timeline resolves to: where playback should sit,
/// and the selection to write when a handle is under the pointer.
///
/// Returns null when the timeline has no duration to map the pointer onto.
/// A pointer that is not on a handle only seeks, which is what makes a scrub
/// leave the selection alone.
({int positionUs, HandleDrag? drag})? dragMove({
  required Duration duration,
  required double fraction,
  required (int, int)? selection,
  required HandleKind? handle,
}) {
  if (duration == Duration.zero) {
    return null;
  }
  final positionUs = (duration.inMicroseconds * fraction).round();
  if (selection == null || handle == null) {
    return (positionUs: positionUs, drag: null);
  }
  // The playhead keeps microsecond precision; only the selection snaps to the
  // resolution the entry fields show.
  return (
    positionUs: positionUs,
    drag: _dragHandle(selection, handle, roundToTenthMs(positionUs ~/ 1000)),
  );
}

/// Moves [handle] to [ms] while it stays on its own side of the other one,
/// swaps the two when it crosses, and returns null when [ms] lands exactly on
/// the other handle: the selection has to keep a start before an end, and a
/// collapsed one has nowhere to put a pointer.
HandleDrag? _dragHandle((int, int) selection, HandleKind handle, int ms) {
  final (currentStart, currentEnd) = selection;
  return switch (handle) {
    HandleKind.start when ms == currentEnd => null,
    HandleKind.start when ms > currentEnd => (
      start: currentEnd,
      end: ms,
      handle: HandleKind.end,
    ),
    HandleKind.start => (start: ms, end: currentEnd, handle: HandleKind.start),
    HandleKind.end when ms == currentStart => null,
    HandleKind.end when ms < currentStart => (
      start: ms,
      end: currentStart,
      handle: HandleKind.start,
    ),
    HandleKind.end => (start: currentStart, end: ms, handle: HandleKind.end),
  };
}

class Timeline extends StatefulWidget {
  const Timeline({super.key, required this.session});

  final VideoSession session;

  @override
  State<Timeline> createState() => _TimelineState();
}

class _TimelineState extends State<Timeline> {
  _DragType _dragType = _DragType.scrub;
  double _hoverX = 0;

  VideoSession get session => widget.session;

  double _xForMs(int ms, double width) {
    final durationMs = session.duration.inMilliseconds;
    if (durationMs <= 0) {
      return 0;
    }
    final fraction = (ms / durationMs).clamp(0.0, 1.0).toDouble();
    return fraction * width;
  }

  HandleKind? _handleAt(double x, double width) {
    if (width <= 0) {
      return null;
    }
    final selection = session.selection;
    if (selection == null) {
      return null;
    }
    final (start, end) = selection;
    final xStart = _xForMs(start, width);
    final xEnd = _xForMs(end, width);
    if ((x - xEnd).abs() <= _tolerance) {
      return HandleKind.end;
    }
    if ((x - xStart).abs() <= _tolerance) {
      return HandleKind.start;
    }
    return null;
  }

  HandleKind? get _activeHandle => switch (_dragType) {
    _DragType.start => HandleKind.start,
    _DragType.end => HandleKind.end,
    _DragType.scrub => null,
  };

  void _onDragStart(double x, double width) {
    _dragType = switch (_handleAt(x, width)) {
      HandleKind.start => _DragType.start,
      HandleKind.end => _DragType.end,
      null => _DragType.scrub,
    };
    setState(() {});

    _onDragUpdate(x, width);
  }

  void _onDragEnd() {
    setState(() => _dragType = _DragType.scrub);
  }

  void _onDragUpdate(double x, double width) {
    final selection = session.selection;
    final move = dragMove(
      duration: session.duration,
      fraction: x.clamp(0.0, width) / width,
      selection: selection,
      handle: _activeHandle,
    );
    if (move == null) {
      return;
    }
    unawaited(session.seek(Duration(microseconds: move.positionUs)));

    final drag = move.drag;
    if (drag == null || selection == null) {
      return;
    }
    // A swap hands the drag to the handle that took the pointer's value, so
    // the edge under the pointer keeps being the edge under the pointer.
    _dragType = switch (drag.handle) {
      HandleKind.start => _DragType.start,
      HandleKind.end => _DragType.end,
    };
    final (start, end) = selection;
    if (drag.start != start) {
      session.updateStartMs(drag.start);
    }
    if (drag.end != end) {
      session.updateEndMs(drag.end);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 26, right: 26, top: 0, bottom: 2),
      child: SizedBox(
        height: _trackHeight,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final hovered = _handleAt(_hoverX, width);
            final active = _activeHandle;
            return TweenAnimationBuilder<double>(
              tween: Tween<double>(
                end: hovered != null || active != null ? 1 : 0,
              ),
              duration: const Duration(milliseconds: 140),
              curve: Curves.easeOut,
              builder: (context, focus, _) => MouseRegion(
                cursor: hovered != null
                    ? SystemMouseCursors.resizeLeftRight
                    : SystemMouseCursors.basic,
                onHover: (event) =>
                    setState(() => _hoverX = event.localPosition.dx),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanStart: (details) =>
                      _onDragStart(details.localPosition.dx, width),
                  onPanUpdate: (details) =>
                      _onDragUpdate(details.localPosition.dx, width),
                  onPanEnd: (_) => _onDragEnd(),
                  onPanCancel: _onDragEnd,
                  child: CustomPaint(
                    size: Size(width, _trackHeight),
                    painter: _TimelinePainter(
                      durationMs: session.duration.inMilliseconds,
                      positionMs: session.position.inMilliseconds,
                      selection: session.selection,
                      colorScheme: Theme.of(context).colorScheme,
                      hovered: hovered,
                      active: active,
                      focus: focus,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _TimelinePainter extends CustomPainter {
  _TimelinePainter({
    required this.durationMs,
    required this.positionMs,
    required this.selection,
    required this.colorScheme,
    required this.hovered,
    required this.active,
    required this.focus,
  });

  static const _bandTop = 8.0;
  static const _bandHeight = 44.0;
  static const _bandBottom = _bandTop + _bandHeight;
  static const _labelBaseline = _trackHeight - 2;
  static const _handleHalfWidth = 6.0;
  static const _handleGrow = 1.5;
  static const _handleRadius = 5.0;
  static const _dotRadius = 1.2;
  static const _dotColumns = 2;
  static const _dotRows = 3;
  static const _dotRowSpacing = 8.0;
  static const _playheadHalfHeight = 13.0;
  static const _selectionBorderWidth = 1.0;

  final int durationMs;
  final int positionMs;
  final (int, int)? selection;
  final ColorScheme colorScheme;
  final HandleKind? hovered;
  final HandleKind? active;
  final double focus;

  @override
  void paint(Canvas canvas, Size size) {
    final trackY = _bandTop + _bandHeight / 2;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(0, _bandTop, size.width, _bandBottom),
        const Radius.circular(6),
      ),
      Paint()..color = colorScheme.surfaceContainerHighest,
    );

    if (durationMs <= 0) {
      return;
    }

    double xForMs(int ms) {
      final fraction = (ms / durationMs).clamp(0.0, 1.0);
      return fraction * size.width;
    }

    // Subtle tick marks to keep the track scannable.
    final tickPaint = Paint()
      ..color = colorScheme.outline.withValues(alpha: 0.35)
      ..strokeWidth = 1;
    const tickCount = 48;
    for (var i = 1; i < tickCount; i++) {
      final x = size.width * i / tickCount;
      canvas.drawLine(
        Offset(x, _bandTop + 3),
        Offset(x, _bandTop + 6),
        tickPaint,
      );
      canvas.drawLine(
        Offset(x, _bandBottom - 6),
        Offset(x, _bandBottom - 3),
        tickPaint,
      );
    }

    final sel = selection;
    ({int startMs, int endMs, double xStart, double xEnd})? band;
    if (sel != null) {
      final (start, end) = sel;
      final xStart = xForMs(start).clamp(0.0, size.width);
      final xEnd = xForMs(end).clamp(0.0, size.width);
      if (xEnd > xStart) {
        band = (startMs: start, endMs: end, xStart: xStart, xEnd: xEnd);
      }
    }

    if (band != null) {
      final selectionRect = RRect.fromRectAndRadius(
        Rect.fromLTRB(band.xStart, _bandTop, band.xEnd, _bandBottom),
        const Radius.circular(5),
      );
      canvas.drawRRect(
        selectionRect,
        Paint()..color = colorScheme.primary.withValues(alpha: 0.38),
      );
      canvas.drawRRect(
        selectionRect.deflate(_selectionBorderWidth / 2),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = _selectionBorderWidth
          ..color = colorScheme.primary,
      );

      _drawLabel(
        canvas,
        size.width,
        timeToEntryText(Duration(milliseconds: band.startMs)),
        band.xStart,
      );
      _drawLabel(
        canvas,
        size.width,
        timeToEntryText(Duration(milliseconds: band.endMs)),
        band.xEnd,
      );
    }

    // Playhead.
    final xPosition = xForMs(positionMs).clamp(0.0, size.width);
    final playheadPaint = Paint()
      ..color = colorScheme.onSurface
      ..strokeWidth = 2;
    canvas.drawLine(
      Offset(xPosition, trackY - _playheadHalfHeight),
      Offset(xPosition, trackY + _playheadHalfHeight),
      playheadPaint,
    );

    if (band != null) {
      for (final kind in HandleKind.values) {
        _drawHandle(
          canvas,
          x: kind == HandleKind.start ? band.xStart : band.xEnd,
          kind: kind,
          emphasis: _emphasisFor(kind),
        );
      }
    }
  }

  double _emphasisFor(HandleKind kind) => switch ((active, hovered)) {
    (final a?, _) when a == kind => 1,
    (_, final h?) when h == kind => focus,
    _ => 0,
  };

  void _drawHandle(
    Canvas canvas, {
    required double x,
    required HandleKind kind,
    required double emphasis,
  }) {
    final half = _handleHalfWidth + _handleGrow * emphasis;
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTRB(x - half, _bandTop, x + half, _bandBottom),
      const Radius.circular(_handleRadius),
    );
    final path = Path()..addRRect(rrect);

    if (emphasis > 0) {
      canvas.drawShadow(path, const Color(0xFF000000), 1 + 2 * emphasis, true);
    }

    final primary = colorScheme.primary;
    final onPrimary = colorScheme.onPrimary;
    final gloss = 0.08 + 0.07 * emphasis;
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(primary, onPrimary, gloss)!,
            Color.lerp(primary, onPrimary, gloss * 0.5)!,
          ],
        ).createShader(rrect.outerRect),
    );

    final centerY = _bandTop + _bandHeight / 2;
    final dotPaint = Paint()
      ..color = onPrimary.withValues(alpha: 0.85 + 0.15 * emphasis);
    final columnSpacing = 2 * (half + _dotRadius) / (_dotColumns + 1);
    for (var row = 0; row < _dotRows; row++) {
      final y = centerY + (row - (_dotRows - 1) / 2) * _dotRowSpacing;
      for (var column = 0; column < _dotColumns; column++) {
        final bx = x + (column - (_dotColumns - 1) / 2) * columnSpacing;
        canvas.drawCircle(Offset(bx, y), _dotRadius, dotPaint);
      }
    }
  }

  void _drawLabel(Canvas canvas, double width, String text, double centerX) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: monoStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurface,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final maxX = width - painter.width - 2;
    final x = maxX < 2.0
        ? (width - painter.width) / 2
        : (centerX - painter.width / 2).clamp(2.0, maxX);
    final top = _labelBaseline - painter.height;

    final bg = RRect.fromRectAndRadius(
      Rect.fromLTWH(x - 3, top - 1, painter.width + 6, painter.height + 2),
      const Radius.circular(3),
    );
    canvas.drawRRect(
      bg,
      Paint()..color = colorScheme.surface.withValues(alpha: 0.85),
    );
    painter.paint(canvas, Offset(x, top));
  }

  @override
  bool shouldRepaint(_TimelinePainter oldDelegate) {
    return oldDelegate.durationMs != durationMs ||
        oldDelegate.positionMs != positionMs ||
        oldDelegate.selection != selection ||
        oldDelegate.colorScheme != colorScheme ||
        oldDelegate.hovered != hovered ||
        oldDelegate.active != active ||
        oldDelegate.focus != focus;
  }
}
