import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../util/timecode.dart';
import '../common/typography.dart';
import '../common/video_session.dart';

const _tolerance = 8.0;
const _trackHeight = 64.0;

enum _DragType { scrub, start, end }

enum _HandleKind { start, end }

/// A scrubber showing the full duration, the selected region with resize
/// handles, and the current playback position. Dragging near the handles
/// resizes the selection; dragging anywhere else seeks.
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

  _HandleKind? _handleAt(double x, double width) {
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
      return _HandleKind.end;
    }
    if ((x - xStart).abs() <= _tolerance) {
      return _HandleKind.start;
    }
    return null;
  }

  /// The edge being dragged, or null while scrubbing or idle.
  _HandleKind? get _activeHandle => switch (_dragType) {
    _DragType.start => _HandleKind.start,
    _DragType.end => _HandleKind.end,
    _DragType.scrub => null,
  };

  void _onDragStart(double x, double width) {
    _dragType = switch (_handleAt(x, width)) {
      _HandleKind.start => _DragType.start,
      _HandleKind.end => _DragType.end,
      null => _DragType.scrub,
    };
    setState(() {});

    _onDragUpdate(x, width);
  }

  void _onDragEnd() {
    setState(() => _dragType = _DragType.scrub);
  }

  void _onDragUpdate(double x, double width) {
    final xClamped = x.clamp(0.0, width);
    final value = xClamped / width;

    final durationUs = session.duration.inMicroseconds;
    if (durationUs == 0) {
      return;
    }

    final timeUs = (durationUs * value).round();
    unawaited(session.seek(Duration(microseconds: timeUs)));

    final selection = session.selection;
    if (selection == null) {
      return;
    }
    final (_, endMs) = selection;

    final ms = timeUs ~/ 1000;
    if (_dragType == _DragType.start) {
      final text = timeToEntryText(Duration(milliseconds: ms));
      final parsed = timestamp(text);
      if (parsed == null || parsed == endMs) {
        return;
      }
      if (parsed <= endMs) {
        session.updateStartMs(parsed);
      } else {
        _dragType = _DragType.end;
        final oldEnd = session.endMs!;
        session.updateStartMs(oldEnd);
        session.updateEndMs(parsed);
      }
    } else if (_dragType == _DragType.end) {
      final text = timeToEntryText(Duration(milliseconds: ms));
      final parsed = timestamp(text);
      if (parsed == null || parsed == session.startMs) {
        return;
      }
      if (parsed >= session.startMs!) {
        session.updateEndMs(parsed);
      } else {
        _dragType = _DragType.start;
        final oldStart = session.startMs!;
        session.updateEndMs(oldStart);
        session.updateStartMs(parsed);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 26, right: 26, top: 8, bottom: 4),
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
  static const _bandHeight = 34.0;
  static const _bandBottom = _bandTop + _bandHeight;
  static const _labelBaseline = _trackHeight - 2;
  static const _handleHalfWidth = 6.0;
  static const _handleGrow = 1.5;
  static const _handleOverhang = 4.0;
  static const _handleRadius = 5.0;

  final int durationMs;
  final int positionMs;
  final (int, int)? selection;
  final ColorScheme colorScheme;
  final _HandleKind? hovered;
  final _HandleKind? active;
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
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(band.xStart, _bandTop, band.xEnd, _bandBottom),
          const Radius.circular(5),
        ),
        Paint()..color = colorScheme.primary.withValues(alpha: 0.38),
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
      Offset(xPosition, trackY - 10),
      Offset(xPosition, trackY + 10),
      playheadPaint,
    );

    if (band != null) {
      for (final kind in _HandleKind.values) {
        _drawHandle(
          canvas,
          x: kind == _HandleKind.start ? band.xStart : band.xEnd,
          kind: kind,
          emphasis: _emphasisFor(kind),
        );
      }
    }
  }

  double _emphasisFor(_HandleKind kind) => switch ((active, hovered)) {
    (final a?, _) when a == kind => 1,
    (_, final h?) when h == kind => focus,
    _ => 0,
  };

  void _drawHandle(
    Canvas canvas, {
    required double x,
    required _HandleKind kind,
    required double emphasis,
  }) {
    final half = _handleHalfWidth + _handleGrow * emphasis;
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTRB(
        x - half,
        _bandTop - _handleOverhang,
        x + half,
        _bandBottom + _handleOverhang,
      ),
      const Radius.circular(_handleRadius),
    );
    final path = Path()..addRRect(rrect);

    if (emphasis > 0) {
      canvas.drawShadow(path, const Color(0xFF000000), 1 + 2 * emphasis, true);
    }

    final primary = colorScheme.primary;
    final onPrimary = colorScheme.onPrimary;
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(primary, onPrimary, 0.06)!,
            Color.lerp(primary, onPrimary, 0.15 * emphasis)!,
          ],
        ).createShader(rrect.outerRect),
    );

    final centerY = _bandTop + _bandHeight / 2;
    final barPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..color = onPrimary.withValues(alpha: 0.85 + 0.15 * emphasis);
    const barCount = 3;
    const barSpacing = 3.0;
    const barHalfHeight = (barCount - 1) * barSpacing / 2;
    for (var i = 0; i < barCount; i++) {
      final y = centerY - barHalfHeight + i * barSpacing;
      canvas.drawLine(Offset(x, y - 3), Offset(x, y + 3), barPaint);
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
