import 'package:desktop_drop/desktop_drop.dart';
import 'package:material_ui/material_ui.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:window_manager/window_manager.dart';

import 'about_sheet.dart';
import '../util/ffmpeg.dart';
import 'app_menu.dart';
import 'open_dialog.dart';
import '../util/platform_util.dart';
import 'save_dialog.dart';
import '../common/app_settings.dart';
import '../common/shortcuts.dart';
import 'settings_sheet.dart';
import 'start_end_row.dart';
import '../common/theme.dart';
import 'timeline.dart';
import 'trim_dialog.dart';
import '../common/video_session.dart';

class VideoTrimmerApp extends StatefulWidget {
  const VideoTrimmerApp({
    super.key,
    this.session,
    this.binariesMissing = const [],
    this.initialSettings = const AppSettings(),
    this.settingsStore,
  });

  final VideoSession? session;
  final List<String> binariesMissing;
  final AppSettings initialSettings;
  final AppSettingsStore? settingsStore;

  @override
  State<VideoTrimmerApp> createState() => _VideoTrimmerAppState();
}

class _VideoTrimmerAppState extends State<VideoTrimmerApp> {
  late AppSettings _settings = widget.initialSettings;

  void _changeSettings(AppSettings settings) {
    setState(() => _settings = settings);
    widget.settingsStore?.save(settings).ignore();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Video Trimmer',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(brightness: .light, accent: _settings.accent),
      darkTheme: buildAppTheme(brightness: .dark, accent: _settings.accent),
      themeMode: _settings.themeMode,
      home: widget.binariesMissing.isEmpty
          ? VideoTrimmerHome(
              session: widget.session,
              settings: _settings,
              onSettingsChanged: _changeSettings,
            )
          : MissingBinariesPage(binariesMissing: widget.binariesMissing),
    );
  }
}

class VideoTrimmerHome extends StatefulWidget {
  const VideoTrimmerHome({
    super.key,
    this.session,
    this.settings = const AppSettings(),
    this.onSettingsChanged,
  });

  final VideoSession? session;
  final AppSettings settings;
  final ValueChanged<AppSettings>? onSettingsChanged;

  @override
  State<VideoTrimmerHome> createState() => _VideoTrimmerHomeState();
}

class _VideoTrimmerHomeState extends State<VideoTrimmerHome> {
  late final VideoSession _session;
  late final Ffmpeg _ffmpeg = Ffmpeg();

  bool _dragOver = false;
  bool _isFullscreen = false;
  late final _WindowListener _windowListener;

  VideoSession get session => _session;

  @override
  void initState() {
    super.initState();
    _session = widget.session ?? VideoSession();
    _windowListener = _WindowListener(onFullscreenChange: (isFullscreen) {
      if (mounted) {
        setState(() => _isFullscreen = isFullscreen);
      }
    });
    windowManager.addListener(_windowListener);
    _initFullscreenState();
  }

  Future<void> _initFullscreenState() async {
    _isFullscreen = await windowManager.isFullScreen();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    windowManager.removeListener(_windowListener);
    if (widget.session == null) {
      _session.dispose();
    }
    super.dispose();
  }

  Future<void> _openVideo(String? pathOverride) async {
    var path = pathOverride ?? await openVideoFile(context);
    if (path == null || path.isEmpty) {
      return;
    }
    await _session.ready;
    if (!mounted) {
      return;
    }
    await _session.open(path);
  }

  Future<void> _verifyAndTrim() async {
    if (!session.selectionValid) {
      return;
    }
    final start = session.startText!;
    final end = session.endText!;
    final inputPath = session.inputPath!;

    final outputPath = await showSaveDialog(
      context,
      inputPath: inputPath,
      hasPcmAudio: session.doNotDefaultToMp4,
      start: start,
      end: end,
    );
    if (outputPath == null || !mounted) {
      return;
    }
    await session.pause();
    if (!mounted) {
      return;
    }
    await runTrimFlow(
      context,
      ffmpeg: _ffmpeg,
      inputPath: inputPath,
      outputPath: outputPath,
      start: start,
      end: end,
      reencode: session.precise,
      noAudio: session.removeAudio,
    );
  }

