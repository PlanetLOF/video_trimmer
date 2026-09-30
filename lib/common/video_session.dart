import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../util/probe.dart';
import '../util/timecode.dart';

/// Owns the media_kit [Player], the playback streams, and the trim selection
/// state. The source of truth for position/duration/selection that the UI
/// renders. The media_kit player is created lazily by [init] so widgets can
/// be tested without a running player.
class VideoSession extends ChangeNotifier {
  VideoSession({Probe? probe, bool initOnConstruct = true})
    : _probe = probe ?? Probe() {
    if (initOnConstruct) {
      init();
    }
  }

  final Probe _probe;

  Player? _player;
  VideoController? _controller;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  final Completer<void> _ready = Completer<void>();

  String? _inputPath;
  String? _displayName;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  Duration? _frameTime;
  bool _playing = false;
  bool _loading = true;
  bool _hasVideo = true;
  bool _hasError = false;
  bool _doNotDefaultToMp4 = false;
  bool _precise = false;
  bool _removeAudio = false;
  int _fileId = 0;

  String? _startText;
  String? _endText;
  int? _startMs;
  int? _endMs;
  bool? _startError;
  bool? _endError;

  bool _isOpen = false;

  Player? get player => _player;
  VideoController? get controller => _controller;
  Future<void> get ready => _ready.future;

  String? get inputPath => _inputPath;
  String? get displayName => _displayName;
  bool get isOpen => _isOpen;
  int get fileId => _fileId;

  Duration get duration => _duration;
  Duration get position => _position;
  Duration? get frameTime => _frameTime;
  bool get playing => _playing;
  bool get loading => _loading;
  bool get hasVideo => _hasVideo;
  bool get hasError => _hasError;
  bool get doNotDefaultToMp4 => _doNotDefaultToMp4;
  bool get precise => _precise;
  bool get removeAudio => _removeAudio;

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

  /// Creates the media_kit player and subscribes to its streams. Safe to call
  /// multiple times; errors are swallowed so the UI can show them instead.
  Future<void> init() async {
    if (_player != null) {
      return;
    }
    try {
      final player = Player(configuration: PlayerConfiguration(vo: 'gpu-next'));
      _player = player;
      _controller = VideoController(
        player,
        configuration: VideoControllerConfiguration(hwdec: 'auto-unsafe'),
      );
      _subscriptions.add(
        player.stream.position.listen((value) {
          _position = value;
          notifyListeners();
        }),
      );
      _subscriptions.add(
        player.stream.duration.listen((value) {
          final firstDuration =
              _duration == Duration.zero && value != Duration.zero;
          _duration = value;
          if (firstDuration) {
            _applyDefaultEntries();
          }
          notifyListeners();
        }),
      );
      _subscriptions.add(
        player.stream.playing.listen((value) {
          _playing = value;
          notifyListeners();
        }),
      );
      _subscriptions.add(
        player.stream.buffering.listen((value) {
          _loading = value;
          notifyListeners();
        }),
      );
      _subscriptions.add(
        player.stream.error.listen((error) {
          _hasError = true;
          notifyListeners();
        }),
      );
      _subscriptions.add(
        player.stream.width.listen((width) {
          _hasVideo = (width ?? 0) > 0;
          notifyListeners();
        }),
      );
      _ready.complete();
    } catch (error) {
      debugPrint('VideoSession: media_kit init failed: $error');
      _hasError = true;
      _ready.complete();
      notifyListeners();
    }
  }

  /// Opens [path], replacing any currently open file.
  Future<void> open(String path) async {
    _inputPath = path;
    _displayName = path.split(RegExp(r'[\\/]')).last;
    _isOpen = true;
    _fileId++;
    _startText = null;
    _endText = null;
    _doNotDefaultToMp4 = false;
    _hasError = false;
    _loading = true;
    _hasVideo = true;
    _position = Duration.zero;
    _duration = Duration.zero;
    _applyDefaultEntries();
    notifyListeners();

    await init();
    try {
      final media = Media(Uri.file(path).toString());
      await _player?.open(media, play: false);
    } catch (error) {
      _hasError = true;
      notifyListeners();
    }
    unawaited(_probeFile(path));
  }

  Future<void> _probeFile(String path) async {
    final result = await _probe.run(path);
    if (_inputPath != path) {
      return;
    }
    _doNotDefaultToMp4 = result.hasPcmAudio;
    _frameTime = result.frameTime;
    notifyListeners();
  }

  void _applyDefaultEntries() {
    final durationMs = _duration.inMilliseconds;
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

  void _validate() {
    _startMs = timestamp(_startText ?? '');
    _endMs = timestamp(_endText ?? '');
    _startError = _startMs == null;
    _endError =
        _endMs == null ||
        (_startMs != null && _endMs != null && _startMs! >= _endMs!);
  }

  Future<void> togglePlay() async {
    final player = _player;
    if (player == null) {
      return;
    }
    if (_playing) {
      await player.pause();
    } else {
      await player.play();
    }
  }

  Future<void> pause() async {
    await _player?.pause();
  }

  /// Seeks to an absolute [time].
  Future<void> seek(Duration time) async {
    _position = time;
    notifyListeners();
    await _player?.seek(time);
  }

  /// Seeks by the approximate frame time, forward or backward.
  Future<void> step(int direction) async {
    final frameTime = _frameTime;
    final player = _player;
    if (frameTime == null || player == null) {
      return;
    }
    final delta = Duration(microseconds: direction * frameTime.inMicroseconds);
    final target = _position + delta;
    await seek(target < Duration.zero ? Duration.zero : target);
  }

  Future<void> stepForward() => step(1);
  Future<void> stepBack() => step(-1);

  /// Sets the start timestamp to the current playback position.
  void setStartAsPosition() {
    final ms = _position.inMicroseconds ~/ 1000;
    _startText = timeToEntryText(Duration(milliseconds: ms));
    _validate();
    notifyListeners();
  }

  /// Sets the end timestamp to the current playback position.
  void setEndAsPosition() {
    final ms = _position.inMicroseconds ~/ 1000;
    _endText = timeToEntryText(Duration(milliseconds: ms));
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

  void setPrecise(bool value) {
    if (_precise == value) {
      return;
    }
    _precise = value;
    notifyListeners();
  }

  void setRemoveAudio(bool value) {
    if (_removeAudio == value) {
      return;
    }
    _removeAudio = value;
    notifyListeners();
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    unawaited(_player?.dispose());
    super.dispose();
  }
}
