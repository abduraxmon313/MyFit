import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image_picker/image_picker.dart' show XFile;
import 'package:myfit/config/app_config.dart';
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

class _RealHttp extends HttpOverrides {}

class FakeLessonRepository implements LessonRepository {
  FakeLessonRepository({this.admin = false, this.lessons = const {}});

  final bool admin;
  final Map<String, List<CourseLesson>> lessons;

  @override
  Future<bool> isAdmin() async => admin;

  @override
  Stream<Map<String, int>> watchLessonCounts(List<String> categoryIds) =>
      Stream.value({
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
    String? replaceLessonId,
  }) async {
    calls.add(
      '$categoryId|$title|${file.name}'
      '${replaceLessonId == null ? '' : '|replace:$replaceLessonId'}',
    );
    onPhase?.call(LessonUploadPhase.uploading);
    onProgress?.call(50, 100);
    await finish.future;
    cancelToken?.throwIfCancelled();
    if (failWith != null) throw failWith!;
    return const UploadedLessonVideo(lessonId: 'l1', videoUrl: 'https://v/1');
  }

  final edits = <String>[];

  @override
  Future<void> updateLesson({
    required String categoryId,
    required String lessonId,
    required String title,
    String description = '',
  }) async {
    if (failWith != null) throw failWith!;
    edits.add('update|$categoryId|$lessonId|$title|$description');
  }

