import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:video_player/video_player.dart';

import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';

/// Streams a lesson video from its public URL (Cloudflare R2 or older hosts).
class LessonVideoPlayer extends StatefulWidget {
  const LessonVideoPlayer({super.key, required this.url});

  final String url;

  @override
  State<LessonVideoPlayer> createState() => _LessonVideoPlayerState();
}

class _LessonVideoPlayerState extends State<LessonVideoPlayer> {
  VideoPlayerController? _controller;
  bool _ready = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _open();
  }

  @override
  void didUpdateWidget(LessonVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) _open();
  }

  Future<void> _open() async {
    final previous = _controller;
    final uri = Uri.tryParse(widget.url);
    setState(() {
      _ready = false;
      _failed = uri == null;
      _controller = null;
    });
    await previous?.dispose();
    if (uri == null) return;
    final controller = VideoPlayerController.networkUrl(uri);
    _controller = controller;
    controller.addListener(_onChanged);
    try {
      await controller.initialize();
      if (!mounted || _controller != controller) return;
      setState(() => _ready = true);
    } catch (_) {
      if (!mounted || _controller != controller) return;
      setState(() => _failed = true);
    }
  }

  void _onChanged() {
    if (!mounted) return;
    final hasError = _controller?.value.hasError ?? false;
    setState(() => _failed = _failed || hasError);
  }

  void _toggle() {
    final controller = _controller;
    if (controller == null || !_ready) return;
    final value = controller.value;
    if (value.isPlaying) {
      controller.pause();
    } else {
      if (value.duration > Duration.zero && value.position >= value.duration) {
        controller.seekTo(Duration.zero);
      }
      controller.play();
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_onChanged);
    _controller?.dispose();
    super.dispose();
  }

  static String _time(Duration value) {
    final minutes = value.inMinutes;
    final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (minutes < 60) return '$minutes:$seconds';
    final rest = minutes.remainder(60).toString().padLeft(2, '0');
    return '${value.inHours}:$rest:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final muted = Colors.white.withValues(alpha: .75);
    Widget child;
    if (_failed) {
      child = Column(
        key: const Key('lesson-video-error'),
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(LucideIcons.circleAlert, size: 36, color: muted),
          const SizedBox(height: 10),
          Text(
            context.tr('Videoni ochib bo‘lmadi'),
            style: TextStyle(color: muted, fontSize: 13.5),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _open,
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            icon: const Icon(LucideIcons.rotateCw, size: 16),
            label: Text(context.tr('Qayta urinish')),
          ),
        ],
      );
    } else if (!_ready || controller == null) {
      child = const Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
      );
    } else {
      final value = controller.value;
      child = GestureDetector(
        key: const Key('lesson-video-player'),
        behavior: HitTestBehavior.opaque,
        onTap: _toggle,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: AspectRatio(
                aspectRatio: value.aspectRatio > 0 ? value.aspectRatio : 16 / 9,
                child: VideoPlayer(controller),
              ),
            ),
            if (!value.isPlaying)
              Center(
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: .45),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    LucideIcons.play,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
              ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 18, 12, 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: .55),
                    ],
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    VideoProgressIndicator(
                      controller,
                      allowScrubbing: true,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      colors: VideoProgressColors(
                        playedColor: Colors.white,
                        bufferedColor: Colors.white.withValues(alpha: .35),
                        backgroundColor: Colors.white.withValues(alpha: .15),
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          '${_time(value.position)} / ${_time(value.duration)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                        const Spacer(),
                        if (value.isBuffering)
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: ColoredBox(color: AppPalette.navy, child: child),
      ),
    );
  }
}