  void _onDropped(DropDoneDetails details) {
    final file = details.files.isNotEmpty ? details.files.first.path : null;
    if (file == null || file.isEmpty) {
      return;
    }
    _openVideo(file);
  }

  void _setDragOver(bool value) {
    if (_dragOver == value) {
      return;
    }
    setState(() => _dragOver = value);
  }

  @override
  Widget build(BuildContext context) {
    return AppShortcuts(
      session: session,
      onTrim: _verifyAndTrim,
      onOpen: () => _openVideo(null),
      child: DropTarget(
        onDragEntered: (_) => _setDragOver(true),
        onDragExited: (_) => _setDragOver(false),
        onDragDone: (details) {
          _setDragOver(false);
          _onDropped(details);
        },
        child: ListenableBuilder(
          listenable: session,
          builder: (context, child) {
            return Scaffold(
              body: Stack(
                children: [
                  _buildMainPage(context),
                  if (_dragOver) _buildDropOverlay(context),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildDropOverlay(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          color: colorScheme.primary.withValues(alpha: 0.06),
          child: Center(
            child: Container(
              margin: const EdgeInsets.all(24),
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerLow,
                borderRadius: .circular(20),
                border: .all(color: colorScheme.primary, width: 2),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.file_download_outlined,
                    size: 40,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(height: 12),
                  const Text('Release to open video'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMainPage(BuildContext context) {
    return Column(
      children: [
        Expanded(child: _buildVideoArea(context)),
        if (!_isFullscreen) ...[
          Timeline(session: session),
          const Divider(height: 1),
          StartEndRow(session: session, onRequestTrim: _verifyAndTrim),
        ],
      ],
    );
  }

  Widget _buildVideoArea(BuildContext context) {
    final controller = session.controller;
    final colorScheme = Theme.of(context).colorScheme;
    final Widget videoChild;
    if (session.hasError) {
      videoChild = _MessageView(
        icon: Icons.error_outline,
        label: 'Video could not be played.',
      );
    } else if (!session.isOpen) {
      videoChild = _buildWelcomeContent(context);
    } else if (controller == null || session.loading) {
      videoChild = const Center(child: CircularProgressIndicator());
    } else if (!session.hasVideo) {
      videoChild = _MessageView(
        icon: Icons.movie_outlined,
        label: 'This file has no video stream.',
      );
    } else {
      // media_kit_video 2.0.1 still imports the legacy `package:flutter/material.dart`,
      // so none of its widgets can see this app's `material_ui` ThemeData. That is fine
      // here because `NoVideoControls` disables the built-in controls and subtitles are
      // never enabled, so no legacy widget is actually built. If either is turned on,
      // wrap this subtree in `MaterialUiCompatibilityBridge` from `package:material_ui`
      // so the legacy widgets resolve the app theme. The bridge is deprecated as of
      // material_ui 1.4.0 and will be removed in a future release.
      videoChild = Video(controller: controller, controls: NoVideoControls);
    }

    return Padding(
      padding: const EdgeInsets.all(10),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: .circular(12),
          border: .all(color: colorScheme.primary, width: 2),
        ),
        child: ClipRRect(
          borderRadius: .circular(9),
          child: ColoredBox(
            color: session.isOpen
                ? Colors.black
                : colorScheme.surfaceContainerLow,
            child: Stack(
              children: [
                // Video playback or welcome content
                SizedBox.expand(child: videoChild),
                // Top-right overlay menu (always show)
                Positioned(top: 8, right: 8, child: _buildOverlayMenu(context)),
                // Bottom-left video title (only when video loaded)
                if (session.isOpen && session.displayName != null)
                  Positioned(
                    bottom: 8,
                    left: 8,
                    child: _buildVideoTitle(context),
                  ),
                // Bottom-right fullscreen button (only when video loaded)
                if (session.isOpen)
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: _buildFullscreenButton(context),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeContent(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.movie_outlined,
                  size: 48,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: 20),
              Text('Drop a video file here', style: textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                'or click Open to browse your files. Trimming works without re-encoding.',
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.outline,
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => _openVideo(null),
                icon: const Icon(Icons.folder_open),
                label: const Text('Open'),
              ),
              const SizedBox(height: 12),
              Text(
                'Tip: you can also drag & drop a video onto this window.',
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.outline,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOverlayMenu(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showAppMenu(context),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(
              Icons.more_horiz,
              color: colorScheme.onSurface,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }

  void _showAppMenu(BuildContext context) {
    final RenderBox button = context.findRenderObject()! as RenderBox;
    final Offset buttonPosition = button.localToGlobal(Offset.zero);
    final Size buttonSize = button.size;

    showMenu<AppMenuAction>(
      context: context,
      position: RelativeRect.fromLTRB(
        buttonPosition.dx + buttonSize.width,
        buttonPosition.dy,
        buttonPosition.dx,
        buttonPosition.dy + buttonSize.height,
      ),
      items: buildAppMenuEntries(session),
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ).then((action) {
      if (!mounted) return;
      if (action != null) {
        switch (action) {
          case AppMenuAction.open:
            _openVideo(null);
          case AppMenuAction.precise:
            session.setPrecise(!session.precise);
          case AppMenuAction.removeAudio:
            session.setRemoveAudio(!session.removeAudio);
          case AppMenuAction.settings:
            showSettingsSheet(
              context,
              settings: widget.settings,
              onChanged: widget.onSettingsChanged ?? (_) {},
            );
          case AppMenuAction.about:
            showVideoTrimmerAboutSheet(context);
        }
      }
    });
  }

  Widget _buildVideoTitle(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        session.displayName!,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.w500,
        ),
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
    );
  }

  Widget _buildFullscreenButton(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _toggleFullscreen,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.fullscreen,
            color: colorScheme.onSurface,
            size: 24,
          ),
        ),
      ),
    );
  }

  void _toggleFullscreen() async {
    final isFullscreen = await windowManager.isFullScreen();
    await windowManager.setFullScreen(!isFullscreen);
  }
}

/// Window listener for fullscreen state changes
class _WindowListener extends WindowListener {
  _WindowListener({required this.onFullscreenChange});
  final void Function(bool isFullscreen) onFullscreenChange;

  @override
  void onWindowEnterFullScreen() {
    onFullscreenChange(true);
  }

  @override
  void onWindowLeaveFullScreen() {
    onFullscreenChange(false);
  }
}

class _MessageView extends StatelessWidget {
  const _MessageView({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 64, color: colorScheme.outline),
          const SizedBox(height: 12),
          Text(label),
        ],
      ),
    );
  }
}

class MissingBinariesPage extends StatefulWidget {
  const MissingBinariesPage({super.key, required this.binariesMissing});

  final List<String> binariesMissing;

  @override
  State<MissingBinariesPage> createState() => _MissingBinariesPageState();
}

class _MissingBinariesPageState extends State<MissingBinariesPage> {
  late List<String> _missing = List.of(widget.binariesMissing);

  Future<void> _recheck() async {
    final missing = <String>[];
    for (final name in ['ffmpeg', 'ffprobe']) {
      if (!await PlatformUtil.binaryRuns(name)) {
        missing.add(name);
      }
    }
    if (!mounted) {
      return;
    }
    setState(() => _missing = missing);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Video Trimmer')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: colorScheme.errorContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.error_outline,
                    size: 48,
                    color: colorScheme.onErrorContainer,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'ffmpeg & ffprobe could not be found',
                  style: textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                Text(
                  'Missing: ${_missing.join(', ')}. Videos cannot be trimmed '
                  'without ffmpeg and ffprobe.\n\n'
                  'Install ffmpeg and make sure it is available on your PATH, '
                  'then restart or retry.',
                  textAlign: TextAlign.center,
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _recheck,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