  @override
  Future<void> deleteLesson({
    required String categoryId,
    required String lessonId,
  }) async {
    if (failWith != null) throw failWith!;
    edits.add('delete|$categoryId|$lessonId');
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

  group('Worker API client', () {
    const api = 'https://myfit-video.example.workers.dev';

    test('sends the ID token as Bearer JSON and returns the body', () async {
      late http.Request seen;
      final client = MockClient((request) async {
        seen = request;
        return http.Response('{"uploadId":"u1"}', 200);
      });
      final uploader = LessonVideoUploader(
        apiBase: '$api/',
        idToken: ({bool forceRefresh = false}) async => 'id-token',
      );
      final result = await uploader.callApi(client, '/createVideoUpload', {
        'a': 1,
      });
      expect(result, {'uploadId': 'u1'});
      expect(seen.method, 'POST');
      expect(seen.url.toString(), '$api/createVideoUpload');
      expect(seen.headers['Authorization'], 'Bearer id-token');
      expect(jsonDecode(seen.body), {'a': 1});
    });

    test(
      'defaults to the central Worker URL for create and finalize',
      () async {
        expect(kVideoApiBaseUrl, 'https://myfit-video.myfit-app.workers.dev');
        final uploader = LessonVideoUploader(
          idToken: ({bool forceRefresh = false}) async => 't',
        );
        expect(uploader.apiBase, kVideoApiBaseUrl);
        final urls = <String>[];
        final client = MockClient((request) async {
          urls.add(request.url.toString());
          return http.Response('{}', 200);
        });
        await uploader.callApi(client, '/createVideoUpload', {});
        await uploader.callApi(client, '/finalizeVideoUpload', {});
        expect(urls, [
          'https://myfit-video.myfit-app.workers.dev/createVideoUpload',
          'https://myfit-video.myfit-app.workers.dev/finalizeVideoUpload',
        ]);
      },
    );

    test('refreshes an expired token once', () async {
      final tokens = <bool>[];
      var calls = 0;
      final client = MockClient((request) async {
        calls++;
        return calls == 1
            ? http.Response(
                '{"error":{"reason":"token-expired","message":"x"}}',
                401,
              )
            : http.Response('{"ok":true}', 200);
      });
      final uploader = LessonVideoUploader(
        apiBase: api,
        idToken: ({bool forceRefresh = false}) async {
          tokens.add(forceRefresh);
          return forceRefresh ? 'fresh' : 'stale';
        },
      );
      expect(await uploader.callApi(client, '/x', {}), {'ok': true});
      expect(tokens, [false, true]);
    });

    test('maps Worker errors, outages and missing config', () async {
      Future<String> reason(
        http.Response response, {
        String base = api,
        String? token = 't',
      }) async {
        try {
          await LessonVideoUploader(
            apiBase: base,
            idToken: ({bool forceRefresh = false}) async => token,
          ).callApi(MockClient((_) async => response), '/x', {});
          return 'ok';
        } on LessonVideoException catch (error) {
          return error.reason;
        }
      }

      final ok = http.Response('{}', 200);
      expect(
        await reason(
          http.Response('{"error":{"reason":"not-admin","message":"m"}}', 403),
        ),
        'not-admin',
      );
      expect(
        await reason(
          http.Response('{"error":{"reason":"not-h264","message":"m"}}', 400),
        ),
        'not-h264',
      );
      expect(
        await reason(
          http.Response(
            '{"error":{"reason":"invalid-token","message":"m"}}',
            401,
          ),
        ),
        'sign-in-required',
      );
      expect(await reason(http.Response('<html>', 502)), 'network');
      expect(await reason(ok, base: ''), 'not-configured');
      expect(
        await reason(ok, base: 'http://insecure.example'),
        'not-configured',
      );
      expect(await reason(ok, token: null), 'sign-in-required');
    });

    test(
      'full upload: create → direct PUT → finalize, token never sent to R2',
      () async {
        final bytes = mp4Bytes();
        final log = <String>[];
        final client = MockClient.streaming((request, body) async {
          final data = await body.toBytes();
          log.add('${request.method} ${request.url.host}${request.url.path}');
          if (request.url.host == 'r2.example') {
            expect(request.headers.containsKey('Authorization'), isFalse);
            expect(request.headers['Content-Type'], 'video/mp4');
            expect(request.contentLength, bytes.length);
            expect(data, bytes);
            return http.StreamedResponse(const Stream.empty(), 200);
          }
          expect(request.headers['Authorization'], 'Bearer tok');
          final json = jsonDecode(utf8.decode(data)) as Map;
          final reply = request.url.path == '/createVideoUpload'
              ? {
                  'uploadId': 'up1',
                  'uploadUrl':
                      'https://r2.example/myfit-videos/k.mp4?X-Amz-Signature=s',
                  'headers': {'Content-Type': 'video/mp4'},
                  'sizeEcho': json['sizeBytes'],
                }
              : {'lessonId': 'l9', 'videoUrl': 'https://pub.r2.dev/k.mp4'};
          if (request.url.path == '/createVideoUpload') {
            expect(json['sizeBytes'], bytes.length);
            expect(json['categoryId'], 'cardio');
            expect(json.containsKey('uid'), isFalse);
          } else {
            expect(json, {'uploadId': 'up1'});
          }
          return http.StreamedResponse(
            Stream.value(utf8.encode(jsonEncode(reply))),
            200,
          );
        });
        final phases = <LessonUploadPhase>[];
        var lastProgress = 0;
        final result =
            await LessonVideoUploader(
              client: client,
              apiBase: api,
              idToken: ({bool forceRefresh = false}) async => 'tok',
            ).upload(
              categoryId: 'cardio',
              title: ' Isinish ',
              file: XFile.fromData(bytes, name: 'a.mp4', path: '/x/a.mp4'),
              onPhase: phases.add,
              onProgress: (sent, total) => lastProgress = sent,
            );
        expect(result.lessonId, 'l9');
        expect(log, [
          'POST myfit-video.example.workers.dev/createVideoUpload',
          'PUT r2.example/myfit-videos/k.mp4',
          'POST myfit-video.example.workers.dev/finalizeVideoUpload',
        ]);
        expect(phases, LessonUploadPhase.values);
        expect(lastProgress, bytes.length);
      },
    );

    test('dart:io client sends the exact Content-Length, not chunked', () {
      // flutter_test blocks real HTTP; this zone restores dart:io's client,
      // which is what package:http uses on Android and iOS.
      return HttpOverrides.runWithHttpOverrides(() async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        final seen = Completer<HttpHeaders>();
        var received = 0;
        server.listen((request) async {
          await request.forEach((chunk) => received += chunk.length);
          seen.complete(request.headers);
          request.response.statusCode = 200;
          await request.response.close();
        });
        const size = 3 * 1024 * 1024 + 7;
        final client = http.Client();
        try {
          await putLessonVideo(
            client: client,
            url: Uri.parse('http://127.0.0.1:${server.port}/k.mp4'),
            headers: const {'Content-Type': 'video/mp4'},
            body: Stream.fromIterable([
              for (var i = 0; i < size; i += 65536)
                Uint8List(i + 65536 > size ? size - i : 65536),
            ]),
            length: size,
          );
          final headers = await seen.future;
          expect(headers.value('content-length'), '$size');
          expect(headers.value('transfer-encoding'), isNull);
          expect(headers.contentType?.mimeType, 'video/mp4');
          expect(received, size);
        } finally {
          client.close();
          await server.close(force: true);
        }
      }, _RealHttp());
    });
  });

