import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../util/timecode.dart';

/// The trim selection: the two entry texts, what they parse to, and whether
/// they make a usable range.
///
/// It is a [ChangeNotifier] because the timeline drag, the entry fields and
/// the playhead buttons each change it on their own, so it owns that change
/// signal and `VideoSession` relays it to the widgets that already listen to
/// the session.
class TrimSelection extends ChangeNotifier {
  TrimSelection();

  String? _startText;
  String? _endText;
  int? _startMs;
  int? _endMs;
  bool? _startError;
  bool? _endError;

  String? get startText => _startText;
  String? get endText => _endText;

  /// The parsed start/end timestamps in milliseconds, or null when invalid.
  int? get startMs => _startMs;
  int? get endMs => _endMs;
  bool get startError => _startError ?? false;
  bool get endError => _endError ?? false;

  bool get selectionValid =>
      _startMs != null && _endMs != null && _startMs! < _endMs!;

  /// A snapshot of the valid selection used for trimming.
  (int, int)? get selection => selectionValid ? (_startMs!, _endMs!) : null;

  /// Clears both entries for a new file.
  ///
  /// The parsed values and the error flags stay as they are: the entries are
  /// refilled as soon as the duration is known, and revalidating an empty pair
  /// in between would only mark both fields as errors.
  ///
  /// Silent, like [applyDefaultEntries] — whoever opened the file notifies
  /// once for the whole open.
  void reset() {
    _startText = null;
    _endText = null;
  }

  /// Fills in whichever entry is still empty: the middle third of the video,
  /// or the whole video on the side whose opposite end is already set.
  ///
  /// Does nothing before a duration is known and nothing once both entries are
  /// set, so it is safe to call on every duration change. Silent, like [reset].
  void applyDefaultEntries(Duration duration) {
    final durationMs = duration.inMilliseconds;
    if (durationMs <= 0) {
      return;
    }
    final hasStart = _startText != null;
    final hasEnd = _endText != null;
    if (hasStart && hasEnd) {
      return;
    }

    var start = durationMs ~/ 3;
    var end = math.max(durationMs ~/ 3 * 2, start + 1);
    var startAssigned = false;
    var endAssigned = false;

    if (!hasStart) {
      start = hasEnd ? 0 : start;
      _startText = timeToEntryText(Duration(milliseconds: start));
      startAssigned = true;
    }
    if (!hasEnd) {
      end = hasStart ? durationMs : end;
      _endText = timeToEntryText(Duration(milliseconds: end));
      endAssigned = true;
    }

    if (startAssigned || endAssigned) {
      _validate();
    }
  }

  void setStartText(String text) {
    if (text == _startText) {
      return;
    }
    _startText = text;
    _validate();
    notifyListeners();
  }

  void setEndText(String text) {
    if (text == _endText) {
      return;
    }
    _endText = text;
    _validate();
    notifyListeners();
  }

  /// Updates the start timestamp from an external source (timeline drag),
  /// rounded to the entry-text resolution.
  void updateStartMs(int ms) {
    _startText = timeToEntryText(Duration(milliseconds: ms));
    _validate();
    notifyListeners();
  }

  /// Updates the end timestamp from an external source (timeline drag),
  /// rounded to the entry-text resolution.
  void updateEndMs(int ms) {
    _endText = timeToEntryText(Duration(milliseconds: ms));
    _validate();
    notifyListeners();
  }

  void _validate() {
    _startMs = timestamp(_startText ?? '');
    _endMs = timestamp(_endText ?? '');
    _startError = _startMs == null;
    _endError =
        _endMs == null ||
        (_startMs != null && _endMs != null && _startMs! >= _endMs!);
  }
}
