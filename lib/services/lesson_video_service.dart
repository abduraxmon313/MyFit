import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart' show XFile;

import '../config/app_config.dart';
import '../models/trainer_course.dart';
import 'mp4_inspector.dart';

/// Upload limit; the backend enforces the same value.
const kMaxLessonVideoBytes = 2 * 1024 * 1024 * 1024;
const kLessonVideoContentType = 'video/mp4';

/// Video upload or validation failure.
///
/// [reason] matches the backend `details.reason` values, plus the client-side
/// `cancelled`, `network`, `upload-failed` and `not-configured`.
class LessonVideoException implements Exception {
  const LessonVideoException(this.reason, [this.detail]);

  final String reason;
  final String? detail;

  @override
  String toString() =>
      'LessonVideoException($reason${detail == null ? '' : ': $detail'})';
}

/// Validates name, size and codec before anything is uploaded.
Future<Mp4Info> validateLessonVideo({
  required String fileName,
  String? mimeType,
  required int sizeBytes,
  required Mp4ReadAt readAt,
}) async {
  final isMp4 =
      fileName.toLowerCase().endsWith('.mp4') ||
      mimeType?.toLowerCase() == kLessonVideoContentType;
  if (!isMp4) throw const LessonVideoException('unsupported-format');
  if (sizeBytes <= 0) throw const LessonVideoException('empty-file');
  if (sizeBytes > kMaxLessonVideoBytes) {
    throw const LessonVideoException('too-large');
  }
  try {
    return await inspectMp4(readAt, sizeBytes);
  } on Mp4Exception catch (error) {
    throw LessonVideoException(error.reason, error.message);
  }
}

/// Reads [length] bytes of [file] from [offset] without loading the rest.
Future<Uint8List> readXFileRange(XFile file, int offset, int length) async {
  final builder = BytesBuilder(copy: false);
  await for (final chunk in file.openRead(offset, offset + length)) {
    builder.add(chunk);
  }
  return builder.takeBytes();
}

/// Lets the user stop an upload in progress.
class UploadCancelToken {
  final _completer = Completer<void>();

  bool get isCancelled => _completer.isCompleted;
  Future<void> get whenCancelled => _completer.future;

  void cancel() {
    if (!_completer.isCompleted) _completer.complete();
  }

  void throwIfCancelled() {
    if (isCancelled) throw const LessonVideoException('cancelled');
  }
}

typedef UploadProgress = void Function(int sentBytes, int totalBytes);

enum LessonUploadPhase { validating, uploading, finalizing }

/// Streaming PUT body; the file is read chunk by chunk, never buffered whole.
class _StreamingPut extends http.BaseRequest implements http.Abortable {
  _StreamingPut(Uri url, this._body, {this.abortTrigger}) : super('PUT', url);

  final Stream<List<int>> _body;

  @override
  final Future<void>? abortTrigger;

  @override
  http.ByteStream finalize() {
    super.finalize();
    return http.ByteStream(_body);
  }
}

/// Uploads [body] to a presigned R2 URL with progress and cancellation.
Future<void> putLessonVideo({
  required http.Client client,
  required Uri url,
  required Map<String, String> headers,
  required Stream<List<int>> body,
  required int length,
  UploadProgress? onProgress,
  UploadCancelToken? cancelToken,
}) async {
  cancelToken?.throwIfCancelled();
  var sent = 0;
  final counted = body.map((chunk) {
    sent += chunk.length;
    onProgress?.call(sent > length ? length : sent, length);
    return chunk;
  });
  final request =
      _StreamingPut(url, counted, abortTrigger: cancelToken?.whenCancelled)
        ..headers.addAll(headers)
        ..contentLength = length;
  try {
    final response = await client.send(request);
    final body = await response.stream.bytesToString();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw LessonVideoException(
        'upload-failed',
        'HTTP ${response.statusCode}: ${body.length > 300 ? body.substring(0, 300) : body}',
      );
    }
  } on http.RequestAbortedException {
    throw const LessonVideoException('cancelled');
  } on http.ClientException catch (error) {
    if (cancelToken?.isCancelled ?? false) {
      throw const LessonVideoException('cancelled');
    }
    throw LessonVideoException('network', error.message);
  }
}

/// Result of a finished upload.
class UploadedLessonVideo {
  const UploadedLessonVideo({required this.lessonId, required this.videoUrl});

  final String lessonId;
  final String videoUrl;
}

/// Returns the signed-in user's Firebase ID token (`null` when signed out).
typedef IdTokenProvider = Future<String?> Function({bool forceRefresh});

Future<String?> _firebaseIdToken({bool forceRefresh = false}) async =>
    FirebaseAuth.instance.currentUser?.getIdToken(forceRefresh);

