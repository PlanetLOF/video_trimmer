import 'dart:async';

import 'package:flutter/material.dart';

import '../util/timecode.dart';
import '../common/video_session.dart';

const _tolerance = 5.0;
const _trackHeight = 56.0;

enum _DragType { scrub, start, end }

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

  void _onDragStart(double x, double width) {
    _dragType = _DragType.scrub;

    final selection = session.selection;
    if (selection != null) {
      final (start, end) = selection;
      final xStart = _xForMs(start, width);
      final xEnd = _xForMs(end, width);
      if ((x - xEnd).abs() <= _tolerance) {
        _dragType = _DragType.end;
      } else if ((x - xStart).abs() <= _tolerance) {
        _dragType = _DragType.start;
      }
    }

    _onDragUpdate(x, width);
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
            return MouseRegion(
              cursor: _isNearHandle(_hoverX, width)
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
                child: CustomPaint(
                  size: Size(width, _trackHeight),
                  painter: _TimelinePainter(
                    durationMs: session.duration.inMilliseconds,
                    positionMs: session.position.inMilliseconds,
                    selection: session.selection,
                    colorScheme: Theme.of(context).colorScheme,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  bool _isNearHandle(double x, double width) {
    if (width <= 0) {
      return false;
    }
    final selection = session.selection;
    if (selection == null) {
      return false;
    }
    final (start, end) = selection;
    final xStart = _xForMs(start, width);
    final xEnd = _xForMs(end, width);
    if ((x - xEnd).abs() <= _tolerance || (x - xStart).abs() <= _tolerance) {
      return true;
    }
    return false;
  }
}

class _TimelinePainter extends CustomPainter {
  _TimelinePainter({
    required this.durationMs,
    required this.positionMs,
    required this.selection,
    required this.colorScheme,
  });

  static const _bandTop = 4.0;
  static const _bandHeight = 36.0;
  static const _labelBaseline = _bandTop + _bandHeight + 14;

  final int durationMs;
  final int positionMs;
  final (int, int)? selection;
  final ColorScheme colorScheme;

  @override
  void paint(Canvas canvas, Size size) {
    final bandBottom = _bandTop + _bandHeight;
    final trackY = _bandTop + _bandHeight / 2;

    // Track background matched exactly to the band height, so the bar and its
    // backdrop stay the same size.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(0, _bandTop, size.width, bandBottom),
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
        Offset(x, bandBottom - 6),
        Offset(x, bandBottom - 3),
        tickPaint,
      );
    }

    final sel = selection;
    if (sel != null) {
      final (start, end) = sel;
      final xStart = xForMs(start).clamp(0.0, size.width);
      final xEnd = xForMs(end).clamp(0.0, size.width);
      if (xEnd > xStart) {
        // Selection band.
        final bandRect = Rect.fromLTRB(xStart, _bandTop, xEnd, bandBottom);
        canvas.drawRRect(
          RRect.fromRectAndRadius(bandRect, const Radius.circular(5)),
          Paint()..color = colorScheme.primary.withValues(alpha: 0.38),
        );

        // Handles.
        _drawHandle(canvas, xStart, _bandTop, bandBottom);
        _drawHandle(canvas, xEnd, _bandTop, bandBottom);

        // Timecode labels under the handles.
        _drawLabel(
          canvas,
          size.width,
          timeToEntryText(Duration(milliseconds: start)),
          xStart,
        );
        _drawLabel(
          canvas,
          size.width,
          timeToEntryText(Duration(milliseconds: end)),
          xEnd,
        );
      }
    }

    // Playhead.
    final xPosition = xForMs(positionMs).clamp(0.0, size.width);
    final playheadPaint = Paint()
      ..color = colorScheme.onSurface
      ..strokeWidth = 2;
    canvas.drawLine(
      Offset(xPosition, trackY - 14),
      Offset(xPosition, trackY + 14),
      playheadPaint,
    );
    canvas.drawCircle(
      Offset(xPosition, trackY - 14),
      4,
      Paint()..color = colorScheme.onSurface,
    );
  }

  void _drawHandle(Canvas canvas, double x, double bandTop, double bandBottom) {
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTRB(x - 6, bandTop - 3, x + 6, bandBottom + 3),
      const Radius.circular(4),
    );
    canvas.drawRRect(rect, Paint()..color = colorScheme.primary);
    // Grip bar.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(x - 1.5, bandTop + 8, x + 1.5, bandBottom - 8),
        const Radius.circular(1),
      ),
      Paint()..color = colorScheme.onPrimary.withValues(alpha: 0.9),
    );
  }

  void _drawLabel(Canvas canvas, double width, String text, double centerX) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: colorScheme.onSurface,
          fontSize: 10,
          fontWeight: FontWeight.w600,
          fontFamily: 'monospace',
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
        oldDelegate.colorScheme != colorScheme;
  }
}
