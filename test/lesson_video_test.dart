import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image_picker/image_picker.dart' show XFile;
import 'package:myfit/data/trainer_course.dart';
import 'package:myfit/models/trainer_course.dart';
import 'package:myfit/screens/lessons_page.dart';
import 'package:myfit/screens/video_upload_page.dart';
import 'package:myfit/services/lesson_video_service.dart';
import 'package:myfit/services/mp4_inspector.dart';

// ------------------------------------------------------------ MP4 fixtures

Uint8List _u32(int value) =>
    Uint8List(4)..buffer.asByteData().setUint32(0, value);

Uint8List _box(String type, List<Uint8List> payloads) {
  final body = payloads.expand((part) => part).toList();
  return Uint8List.fromList([
    ..._u32(8 + body.length),
    ...ascii.encode(type),
    ...body,
  ]);
}

Uint8List _fullBox() => Uint8List(4);

Uint8List _trak(String handler, String codec) => _box('trak', [
  _box('tkhd', [_fullBox(), Uint8List(80)]),
  _box('mdia', [
    _box('mdhd', [_fullBox(), Uint8List(20)]),
    _box('hdlr', [_fullBox(), _u32(0), ascii.encode(handler), Uint8List(13)]),
    _box('minf', [
      _box('stbl', [
        _box('stsd', [
          _fullBox(),
          _u32(1),
          _box(codec, [Uint8List(78)]),
        ]),
      ]),
    ]),
  ]),
]);

Uint8List mp4Bytes({
  String brand = 'isom',
  String codec = 'avc1',
  bool moovFirst = false,
  double seconds = 125,
}) {
  final ftyp = _box('ftyp', [
    ascii.encode(brand),
    _u32(0),
    ascii.encode('isommp41'),
  ]);
  final moov = _box('moov', [
    _box('mvhd', [
      _fullBox(),
      _u32(0),
      _u32(0),
      _u32(1000),
      _u32((seconds * 1000).round()),
      Uint8List(80),
    ]),
    _trak('soun', 'mp4a'),
    _trak('vide', codec),
  ]);
  final mdat = _box('mdat', [Uint8List(4096)..fillRange(0, 4096, 9)]);
  return Uint8List.fromList(
    moovFirst ? [...ftyp, ...moov, ...mdat] : [...ftyp, ...mdat, ...moov],
  );
}

Mp4ReadAt _reader(Uint8List bytes) =>
    (offset, length) async =>
        Uint8List.sublistView(bytes, offset, offset + length);

// ------------------------------------------------------------------ fakes

class FakeLessonRepository implements LessonRepository {
  FakeLessonRepository({this.admin = false, this.lessons = const {}});

  final bool admin;
  final Map<String, List<CourseLesson>> lessons;

  @override
  Future<bool> isAdmin() async => admin;

  @override
  Stream<Map<String, int>> watchLessonCounts() => Stream.value({
    for (final entry in lessons.entries) entry.key: entry.value.length,
  });

  @override
  Stream<List<CourseLesson>> watchLessons(String categoryId) =>
      Stream.value(lessons[categoryId] ?? const []);
}

class FakeUploader extends LessonVideoUploader {
  FakeUploader({this.failWith});

  final LessonVideoException? failWith;
  final calls = <String>[];
  final finish = Completer<void>();

  @override
  Future<UploadedLessonVideo> upload({
    required String categoryId,
    required String title,
    String description = '',
    required XFile file,
    UploadProgress? onProgress,
    void Function(LessonUploadPhase phase)? onPhase,
    UploadCancelToken? cancelToken,
  }) async {
    calls.add('$categoryId|$title|${file.name}');
    onPhase?.call(LessonUploadPhase.uploading);
    onProgress?.call(50, 100);
    await finish.future;
    cancelToken?.throwIfCancelled();
    if (failWith != null) throw failWith!;
    return const UploadedLessonVideo(lessonId: 'l1', videoUrl: 'https://v/1');
  }
}

