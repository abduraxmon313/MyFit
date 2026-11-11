import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:video_player/video_player.dart';

import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';

/// Streams a lesson video from its public URL (Cloudflare R2 or older hosts).
/// The controls include a fullscreen button.
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
    previous?.removeListener(_onChanged);
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
    if (hasError && !_failed) setState(() => _failed = true);
  }

  Future<void> _openFullscreen() async {
    final controller = _controller;
    if (controller == null || !_ready) return;
    await Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder<void>(
        opaque: true,
        transitionDuration: const Duration(milliseconds: 180),
        reverseTransitionDuration: const Duration(milliseconds: 150),
        pageBuilder: (_, _, _) =>
            LessonVideoFullscreenPage(controller: controller),
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  void dispose() {
    _controller?.removeListener(_onChanged);
    _controller?.dispose();
    super.dispose();
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
      child = VideoSurface(
        key: const Key('lesson-video-player'),
        controller: controller,
        fullscreen: false,
        onFullscreen: _openFullscreen,
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

/// Fullscreen playback of an already initialised [controller].
///
/// Hides the system bars and follows the phone: upright shows the whole
/// video (letterboxed), turning the phone sideways fills the screen. Works
/// for both landscape and portrait videos. Restored when the page closes.
const kFullscreenOrientations = [
  DeviceOrientation.portraitUp,
  DeviceOrientation.landscapeLeft,
  DeviceOrientation.landscapeRight,
];

class LessonVideoFullscreenPage extends StatefulWidget {
  const LessonVideoFullscreenPage({super.key, required this.controller});

  final VideoPlayerController controller;

  @override
  State<LessonVideoFullscreenPage> createState() =>
      _LessonVideoFullscreenPageState();
}

class _LessonVideoFullscreenPageState extends State<LessonVideoFullscreenPage> {
  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations(kFullscreenOrientations);
  }

  @override
  void dispose() {
    // Back to the app defaults: all orientations the app allows, normal bars.
    SystemChrome.setPreferredOrientations(const []);
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    key: const Key('lesson-video-fullscreen'),
    backgroundColor: Colors.black,
    body: VideoSurface(
      controller: widget.controller,
      fullscreen: true,
      onFullscreen: () => Navigator.of(context).maybePop(),
    ),
  );
}

/// Video, play overlay and controls; shared by inline and fullscreen views.
class VideoSurface extends StatelessWidget {
  const VideoSurface({
    super.key,
    required this.controller,
    required this.fullscreen,
    required this.onFullscreen,
  });

  final VideoPlayerController controller;
  final bool fullscreen;

  /// Enters fullscreen (inline) or leaves it (fullscreen).
  final VoidCallback onFullscreen;

  static String _time(Duration value) {
    final minutes = value.inMinutes;
    final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (minutes < 60) return '$minutes:$seconds';
    final rest = minutes.remainder(60).toString().padLeft(2, '0');
    return '${value.inHours}:$rest:$seconds';
  }

  void _toggle() {
    final value = controller.value;
    if (!value.isInitialized) return;
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
  Widget build(
    BuildContext context,
  ) => ValueListenableBuilder<VideoPlayerValue>(
    valueListenable: controller,
    builder: (context, value, _) {
      final controls = Container(
        padding: EdgeInsets.fromLTRB(12, 18, 4, fullscreen ? 12 : 4),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.transparent, Colors.black.withValues(alpha: .55)],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: VideoProgressIndicator(
                controller,
                allowScrubbing: true,
                padding: const EdgeInsets.symmetric(vertical: 6),
                colors: VideoProgressColors(
                  playedColor: Colors.white,
                  bufferedColor: Colors.white.withValues(alpha: .35),
                  backgroundColor: Colors.white.withValues(alpha: .15),
                ),
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
                const SizedBox(width: 8),
                if (value.isBuffering)
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                const Spacer(),
                IconButton(
                  key: Key(
                    fullscreen
                        ? 'lesson-video-exit-fullscreen'
                        : 'lesson-video-fullscreen-button',
                  ),
                  tooltip: context.tr(
                    fullscreen
                        ? 'To‘liq ekrandan chiqish'
                        : 'To‘liq ekranda ko‘rish',
                  ),
                  color: Colors.white,
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    fullscreen ? LucideIcons.minimize : LucideIcons.maximize,
                    size: 20,
                  ),
                  onPressed: onFullscreen,
                ),
              ],
            ),
          ],
        ),
      );
      return GestureDetector(
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
                  width: fullscreen ? 68 : 56,
                  height: fullscreen ? 68 : 56,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: .45),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    LucideIcons.play,
                    color: Colors.white,
                    size: fullscreen ? 32 : 26,
                  ),
                ),
              ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: fullscreen
                  ? SafeArea(top: false, child: controls)
                  : controls,
            ),
          ],
        ),
      );
    },
  );
}
