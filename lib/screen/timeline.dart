import 'dart:async';

import 'package:flutter/material.dart';

import '../util/timecode.dart';
import '../common/video_session.dart';

const _tolerance = 5.0;

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
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(left: 26, right: 26, top: 8, bottom: 4),
      child: SizedBox(
        height: 40,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            return MouseRegion(
              cursor: _isNearHandle(_hoverX, width)
                  ? SystemMouseCursors.resizeLeftRight
                  : SystemMouseCursors.basic,
              onHover: (event) => setState(() => _hoverX = event.localPosition.dx),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanStart: (details) =>
                    _onDragStart(details.localPosition.dx, width),
                onPanUpdate: (details) =>
                    _onDragUpdate(details.localPosition.dx, width),
                child: CustomPaint(
                  size: Size(width, 40),
                  painter: _TimelinePainter(
                    durationMs: session.duration.inMilliseconds,
                    positionMs: session.position.inMilliseconds,
                    selection: session.selection,
                    colorScheme: colorScheme,
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

  final int durationMs;
  final int positionMs;
  final (int, int)? selection;
  final ColorScheme colorScheme;

  @override
  void paint(Canvas canvas, Size size) {
    final trackPaint = Paint()
      ..color = colorScheme.surfaceContainerHighest
      ..strokeWidth = 2;
    final trackY = size.height / 2;
    canvas.drawLine(Offset(0, trackY), Offset(size.width, trackY), trackPaint);

    if (durationMs <= 0) {
      return;
    }

    double xForMs(int ms) {
      final fraction = (ms / durationMs).clamp(0.0, 1.0);
      return fraction * size.width;
    }

    final selection = this.selection;
    if (selection != null) {
      final (start, end) = selection;
      final xStart = xForMs(start);
      final xEnd = xForMs(end);
      if (xEnd > xStart) {
        final selectionRect = Rect.fromLTRB(xStart, trackY - 10, xEnd, trackY + 10);
        canvas.drawRRect(
          RRect.fromRectAndRadius(selectionRect, const Radius.circular(4)),
          Paint()..color = colorScheme.primary.withValues(alpha: 0.35),
        );
        final handlePaint = Paint()..color = colorScheme.primary;
        canvas.drawRect(
          Rect.fromLTWH(xStart - 2, trackY - 12, 4, 24),
          handlePaint,
        );
        canvas.drawRect(
          Rect.fromLTWH(xEnd - 2, trackY - 12, 4, 24),
          handlePaint,
        );
      }
    }

    final xPosition = xForMs(positionMs).clamp(0.0, size.width);
    final positionPaint = Paint()
      ..color = colorScheme.onSurface
      ..strokeWidth = 2;
    canvas.drawLine(
      Offset(xPosition, trackY - 12),
      Offset(xPosition, trackY + 12),
      positionPaint,
    );
  }

  @override
  bool shouldRepaint(_TimelinePainter oldDelegate) {
    return oldDelegate.durationMs != durationMs ||
        oldDelegate.positionMs != positionMs ||
        oldDelegate.selection != selection ||
        oldDelegate.colorScheme != colorScheme;
  }
}
