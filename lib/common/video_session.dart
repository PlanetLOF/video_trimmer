import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../util/probe.dart';
import 'trim_selection.dart';

/// The playback calls a session makes. media_kit's [Player] reaches it through
/// [_MediaKitDriver], and a test can hand a session a stub instead, so that
/// opening a file and stepping a frame need no video backend.
abstract class PlayerDriver {
  Future<void> open(Playable playable, {bool play = true});
  Future<void> pause();
  Future<void> play();
  Future<void> seek(Duration position);
}

class _MediaKitDriver implements PlayerDriver {
  const _MediaKitDriver(this._player);

  final Player _player;

  @override
  Future<void> open(Playable playable, {bool play = true}) {
    return _player.open(playable, play: play);
  }

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> seek(Duration position) => _player.seek(position);
}

/// Owns the media_kit [Player], the playback streams, and the [TrimSelection]
/// the UI trims from. The source of truth for position/duration/selection
/// that the UI renders. The media_kit player is created lazily by [init] so
/// widgets can be tested without a running player; a [PlayerDriver] stands in
/// for it when even that lazy creation has to be skipped.
class VideoSession extends ChangeNotifier {
  VideoSession({
    Probe? probe,
    bool initOnConstruct = true,
    PlayerDriver? driver,
  }) : _probe = probe ?? Probe(),
       _trim = TrimSelection() {
    _driver = driver;
    _trim.addListener(notifyListeners);
    if (initOnConstruct) {
      init();
    }
  }

  final Probe _probe;

  /// The entry texts, their parsed values and the defaults they fall back to.
  /// Notifies through this session, so the widgets keep listening to one
  /// notifier.
  final TrimSelection _trim;

  /// The injected driver, or [_MediaKitDriver] once [init] has created the
  /// media_kit player. Null while neither exists.
  PlayerDriver? _driver;

  Player? _player;
  VideoController? _controller;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  final Completer<void> _ready = Completer<void>();

  String? _inputPath;
  String? _displayName;
  Duration _duration = Duration.zero;

  /// The playhead position on a notifier of its own. It moves many times a
  /// second, and notifying the whole session on every tick would rebuild the
  /// page around it; only the readout and the timeline paint it.
  final ValueNotifier<Duration> _position = ValueNotifier(Duration.zero);

  Duration? _frameTime;
  bool _playing = false;
  bool _loading = true;
  bool _hasVideo = true;
  bool _hasError = false;
  bool _doNotDefaultToMp4 = false;
  bool _precise = false;
  bool _removeAudio = false;
  int _fileId = 0;

  bool _isOpen = false;

  Player? get player => _player;
  VideoController? get controller => _controller;
  Future<void> get ready => _ready.future;

  /// The trim selection the timeline drags and the entry fields edit.
  TrimSelection get trim => _trim;

  /// Whatever drives playback: the injected [PlayerDriver] when there is one,
  /// otherwise a wrapper around the media_kit player [init] created.
  PlayerDriver? get _playback => _driver;

  String? get inputPath => _inputPath;
  String? get displayName => _displayName;
  bool get isOpen => _isOpen;
  int get fileId => _fileId;

  Duration get duration => _duration;
  Duration get position => _position.value;

  /// The position as a listenable of its own, for the widgets that only draw
  /// it. Keeping it out of [addListener] is what keeps a tick from rebuilding
  /// the page.
  ValueListenable<Duration> get positionListenable => _position;

  Duration? get frameTime => _frameTime;
  bool get playing => _playing;
  bool get loading => _loading;
  bool get hasVideo => _hasVideo;
  bool get hasError => _hasError;
  bool get doNotDefaultToMp4 => _doNotDefaultToMp4;
  bool get precise => _precise;
  bool get removeAudio => _removeAudio;

  /// Creates the media_kit player and subscribes to its streams. Safe to call
  /// multiple times; errors are swallowed so the UI can show them instead.
  Future<void> init() async {
    // An injected driver stands in for the media_kit player: there is nothing
    // to create and no streams to subscribe to, but the session is ready to
    // open files. open() calls this per file, so [ready]'s completer is only
    // completed on the way through.
    if (_driver != null) {
      if (!_ready.isCompleted) {
        _ready.complete();
      }
      return;
    }
    if (_player != null) {
      return;
    }
    try {
      final player = Player(configuration: PlayerConfiguration(vo: 'gpu-next'));
      _player = player;
      _driver = _MediaKitDriver(player);
      _controller = VideoController(
        player,
        configuration: VideoControllerConfiguration(hwdec: 'auto-unsafe'),
      );
      _subscriptions.add(
        player.stream.position.listen((value) {
          _position.value = value;
        }),
      );
      _subscriptions.add(
        player.stream.duration.listen((value) {
          final firstDuration =
              _duration == Duration.zero && value != Duration.zero;
          _duration = value;
          if (firstDuration) {
            _trim.applyDefaultEntries(value);
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
    _trim.reset();
    _doNotDefaultToMp4 = false;
    _hasError = false;
    _loading = true;
    _hasVideo = true;
    _position.value = Duration.zero;
    _duration = Duration.zero;
    _trim.applyDefaultEntries(_duration);
    notifyListeners();

    await init();
    try {
      final media = Media(Uri.file(path).toString());
      await _playback?.open(media, play: false);
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

  Future<void> togglePlay() async {
    final player = _playback;
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
    await _playback?.pause();
  }

  /// Seeks to an absolute [time].
  Future<void> seek(Duration time) async {
    _position.value = time;
    await _playback?.seek(time);
  }

  /// Seeks by the approximate frame time, forward or backward.
  Future<void> step(int direction) async {
    final frameTime = _frameTime;
    final player = _playback;
    if (frameTime == null || player == null) {
      return;
    }
    final delta = Duration(microseconds: direction * frameTime.inMicroseconds);
    final target = _position.value + delta;
    await seek(target < Duration.zero ? Duration.zero : target);
  }

  Future<void> stepForward() => step(1);
  Future<void> stepBack() => step(-1);

  /// Sets the start timestamp to the current playback position.
  void setStartAsPosition() {
    _trim.updateStartMs(_position.value.inMicroseconds ~/ 1000);
  }

  /// Sets the end timestamp to the current playback position.
  void setEndAsPosition() {
    _trim.updateEndMs(_position.value.inMicroseconds ~/ 1000);
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
    _trim.dispose();
    _position.dispose();
    super.dispose();
  }
}
