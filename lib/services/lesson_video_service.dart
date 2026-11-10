import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart' show XFile;

import '../models/trainer_course.dart';
import 'mp4_inspector.dart';

/// Upload limit; the backend enforces the same value.
const kMaxLessonVideoBytes = 2 * 1024 * 1024 * 1024;
const kLessonVideoContentType = 'video/mp4';

/// Video upload or validation failure.
///
/// [reason] matches the backend `details.reason` values, plus the client-side
/// `cancelled`, `network` and `upload-failed`.
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

/// Admin upload flow: backend presigned URL → direct PUT to R2 → backend
/// verification (HeadObject + MP4 check) → Firestore lesson.
class LessonVideoUploader {
  LessonVideoUploader({this.functions, this.client});

  /// Defaults to the `europe-west1` instance used by all MyFit functions.
  final FirebaseFunctions? functions;

  /// Defaults to a new client per upload.
  final http.Client? client;

  FirebaseFunctions get _fn =>
      functions ?? FirebaseFunctions.instanceFor(region: 'europe-west1');

  Future<UploadedLessonVideo> upload({
    required String categoryId,
    required String title,
    String description = '',
    required XFile file,
    UploadProgress? onProgress,
    void Function(LessonUploadPhase phase)? onPhase,
    UploadCancelToken? cancelToken,
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

    final session = await _call('createVideoUploadUrl', {
      'categoryId': categoryId,
      'title': title.trim(),
      'description': description.trim(),
      'fileName': file.name.toLowerCase().endsWith('.mp4')
          ? file.name
          : 'video.mp4',
      'contentType': kLessonVideoContentType,
      'sizeBytes': size,
    }, timeout: const Duration(seconds: 35));
    final uploadId = session['uploadId'] as String;
    final headers = <String, String>{
      for (final entry in (session['headers'] as Map? ?? const {}).entries)
        '${entry.key}': '${entry.value}',
    };
    cancelToken?.throwIfCancelled();

    onPhase?.call(LessonUploadPhase.uploading);
    final httpClient = client ?? http.Client();
    try {
      await putLessonVideo(
        client: httpClient,
        url: Uri.parse(session['uploadUrl'] as String),
        headers: headers,
        body: file.openRead(),
        length: size,
        onProgress: onProgress,
        cancelToken: cancelToken,
      );
    } finally {
      if (client == null) httpClient.close();
    }
    cancelToken?.throwIfCancelled();

    onPhase?.call(LessonUploadPhase.finalizing);
    final result = await _call('finalizeVideoUpload', {
      'uploadId': uploadId,
    }, timeout: const Duration(seconds: 130));
    return UploadedLessonVideo(
      lessonId: result['lessonId'] as String,
      videoUrl: result['videoUrl'] as String,
    );
  }

  Future<Map<String, dynamic>> _call(
    String name,
    Map<String, Object?> data, {
    required Duration timeout,
  }) async {
    try {
      final response = await _fn
          .httpsCallable(name, options: HttpsCallableOptions(timeout: timeout))
          .call<Map<String, dynamic>>(data);
      return Map<String, dynamic>.from(response.data);
    } on FirebaseFunctionsException catch (error) {
      throw LessonVideoException(_reasonOf(error), error.message);
    }
  }

  static String _reasonOf(FirebaseFunctionsException error) {
    final details = error.details;
    if (details is Map && details['reason'] is String) {
      return details['reason'] as String;
    }
    return switch (error.code) {
      'unauthenticated' => 'sign-in-required',
      'permission-denied' => 'not-admin',
      'unavailable' || 'deadline-exceeded' => 'network',
      _ => 'internal',
    };
  }
}

/// Lesson data source for the "Darslar" tab.
abstract class LessonRepository {
  /// Lessons of one category, ordered by `order`.
  Stream<List<CourseLesson>> watchLessons(String categoryId);

  /// Number of lessons per category id.
  Stream<Map<String, int>> watchLessonCounts();

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
  Stream<Map<String, int>> watchLessonCounts() => Stream.value(const {});

  @override
  Future<bool> isAdmin() async => false;
}

class FirestoreLessonRepository implements LessonRepository {
  FirestoreLessonRepository({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  @override
  Stream<List<CourseLesson>> watchLessons(String categoryId) => _firestore
      .collection('courses')
      .doc(categoryId)
      .collection('lessons')
      .orderBy('order')
      .snapshots()
      .map(
        (snapshot) => [
          for (final doc in snapshot.docs)
            CourseLesson.fromMap(doc.id, doc.data()),
        ],
      );

  @override
  Stream<Map<String, int>> watchLessonCounts() =>
      _firestore.collectionGroup('lessons').snapshots().map((snapshot) {
        final counts = <String, int>{};
        for (final doc in snapshot.docs) {
          final course = doc.reference.parent.parent;
          if (course == null || course.parent.id != 'courses') continue;
          counts[course.id] = (counts[course.id] ?? 0) + 1;
        }
        return counts;
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
