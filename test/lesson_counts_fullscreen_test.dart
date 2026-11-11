import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myfit/services/lesson_video_service.dart';
import 'package:myfit/widgets/lesson_video_player.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

/// Minimal video platform: every video initialises as 1280x720, 2 minutes.
class FakeVideoPlatform extends VideoPlayerPlatform {
  final _events = <int, StreamController<VideoEvent>>{};
  final calls = <String>[];
  var _next = 0;

  @override
  Future<void> init() async {}

  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async {
    final id = _next++;
    _events[id] = StreamController<VideoEvent>();
    scheduleMicrotask(
      () => _events[id]!.add(
        VideoEvent(
          eventType: VideoEventType.initialized,
          duration: const Duration(minutes: 2),
          size: const Size(1280, 720),
        ),
      ),
    );
    return id;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) => _events[playerId]!.stream;

  @override
  Future<void> dispose(int playerId) async => _events.remove(playerId)?.close();

  @override
  Future<void> play(int playerId) async => calls.add('play');

  @override
  Future<void> pause(int playerId) async => calls.add('pause');

  @override
  Future<void> setLooping(int playerId, bool looping) async {}

  @override
  Future<void> setVolume(int playerId, double volume) async {}

  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}

  @override
  Future<void> seekTo(int playerId, Duration position) async {}

  @override
  Future<Duration> getPosition(int playerId) async => Duration.zero;

  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async {}

  @override
  Future<void> setPreventsDisplaySleepDuringVideoPlayback(
    int playerId,
    bool preventsDisplaySleepDuringVideoPlayback,
  ) async {}

  @override
  Widget buildViewWithOptions(VideoViewOptions options) =>
      const ColoredBox(key: Key('fake-video-view'), color: Colors.black);
}

void main() {
  group('lesson counts', () {
    test('emits once all categories report; errors count as 0', () async {
      final a = StreamController<int>();
      final b = StreamController<int>();
      final c = StreamController<int>();
      final values = <Map<String, int>>[];
      final sub = combineLessonCounts({
        'a': a.stream,
        'b': b.stream,
        'c': c.stream,
      }).listen(values.add);
      a.add(2);
      b.add(0);
      await pumpEventQueue();
      expect(values, isEmpty, reason: 'c has not reported yet');
      c.addError(StateError('permission-denied'));
      await pumpEventQueue();
      expect(values.last, {'a': 2, 'b': 0, 'c': 0});
      b.add(3);
      await pumpEventQueue();
      expect(values.last, {'a': 2, 'b': 3, 'c': 0});
      await sub.cancel();
      expect(a.hasListener || b.hasListener || c.hasListener, isFalse);
    });

    test('empty category list emits an empty map', () async {
      expect(await combineLessonCounts({}).first, isEmpty);
    });
  });

  group('fullscreen player', () {
    late FakeVideoPlatform platform;
    final systemCalls = <MethodCall>[];

    setUp(() {
      platform = FakeVideoPlatform();
      VideoPlayerPlatform.instance = platform;
      systemCalls.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            systemCalls.add(call);
            return null;
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    testWidgets('opens fullscreen, keeps playing and restores on exit', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LessonVideoPlayer(url: 'https://pub.r2.dev/lesson.mp4'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('lesson-video-player')), findsOneWidget);

      await tester.tap(find.byKey(const Key('lesson-video-player')));
      await tester.pump();
      expect(platform.calls.last, 'play');
      final callsBefore = [...platform.calls];

      await tester.tap(find.byKey(const Key('lesson-video-fullscreen-button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('lesson-video-fullscreen')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('lesson-video-fullscreen')),
          matching: find.byKey(const Key('fake-video-view')),
        ),
        findsOneWidget,
      );
      final methods = systemCalls.map((c) => c.method).toList();
      expect(methods, contains('SystemChrome.setEnabledSystemUIMode'));
      final orientation = systemCalls.lastWhere(
        (c) => c.method == 'SystemChrome.setPreferredOrientations',
      );
      expect(orientation.arguments, [
        'DeviceOrientation.landscapeLeft',
        'DeviceOrientation.landscapeRight',
      ]);
      expect(
        platform.calls,
        callsBefore,
        reason: 'same controller: no pause, no restart',
      );

      systemCalls.clear();
      await tester.tap(find.byKey(const Key('lesson-video-exit-fullscreen')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('lesson-video-fullscreen')), findsNothing);
      expect(find.byKey(const Key('lesson-video-player')), findsOneWidget);
      final restore = systemCalls.firstWhere(
        (c) => c.method == 'SystemChrome.setPreferredOrientations',
      );
      expect(restore.arguments, isEmpty);
      expect(
        systemCalls.map((c) => c.method),
        contains('SystemChrome.setEnabledSystemUIOverlays'),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('Android back button also leaves fullscreen', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LessonVideoPlayer(url: 'https://pub.r2.dev/lesson.mp4'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('lesson-video-fullscreen-button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('lesson-video-fullscreen')), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('lesson-video-fullscreen')), findsNothing);
      expect(find.byKey(const Key('lesson-video-player')), findsOneWidget);
    });
  });
}