/// Admin upload flow: Worker presigned URL → direct PUT to R2 → Worker
/// verification (R2 head + MP4 check) → Firestore lesson.
///
/// Every Worker call carries the Firebase ID token; the Worker verifies it
/// and checks `admins/{uid}`. R2 credentials never reach the app.
class LessonVideoUploader {
  LessonVideoUploader({this.client, String? apiBase, IdTokenProvider? idToken})
    : apiBase = apiBase ?? kVideoApiBaseUrl,
      idToken = idToken ?? _firebaseIdToken;

  /// Defaults to a new client per upload.
  final http.Client? client;
  final String apiBase;
  final IdTokenProvider idToken;

  Future<UploadedLessonVideo> upload({
    required String categoryId,
    required String title,
    String description = '',
    required XFile file,
    UploadProgress? onProgress,
    void Function(LessonUploadPhase phase)? onPhase,
    UploadCancelToken? cancelToken,

    /// Swap the video of this existing lesson (keeps its id and order).
    String? replaceLessonId,
  }) async {
    onPhase?.call(LessonUploadPhase.validating);
    final size = await file.length();
    await validateLessonVideo(
      fileName: file.name,
      mimeType: file.mimeType,
      sizeBytes: size,
      readAt: (offset, length) => readXFileRange(file, offset, length),
    );
    cancelToken?.throwIfCancelled();

    final httpClient = client ?? http.Client();
    try {
      final session = await callApi(httpClient, '/createVideoUpload', {
        'categoryId': categoryId,
        'title': title.trim(),
        'description': description.trim(),
        'fileName': file.name.toLowerCase().endsWith('.mp4')
            ? file.name
            : 'video.mp4',
        'contentType': kLessonVideoContentType,
        'sizeBytes': size,
        'replaceLessonId': ?replaceLessonId,
      }, timeout: const Duration(seconds: 30));
      final uploadId = session['uploadId'] as String;
      final headers = <String, String>{
        for (final entry in (session['headers'] as Map? ?? const {}).entries)
          '${entry.key}': '${entry.value}',
      };
      cancelToken?.throwIfCancelled();

      onPhase?.call(LessonUploadPhase.uploading);
      await putLessonVideo(
        client: httpClient,
        url: Uri.parse(session['uploadUrl'] as String),
        headers: headers,
        body: file.openRead(),
        length: size,
        onProgress: onProgress,
        cancelToken: cancelToken,
      );
      cancelToken?.throwIfCancelled();

      onPhase?.call(LessonUploadPhase.finalizing);
      final result = await callApi(httpClient, '/finalizeVideoUpload', {
        'uploadId': uploadId,
      }, timeout: const Duration(seconds: 90));
      return UploadedLessonVideo(
        lessonId: result['lessonId'] as String,
        videoUrl: result['videoUrl'] as String,
      );
    } finally {
      if (client == null) httpClient.close();
    }
  }

  /// Changes the title and description of a lesson (admin).
  Future<void> updateLesson({
    required String categoryId,
    required String lessonId,
    required String title,
    String description = '',
  }) => _withClient(
    (httpClient) => callApi(httpClient, '/updateLesson', {
      'categoryId': categoryId,
      'lessonId': lessonId,
      'title': title.trim(),
      'description': description.trim(),
    }),
  );

  /// Deletes a lesson and its video; later lessons move up (admin).
  Future<void> deleteLesson({
    required String categoryId,
    required String lessonId,
  }) => _withClient(
    (httpClient) => callApi(httpClient, '/deleteLesson', {
      'categoryId': categoryId,
      'lessonId': lessonId,
    }),
  );

  Future<void> _withClient(
    Future<Object?> Function(http.Client client) run,
  ) async {
    final httpClient = client ?? http.Client();
    try {
      await run(httpClient);
    } finally {
      if (client == null) httpClient.close();
    }
  }

