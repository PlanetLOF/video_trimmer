/// Helpers for parsing and formatting timecode entry text and file names.
library;

final RegExp _posInt = RegExp(r'^\d{1,2}$');

/// Parses a `[h:]mm:ss[.fff]`, `mm:ss[.fff]` or `ss[.fff]` timestamp into
/// milliseconds.
///
/// Returns `null` when [time] is not a valid timestamp: an empty string, an
/// empty or over-long fractional part, a field that is empty or non-numeric,
/// seconds or minutes above 59, hours above 99, or more than three
/// colon-separated fields.
int? timestamp(String time) {
  final dot = time.indexOf('.');
  final hasFrac = dot != -1;
  String intPart;
  String? frac;
  if (hasFrac) {
    if (time.indexOf('.', dot + 1) != -1) {
      return null;
    }
    intPart = time.substring(0, dot);
    frac = time.substring(dot + 1);
    if (frac.isEmpty || frac.length > 3) {
      return null;
    }
  } else {
    intPart = time;
  }
  if (intPart.isEmpty) {
    return null;
  }
  final fields = intPart.split(':');
  if (fields.length > 3) {
    return null;
  }
  int hours = 0;
  int minutes = 0;
  int seconds = 0;
  final twoDigits = RegExp(r'^\d{2}$');
  if (fields.length == 1) {
    final s = _parseField(fields[0], max: 59);
    if (s == null) {
      return null;
    }
    seconds = s;
  } else if (fields.length == 2) {
    final m = _parseField(fields[0], max: 99);
    final s = _parseField(fields[1], max: 59);
    if (m == null || s == null || !twoDigits.hasMatch(fields[1])) {
      return null;
    }
    minutes = m;
    seconds = s;
  } else {
    final h = _parseField(fields[0], max: 99);
    final m = _parseField(fields[1], max: 59);
    final s = _parseField(fields[2], max: 59);
    if (h == null ||
        m == null ||
        s == null ||
        !twoDigits.hasMatch(fields[1]) ||
        !twoDigits.hasMatch(fields[2])) {
      return null;
    }
    hours = h;
    minutes = m;
    seconds = s;
  }
  var ms = (hours * 3600 + minutes * 60 + seconds) * 1000;
  if (frac != null) {
    ms += _fracToMs(frac);
  }
  return ms;
}

int? _parseField(String field, {required int max}) {
  if (!_posInt.hasMatch(field)) {
    return null;
  }
  final value = int.tryParse(field);
  if (value == null || value > max) {
    return null;
  }
  return value;
}

int _fracToMs(String frac) {
  final value = int.parse(frac);
  var scale = 1;
  for (var i = frac.length; i < 3; i++) {
    scale *= 10;
  }
  return value * scale;
}

/// Formats [duration] as `[h:]mm:ss.t`, rounded to the nearest tenth of a
/// second, for the entry text field.
String timeToEntryText(Duration duration) {
  final totalTenths = (duration.inMilliseconds + 50) ~/ 100;
  final hours = totalTenths ~/ 36000;
  final minutes = (totalTenths % 36000) ~/ 600;
  final seconds = (totalTenths % 600) ~/ 10;
  final tenths = totalTenths % 10;
  String two(int v) => v.toString().padLeft(2, '0');
  if (hours > 0) {
    return '$hours:${two(minutes)}:${two(seconds)}.$tenths';
  }
  return '$minutes:${two(seconds)}.$tenths';
}

/// Strips a trailing fractional part that is entirely zeros from [text],
/// returning the text unchanged when it has no fractional part.
String timeForFilename(String text) {
  final dot = text.indexOf('.');
  if (dot == -1) {
    return text;
  }
  final integer = text.substring(0, dot);
  final fraction = text.substring(dot + 1);
  final stripped = fraction.replaceFirst(RegExp(r'0+$'), '');
  if (stripped.isEmpty) {
    return integer;
  }
  return '$integer.$stripped';
}