void main() {
  group('MP4 inspection', () {
    test('accepts H.264 with moov at the end or the start', () async {
      for (final moovFirst in [false, true]) {
        final bytes = mp4Bytes(moovFirst: moovFirst);
        final info = await inspectMp4(_reader(bytes), bytes.length);
        expect(info.videoCodec, 'avc1');
        expect(info.durationSeconds, 125);
      }
    });

    test('rejects HEVC, QuickTime and non-video files', () async {
      Future<String> reason(Uint8List bytes) async {
        try {
          await inspectMp4(_reader(bytes), bytes.length);
          return 'ok';
        } on Mp4Exception catch (error) {
          return error.reason;
        }
      }

      expect(await reason(mp4Bytes(codec: 'hvc1')), 'not-h264');
      expect(await reason(mp4Bytes(brand: 'qt  ')), 'unsupported-format');
      expect(
        await reason(Uint8List.fromList(utf8.encode('not a video file'))),
        'unsupported-format',
      );
    });
  });

  group('upload validation', () {
    Future<String> reason({
      String name = 'lesson.mp4',
      String? mime,
      int? size,
      Uint8List? bytes,
    }) async {
      final data = bytes ?? mp4Bytes();
      var reads = 0;
      try {
        await validateLessonVideo(
          fileName: name,
          mimeType: mime,
          sizeBytes: size ?? data.length,
          readAt: (offset, length) {
            reads++;
            return _reader(data)(offset, length);
          },
        );
        return 'ok';
      } on LessonVideoException catch (error) {
        return reads == 0 ? '${error.reason} (no read)' : error.reason;
      }
    }

    test('accepts an H.264 MP4 up to exactly 2 GB', () async {
      expect(await reason(), 'ok');
      expect(await reason(name: 'clip', mime: 'video/mp4'), 'ok');
    });

    test('checks extension and size before reading the file', () async {
      expect(await reason(name: 'clip.mov'), 'unsupported-format (no read)');
      expect(await reason(size: 0), 'empty-file (no read)');
      expect(
        await reason(size: kMaxLessonVideoBytes + 1),
        'too-large (no read)',
      );
      expect(kMaxLessonVideoBytes, 2 * 1024 * 1024 * 1024);
    });

    test('rejects non-H.264 video', () async {
      expect(await reason(bytes: mp4Bytes(codec: 'hvc1')), 'not-h264');
    });

    test('reads only the requested range of an XFile', () async {
      final bytes = mp4Bytes();
      final file = XFile.fromData(bytes, name: 'a.mp4');
      final part = await readXFileRange(file, 4, 4);
      expect(ascii.decode(part), 'ftyp');
    });
  });

  group('direct R2 PUT', () {
    test('streams the body with headers and reports progress', () async {
      final bytes = Uint8List.fromList(List.generate(300000, (i) => i % 251));
      late http.BaseRequest seen;
      final received = <int>[];
      final client = MockClient.streaming((request, body) async {
        seen = request;
        await body.forEach(received.addAll);
        return http.StreamedResponse(const Stream.empty(), 200);
      });
      final progress = <int>[];
      await putLessonVideo(
        client: client,
        url: Uri.parse('https://r2.example/key?X-Amz-Signature=s'),
        headers: {'Content-Type': 'video/mp4'},
        body: Stream.fromIterable([
          for (var i = 0; i < bytes.length; i += 65536)
            bytes.sublist(
              i,
              i + 65536 > bytes.length ? bytes.length : i + 65536,
            ),
        ]),
        length: bytes.length,
        onProgress: (sent, total) => progress.add(sent),
      );
      expect(seen.method, 'PUT');
      expect(seen.headers['Content-Type'], 'video/mp4');
      expect(seen.contentLength, bytes.length);
      expect(received, bytes);
      expect(progress.last, bytes.length);
      expect(progress, orderedEquals([...progress]..sort()));
    });

    test('maps HTTP errors and cancellation', () async {
      final failing = MockClient.streaming((request, body) async {
        await body.drain<void>();
        return http.StreamedResponse(
          Stream.value(utf8.encode('<Error>SignatureDoesNotMatch</Error>')),
          403,
        );
      });
      Future<String> run(http.Client client, {UploadCancelToken? token}) async {
        try {
          await putLessonVideo(
            client: client,
            url: Uri.parse('https://r2.example/key'),
            headers: const {},
            body: Stream.value([1, 2, 3]),
            length: 3,
            cancelToken: token,
          );
          return 'ok';
        } on LessonVideoException catch (error) {
          return error.reason;
        }
      }

      expect(await run(failing), 'upload-failed');
      final cancelled = UploadCancelToken()..cancel();
      var called = false;
      final client = MockClient.streaming((request, body) async {
        called = true;
        return http.StreamedResponse(const Stream.empty(), 200);
      });
      expect(await run(client, token: cancelled), 'cancelled');
      expect(called, isFalse);
      final offline = MockClient.streaming(
        (request, body) => throw http.ClientException('Connection reset'),
      );
      expect(await run(offline), 'network');
    });
  });

  test('backend category ids match the app categories', () {
    final source = File('functions/r2_video.js').readAsStringSync();
    final block = RegExp(
      r'LESSON_CATEGORY_IDS = Object\.freeze\(\[([\s\S]*?)\]\)',
    ).firstMatch(source)!.group(1)!;
    final ids = RegExp(r'"([^"]+)"').allMatches(block).map((m) => m.group(1));
    expect(ids.toList(), kLessonCategories.map((c) => c.id).toList());
  });

  testWidgets('lesson counts come from the repository', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 1400);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = FakeLessonRepository(
      lessons: {
        'fullbody': const [
          CourseLesson(id: 'a', order: 1, title: 'A', description: ''),
          CourseLesson(id: 'b', order: 2, title: 'B', description: ''),
        ],
      },
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: LessonsPage(repository: repository)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('2 ta video'), findsOneWidget);
    expect(find.text('Videolar tez orada'), findsNWidgets(12));
  });

  testWidgets('only admins see the upload button', (tester) async {
    const course = TrainerCourse(
      id: 'fullbody',
      title: 'FullBody mashqlar',
      description: '',
      lessons: [],
    );
    for (final admin in [false, true]) {
      await tester.pumpWidget(
        MaterialApp(
          key: ValueKey(admin),
          home: LessonCategoryPage(
            course: course,
            repository: FakeLessonRepository(admin: admin),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('category-upload')),
        admin ? findsOneWidget : findsNothing,
      );
    }
  });

  testWidgets('uploaded lessons are listed in order and play their URL', (
    tester,
  ) async {
    const course = TrainerCourse(
      id: 'cardio',
      title: 'Ozish uchun kardio mashqlar',
      description: '',
      lessons: [],
    );
    final repository = FakeLessonRepository(
      lessons: {
        'cardio': const [
          CourseLesson(
            id: 'second',
            order: 2,
            title: 'Interval',
            description: '',
            videoUrl: 'https://pub.r2.dev/lessons/cardio/2.mp4',
          ),
          CourseLesson(
            id: 'first',
            order: 1,
            title: 'Isinish',
            description: '',
            videoUrl: 'https://pub.r2.dev/lessons/cardio/1.mp4',
            storageProvider: 'r2',
          ),
        ],
      },
    );
    await tester.pumpWidget(
      MaterialApp(
        home: LessonCategoryPage(course: course, repository: repository),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.byKey(const Key('lesson-first'))).dy,
      lessThan(tester.getTopLeft(find.byKey(const Key('lesson-second'))).dy),
    );

    // The detail page uses the lesson URL; the player is replaced in tests.
    final ordered = course
        .withLessons(await repository.watchLessons('cardio').first)
        .orderedLessons;
    await tester.pumpWidget(
      MaterialApp(
        home: LessonPage(
          course: course.withLessons(ordered),
          index: 0,
          playerBuilder: (lesson) => Text('player:${lesson.videoUrl}'),
        ),
      ),
    );
    expect(
      find.text('player:https://pub.r2.dev/lessons/cardio/1.mp4'),
      findsOneWidget,
    );
    await tester.tap(find.text('Keyingi'));
    await tester.pumpAndSettle();
    expect(
      find.text('player:https://pub.r2.dev/lessons/cardio/2.mp4'),
      findsOneWidget,
    );
  });

  group('upload screen', () {
    const course = TrainerCourse(
      id: 'superset',
      title: 'SuperSet mashqlar',
      description: '',
      lessons: [],
    );

    Future<void> pumpUpload(
      WidgetTester tester,
      FakeUploader uploader,
      Uint8List bytes, {
      String name = 'set.mp4',
      List<bool?>? results,
    }) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 900);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () async {
                    final result = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => VideoUploadPage(
                          category: course,
                          uploader: uploader,
                          // Like image_picker: the name comes from the path.
                          pickVideo: () async => XFile.fromData(
                            bytes,
                            name: name,
                            path: '/picked/$name',
                          ),
                        ),
                      ),
                    );
                    results?.add(result);
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('validates, shows progress and returns on success', (
      tester,
    ) async {
      final uploader = FakeUploader();
      final results = <bool?>[];
      await pumpUpload(tester, uploader, mp4Bytes(), results: results);

      final start = find.byKey(const Key('upload-start'));
      expect(tester.widget<FilledButton>(start).onPressed, isNull);
      await tester.tap(find.byKey(const Key('upload-pick')));
      await tester.pumpAndSettle();
      expect(find.text('set.mp4'), findsOneWidget);

      await tester.tap(start);
      await tester.pump();
      expect(find.text('Dars nomini kiriting (2–120 belgi).'), findsOneWidget);
      expect(uploader.calls, isEmpty);

      await tester.enterText(find.byKey(const Key('upload-title')), '1-dars');
      await tester.tap(start);
      await tester.pump();
      expect(uploader.calls, ['superset|1-dars|set.mp4']);
      expect(find.byKey(const Key('upload-progress')), findsOneWidget);
      expect(find.textContaining('50%'), findsOneWidget);
      expect(find.byKey(const Key('upload-cancel')), findsOneWidget);

      uploader.finish.complete();
      await tester.pumpAndSettle();
      expect(results, [true]);
      expect(find.byType(VideoUploadPage), findsNothing);
    });

    testWidgets('rejects a non-H.264 file before upload', (tester) async {
      final uploader = FakeUploader();
      await pumpUpload(tester, uploader, mp4Bytes(codec: 'hvc1'));
      await tester.tap(find.byKey(const Key('upload-pick')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('upload-error')), findsOneWidget);
      expect(
        find.text(
          'Video H.264 kodekida bo‘lishi kerak. Videoni H.264 MP4 qilib eksport qiling.',
        ),
        findsOneWidget,
      );
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('upload-start')))
            .onPressed,
        isNull,
      );
    });

    testWidgets('cancel stops the upload and keeps the page open', (
      tester,
    ) async {
      final uploader = FakeUploader();
      await pumpUpload(tester, uploader, mp4Bytes());
      await tester.tap(find.byKey(const Key('upload-pick')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('upload-title')), '2-dars');
      await tester.tap(find.byKey(const Key('upload-start')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('upload-cancel')));
      uploader.finish.complete();
      await tester.pumpAndSettle();
      expect(find.byType(VideoUploadPage), findsOneWidget);
      expect(find.text('Yuklash bekor qilindi.'), findsOneWidget);
      expect(find.byKey(const Key('upload-start')), findsOneWidget);
    });

    testWidgets('server rejection is shown in the selected language', (
      tester,
    ) async {
      final uploader = FakeUploader(
        failWith: const LessonVideoException('not-admin'),
      );
      await pumpUpload(tester, uploader, mp4Bytes());
      await tester.tap(find.byKey(const Key('upload-pick')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('upload-title')), '3-dars');
      await tester.tap(find.byKey(const Key('upload-start')));
      uploader.finish.complete();
      await tester.pumpAndSettle();
      expect(find.text('Video yuklash faqat adminlar uchun.'), findsOneWidget);
    });
  });
}