  /// POSTs JSON to the Worker with the ID token; retries once with a
  /// refreshed token when the Worker reports an expired/invalid token.
  Future<Map<String, dynamic>> callApi(
    http.Client httpClient,
    String path,
    Map<String, Object?> body, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final base = apiBase.trim().replaceAll(RegExp(r'/+$'), '');
    if (!base.startsWith('https://')) {
      throw const LessonVideoException('not-configured');
    }
    final uri = Uri.parse('$base$path');
    for (var attempt = 0; ; attempt++) {
      final String? token;
      try {
        token = await idToken(forceRefresh: attempt > 0);
      } catch (error) {
        throw LessonVideoException('sign-in-required', '$error');
      }
      if (token == null || token.isEmpty) {
        throw const LessonVideoException('sign-in-required');
      }
      final http.Response response;
      try {
        response = await httpClient
            .post(
              uri,
              headers: {
                'Authorization': 'Bearer $token',
                'Content-Type': 'application/json',
              },
              body: jsonEncode(body),
            )
            .timeout(timeout);
      } on TimeoutException {
        throw const LessonVideoException('network', 'timeout');
      } on http.ClientException catch (error) {
        throw LessonVideoException('network', error.message);
      }
      Object? decoded;
      try {
        decoded = jsonDecode(utf8.decode(response.bodyBytes));
      } catch (_) {
        decoded = null;
      }
      if (response.statusCode == 200 && decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
      final error = decoded is Map ? decoded['error'] : null;
      final reason = error is Map && error['reason'] is String
          ? error['reason'] as String
          : switch (response.statusCode) {
              401 => 'sign-in-required',
              403 => 'not-admin',
              429 || 502 || 503 || 504 => 'network',
              _ => 'internal',
            };
      final retryable = reason == 'token-expired' || reason == 'invalid-token';
      if (response.statusCode == 401 && retryable && attempt == 0) continue;
      throw LessonVideoException(
        reason == 'token-expired' || reason == 'invalid-token'
            ? 'sign-in-required'
            : reason,
        error is Map ? '${error['message']}' : 'HTTP ${response.statusCode}',
      );
    }
  }
}

/// Lesson data source for the "Darslar" tab.
abstract class LessonRepository {
  /// Lessons of one category, ordered by `order`.
  Stream<List<CourseLesson>> watchLessons(String categoryId);

  /// Number of lessons for each of [categoryIds].
  Stream<Map<String, int>> watchLessonCounts(List<String> categoryIds);

  /// Whether the signed-in user has an `admins/{uid}` document.
  Future<bool> isAdmin();
}

/// Used when Firebase is not initialised (tests, previews).
class EmptyLessonRepository implements LessonRepository {
  const EmptyLessonRepository();

  @override
  Stream<List<CourseLesson>> watchLessons(String categoryId) =>
      Stream.value(const []);

  @override
  Stream<Map<String, int>> watchLessonCounts(List<String> categoryIds) =>
      Stream.value(const {});

  @override
  Future<bool> isAdmin() async => false;
}

/// Merges per-category counts into one map. Emits once every category has
/// reported (a failing category counts as 0), then on each change.
Stream<Map<String, int>> combineLessonCounts(Map<String, Stream<int>> sources) {
  late final StreamController<Map<String, int>> controller;
  final subscriptions = <StreamSubscription<int>>[];
  final counts = <String, int>{};
  final reported = <String>{};

  void report(String id, int count) {
    counts[id] = count;
    reported.add(id);
    if (reported.length == sources.length && !controller.isClosed) {
      controller.add(Map.unmodifiable(counts));
    }
  }

  controller = StreamController<Map<String, int>>(
    onListen: () {
      if (sources.isEmpty) controller.add(const {});
      for (final MapEntry(key: id, value: stream) in sources.entries) {
        subscriptions.add(
          stream.listen(
            (value) => report(id, value),
            onError: (Object error) {
              if (kDebugMode) {
                debugPrint('[MyFit] lesson count for $id failed: $error');
              }
              report(id, counts[id] ?? 0);
            },
          ),
        );
      }
    },
    onCancel: () async {
      for (final subscription in subscriptions) {
        await subscription.cancel();
      }
    },
  );
  return controller.stream;
}

class FirestoreLessonRepository implements LessonRepository {
  FirestoreLessonRepository({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> _lessons(String categoryId) =>
      _firestore.collection('courses').doc(categoryId).collection('lessons');

  @override
  Stream<List<CourseLesson>> watchLessons(String categoryId) =>
      _lessons(categoryId)
          .orderBy('order')
          .snapshots()
          .map(
            (snapshot) => [
              for (final doc in snapshot.docs)
                CourseLesson.fromMap(doc.id, doc.data()),
            ],
          );

  /// One listener per category on `courses/{id}/lessons` (the same path the
  /// category page reads). A collection-group query is not used: it needs a
  /// collection-group index and the recursive `{path=**}` rule.
  @override
  Stream<Map<String, int>> watchLessonCounts(List<String> categoryIds) =>
      combineLessonCounts({
        for (final id in categoryIds)
          id: _lessons(id).snapshots().map((snapshot) => snapshot.size),
      });

  @override
  Future<bool> isAdmin() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return false;
    try {
      return (await _firestore.collection('admins').doc(uid).get()).exists;
    } catch (_) {
      return false;
    }
  }
}

LessonRepository defaultLessonRepository() => Firebase.apps.isEmpty
    ? const EmptyLessonRepository()
    : FirestoreLessonRepository();
