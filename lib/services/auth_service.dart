import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';

/// SMS sign-in failure. [reason] matches the Worker `error.reason`
/// (`invalid-code`, `code-expired`, `resend-too-soon`, …) plus `network`.
class SmsAuthException implements Exception {
  const SmsAuthException(this.reason, {this.retryAfterSeconds, this.detail});

  final String reason;
  final int? retryAfterSeconds;
  final String? detail;

  @override
  String toString() => 'SmsAuthException($reason)';
}

/// Firebase Auth session; SMS codes come from the MyFit Worker (DevSMS),
/// not from Firebase Phone Auth. The Worker returns a Firebase custom token
/// for the existing user of that phone number, so UIDs and data stay.
class AuthService {
  AuthService({FirebaseAuth? auth, this.client, String? apiBase})
    : _authOverride = auth,
      _apiBase = apiBase ?? kVideoApiBaseUrl;

  final FirebaseAuth? _authOverride;

  /// Defaults to a new client per request.
  final http.Client? client;
  final String _apiBase;

  FirebaseAuth get _auth => _authOverride ?? FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  /// Normalizes local numbers like `90 123 45 67` to `+998901234567`.
  String normalizePhone(String input) {
    final digits = input.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('998') && digits.length >= 12) {
      return '+$digits';
    }
    if (digits.startsWith('0') && digits.length >= 10) {
      return '+998${digits.substring(1)}';
    }
    if (digits.length == 9) {
      return '+998$digits';
    }
    return '+$digits';
  }

  /// Asks the Worker to send a 6 digit SMS code.
  Future<void> requestSmsCode(String phoneNumber) async {
    await _post('/auth/sms/send', {'phone': normalizePhone(phoneNumber)});
  }

  /// Checks the code with the Worker and signs in with the custom token.
  Future<UserCredential> verifySmsCode({
    required String phoneNumber,
    required String code,
  }) async {
    final result = await _post('/auth/sms/verify', {
      'phone': normalizePhone(phoneNumber),
      'code': code.trim(),
    });
    final token = result['customToken'];
    if (token is! String || token.isEmpty) {
      throw const SmsAuthException('internal', detail: 'No token');
    }
    return _auth.signInWithCustomToken(token);
  }

  Future<Map<String, dynamic>> _post(String path, Object body) async {
    final base = _apiBase.trim().replaceAll(RegExp(r'/+$'), '');
    final httpClient = client ?? http.Client();
    try {
      final http.Response response;
      try {
        response = await httpClient
            .post(
              Uri.parse('$base$path'),
              headers: const {'Content-Type': 'application/json'},
              body: jsonEncode(body),
            )
            .timeout(const Duration(seconds: 30));
      } on TimeoutException {
        throw const SmsAuthException('network', detail: 'timeout');
      } on http.ClientException catch (error) {
        throw SmsAuthException('network', detail: error.message);
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
              429 => 'too-many-requests',
              502 || 503 || 504 => 'sms-unavailable',
              _ => 'internal',
            };
      final retry = error is Map ? error['retryAfterSeconds'] : null;
      throw SmsAuthException(
        reason,
        retryAfterSeconds: retry is num ? retry.toInt() : null,
        detail: error is Map ? '${error['message']}' : null,
      );
    } finally {
      if (client == null) httpClient.close();
    }
  }

  Future<void> signOut() => _auth.signOut();
}