  test('backend category ids match the app categories', () {
    final source = File('workers/video/src/uploads.ts').readAsStringSync();
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

  group('admin lesson editing', () {
    const course = TrainerCourse(
      id: 'cardio',
      title: 'Ozish uchun kardio mashqlar',
      description: '',
      lessons: [],
    );
    const uploaded = CourseLesson(
      id: 'l7',
      order: 1,
      title: 'Isinish',
      description: 'Eski tavsif',
      videoUrl: 'https://pub.r2.dev/lessons/cardio/1.mp4',
      storageProvider: 'r2',
    );

    Future<void> pumpCategory(
      WidgetTester tester,
      FakeUploader uploader, {
      bool admin = true,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: LessonCategoryPage(
            course: course,
            uploader: uploader,
            repository: FakeLessonRepository(
              admin: admin,
              lessons: {
                'cardio': const [uploaded],
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('non-admins see no edit menu', (tester) async {
      await pumpCategory(tester, FakeUploader(), admin: false);
      expect(find.byKey(const Key('lesson-menu-l7')), findsNothing);
    });

    testWidgets('edit changes title and description without a new video', (
      tester,
    ) async {
      final uploader = FakeUploader();
      await pumpCategory(tester, uploader);
      await tester.tap(find.byKey(const Key('lesson-menu-l7')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('lesson-edit')));
      await tester.pumpAndSettle();
      expect(find.text('Darsni tahrirlash'), findsOneWidget);
      expect(find.text('Isinish'), findsWidgets);
      // Saving is allowed without choosing a new video.
      final save = find.byKey(const Key('upload-start'));
      expect(tester.widget<FilledButton>(save).onPressed, isNotNull);
      await tester.enterText(
        find.byKey(const Key('upload-title')),
        'Yangi nom',
      );
      await tester.enterText(
        find.byKey(const Key('upload-description')),
        'Yangi tavsif',
      );
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(uploader.edits, ['update|cardio|l7|Yangi nom|Yangi tavsif']);
      expect(uploader.calls, isEmpty);
      expect(find.text('Dars yangilandi'), findsOneWidget);
    });

    testWidgets('edit with a new video replaces this lesson', (tester) async {
      final uploader = FakeUploader()..finish.complete();
      final bytes = mp4Bytes();
      await tester.pumpWidget(
        MaterialApp(
          home: VideoUploadPage(
            category: course,
            uploader: uploader,
            lesson: uploaded,
            pickVideo: () async =>
                XFile.fromData(bytes, name: 'new.mp4', path: '/picked/new.mp4'),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('upload-pick')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('upload-start')));
      await tester.pumpAndSettle();
      expect(uploader.calls, ['cardio|Isinish|new.mp4|replace:l7']);
      expect(uploader.edits, isEmpty);
    });

    testWidgets('delete asks for confirmation, then deletes', (tester) async {
      final uploader = FakeUploader();
      await pumpCategory(tester, uploader);
      Future<void> openDelete() async {
        await tester.tap(find.byKey(const Key('lesson-menu-l7')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('lesson-delete')));
        await tester.pumpAndSettle();
      }

      await openDelete();
      expect(find.text('Darsni o‘chirasizmi?'), findsOneWidget);
      await tester.tap(find.text('Bekor qilish'));
      await tester.pumpAndSettle();
      expect(uploader.edits, isEmpty);

      await openDelete();
      await tester.tap(find.byKey(const Key('lesson-delete-confirm')));
      await tester.pumpAndSettle();
      expect(uploader.edits, ['delete|cardio|l7']);
      expect(find.text('Dars o‘chirildi'), findsOneWidget);
    });

    testWidgets('a failed delete shows the reason', (tester) async {
      final uploader = FakeUploader(
        failWith: const LessonVideoException('not-admin'),
      );
      await pumpCategory(tester, uploader);
      await tester.tap(find.byKey(const Key('lesson-menu-l7')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('lesson-delete')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('lesson-delete-confirm')));
      await tester.pumpAndSettle();
      expect(find.text('Video yuklash faqat adminlar uchun.'), findsOneWidget);
    });

    test('uploader sends edit and delete requests to the Worker', () async {
      final seen = <String>[];
      final client = MockClient((request) async {
        seen.add('${request.url.path} ${request.body}');
        return http.Response('{}', 200);
      });
      final uploader = LessonVideoUploader(
        client: client,
        apiBase: 'https://w.example',
        idToken: ({bool forceRefresh = false}) async => 't',
      );
      await uploader.updateLesson(
        categoryId: 'cardio',
        lessonId: 'l7',
        title: ' Nom ',
        description: 'Tavsif',
      );
      await uploader.deleteLesson(categoryId: 'cardio', lessonId: 'l7');
      expect(seen, [
        '/updateLesson {"categoryId":"cardio","lessonId":"l7","title":"Nom","description":"Tavsif"}',
        '/deleteLesson {"categoryId":"cardio","lessonId":"l7"}',
      ]);
    });
  });
}
