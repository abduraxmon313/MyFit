import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';

/// Upload limit; the Worker enforces the same value.
const kMaxProfileImageBytes = 5 * 1024 * 1024;

/// Profile photo upload/delete failure. [reason] matches the Worker
/// `error.reason` (`too-large`, `unsupported-format`, `not-owner`, …) plus
/// `network` and `sign-in-required`.
class ProfilePhotoException implements Exception {
  const ProfilePhotoException(this.reason, [this.detail]);

  final String reason;
  final String? detail;

  @override
  String toString() =>
      'ProfilePhotoException($reason${detail == null ? '' : ': $detail'})';
}

/// JPEG, PNG or WebP by magic bytes; `null` otherwise.
String? profileImageContentType(Uint8List bytes) {
  bool starts(List<int> magic) =>
      bytes.length >= magic.length &&
      [for (var i = 0; i < magic.length; i++) bytes[i]].join(',') ==
          magic.join(',');
  if (starts(const [0xff, 0xd8, 0xff])) return 'image/jpeg';
  if (starts(const [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a])) {
    return 'image/png';
  }
  if (bytes.length >= 12 &&
      ascii.decode(bytes.sublist(0, 4), allowInvalid: true) == 'RIFF' &&
      ascii.decode(bytes.sublist(8, 12), allowInvalid: true) == 'WEBP') {
    return 'image/webp';
  }
  return null;
}

typedef ProfileIdToken = Future<String?> Function({bool forceRefresh});

Future<String?> _firebaseIdToken({bool forceRefresh = false}) async =>
    FirebaseAuth.instance.currentUser?.getIdToken(forceRefresh);

/// Calls the Cloudflare Worker (`/profile/upload`, `/profile/delete`).
/// The Worker stores photos in R2 under `profile-images/{uid}/` and takes the
/// UID from the verified ID token only.
class ProfilePhotoApi {
  ProfilePhotoApi({this.client, String? apiBase, ProfileIdToken? idToken})
    : apiBase = apiBase ?? kVideoApiBaseUrl,
      idToken = idToken ?? _firebaseIdToken;

  final http.Client? client;
  final String apiBase;
  final ProfileIdToken idToken;

  /// Uploads [bytes] for [uid] (must be the signed-in user) and returns the
  /// public URL.
  Future<String> upload({required String uid, required Uint8List bytes}) async {
    if (bytes.isEmpty) throw const ProfilePhotoException('empty-file');
    if (bytes.length > kMaxProfileImageBytes) {
      throw const ProfilePhotoException('too-large');
    }
    final contentType = profileImageContentType(bytes);
    if (contentType == null) {
      throw const ProfilePhotoException('unsupported-format');
    }
    final json = await _send(
      Uri.parse(
        '${_base()}/profile/upload',
      ).replace(queryParameters: {'uid': uid}),
      contentType: contentType,
      body: bytes,
      timeout: const Duration(seconds: 60),
    );
    final url = json['url'];
    if (url is! String || !url.startsWith('https://')) {
      throw const ProfilePhotoException('internal', 'No URL in response');
    }
    return url;
  }

  /// Deletes every stored photo of [uid] (the signed-in user).
  Future<void> delete({required String uid}) async {
    await _send(
      Uri.parse('${_base()}/profile/delete'),
      contentType: 'application/json',
      body: utf8.encode(jsonEncode({'uid': uid})),
      timeout: const Duration(seconds: 30),
    );
  }

  String _base() {
    final base = apiBase.trim().replaceAll(RegExp(r'/+$'), '');
    if (!base.startsWith('https://')) {
      throw const ProfilePhotoException('not-configured');
    }
    return base;
  }

  Future<Map<String, dynamic>> _send(
    Uri uri, {
    required String contentType,
    required List<int> body,
    required Duration timeout,
  }) async {
    final httpClient = client ?? http.Client();
    try {
      for (var attempt = 0; ; attempt++) {
        final String? token;
        try {
          token = await idToken(forceRefresh: attempt > 0);
        } catch (error) {
          throw ProfilePhotoException('sign-in-required', '$error');
        }
        if (token == null || token.isEmpty) {
          throw const ProfilePhotoException('sign-in-required');
        }
        final http.Response response;
        try {
          response = await httpClient
              .post(
                uri,
                headers: {
                  'Authorization': 'Bearer $token',
                  'Content-Type': contentType,
                },
                body: body,
              )
              .timeout(timeout);
        } on TimeoutException {
          throw const ProfilePhotoException('network', 'timeout');
        } on http.ClientException catch (error) {
          throw ProfilePhotoException('network', error.message);
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
                403 => 'not-owner',
                413 => 'too-large',
                415 => 'unsupported-format',
                429 || 502 || 503 || 504 => 'network',
                _ => 'internal',
              };
        final tokenProblem =
            reason == 'token-expired' || reason == 'invalid-token';
        if (response.statusCode == 401 && tokenProblem && attempt == 0) {
          continue;
        }
        throw ProfilePhotoException(
          tokenProblem ? 'sign-in-required' : reason,
          error is Map ? '${error['message']}' : 'HTTP ${response.statusCode}',
        );
      }
    } finally {
      if (client == null) httpClient.close();
    }
  }
}
