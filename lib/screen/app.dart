import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:media_kit_video/media_kit_video.dart';

import 'about_dialog.dart';
import '../util/ffmpeg.dart';
import 'open_dialog.dart';
import 'playback_bar.dart';
import '../util/platform_util.dart';
import 'save_dialog.dart';
import '../common/shortcuts.dart';
import 'start_end_row.dart';
import '../common/theme.dart';
import 'timeline.dart';
import 'trim_dialog.dart';
import '../common/video_session.dart';

class VideoTrimmerApp extends StatelessWidget {
  const VideoTrimmerApp({
    super.key,
    this.session,
    this.binariesMissing = const [],
  });

  final VideoSession? session;
  final List<String> binariesMissing;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Video Trimmer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: .fromSeed(seedColor: kSeedColor),
      ),
      darkTheme: ThemeData(
        colorScheme: .fromSeed(
          seedColor: kSeedColor,
          brightness: Brightness.dark,
        ),
      ),
      themeMode: ThemeMode.system,
      home: binariesMissing.isEmpty
          ? VideoTrimmerHome(session: session)
          : MissingBinariesPage(binariesMissing: binariesMissing),
    );
  }
}

class VideoTrimmerHome extends StatefulWidget {
  const VideoTrimmerHome({super.key, this.session});

  final VideoSession? session;

  @override
  State<VideoTrimmerHome> createState() => _VideoTrimmerHomeState();
}

class _VideoTrimmerHomeState extends State<VideoTrimmerHome> {
  late final VideoSession _session;
  late final Ffmpeg _ffmpeg = Ffmpeg();

  VideoSession get session => _session;

  @override
  void initState() {
    super.initState();
    _session = widget.session ?? VideoSession();
  }

  @override
  void dispose() {
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

  @override
  Widget build(BuildContext context) {
    return AppShortcuts(
      session: session,
      onTrim: _verifyAndTrim,
      onOpen: () => _openVideo(null),
      child: DropTarget(
        onDragDone: _onDropped,
        child: ListenableBuilder(
          listenable: session,
          builder: (context, child) {
            return Scaffold(
              appBar: _buildAppBar(context),
              body: session.isOpen ? _buildMainPage(context) : _buildEmptyPage(context),
            );
          },
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Video Trimmer'),
          if (session.isOpen)
            Text(
              session.displayName ?? '',
              style: Theme.of(context).textTheme.bodySmall,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
      actions: [
        PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case 'open':
                _openVideo(null);
              case 'precise':
                session.setPrecise(!session.precise);
              case 'removeAudio':
                session.setRemoveAudio(!session.removeAudio);
              case 'about':
                showVideoTrimmerAboutDialog(context);
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'open', child: Text('Open…')),
            const PopupMenuDivider(),
            CheckedPopupMenuItem(
              value: 'precise',
              checked: session.precise,
              child: const Text('Precise (re-encode)'),
            ),
            CheckedPopupMenuItem(
              value: 'removeAudio',
              checked: session.removeAudio,
              child: const Text('Remove audio'),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem(value: 'about', child: Text('About Video Trimmer')),
          ],
        ),
      ],
    );
  }

  Widget _buildEmptyPage(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.movie_outlined, size: 96, color: colorScheme.outline),
          const SizedBox(height: 16),
          const Text('Open a video file'),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => _openVideo(null),
            icon: const Icon(Icons.folder_open),
            label: const Text('Open'),
          ),
        ],
      ),
    );
  }

  Widget _buildMainPage(BuildContext context) {
    return Column(
      children: [
        Expanded(child: _buildVideoArea(context)),
        Timeline(session: session),
        const Divider(height: 1),
        PlaybackBar(session: session),
        StartEndRow(session: session, onRequestTrim: _verifyAndTrim),
      ],
    );
  }

  Widget _buildVideoArea(BuildContext context) {
    final controller = session.controller;
    final Widget child;
    if (session.hasError) {
      child = _MessageView(
        icon: Icons.error_outline,
        label: 'Video could not be played.',
      );
    } else if (controller == null || session.loading) {
      child = const Center(child: CircularProgressIndicator());
    } else if (!session.hasVideo) {
      child = _MessageView(
        icon: Icons.movie_outlined,
        label: 'This file has no video stream.',
      );
    } else {
      child = Video(
        controller: controller,
        controls: NoVideoControls,
      );
    }
    return ColoredBox(
      color: Colors.black,
      child: SizedBox.expand(child: child),
    );
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
    return Scaffold(
      appBar: AppBar(title: const Text('Video Trimmer')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 64, color: colorScheme.error),
              const SizedBox(height: 16),
              const Text('ffmpeg & ffprobe could not be found'),
              const SizedBox(height: 8),
              Text(
                'Missing: ${_missing.join(', ')}. Videos cannot be trimmed without '
                'ffmpeg and ffprobe.\n\nInstall ffmpeg and make sure it is available '
                'on your PATH, then restart or retry.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _recheck,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
