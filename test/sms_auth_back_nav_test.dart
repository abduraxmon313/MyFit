import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:myfit/config/app_config.dart';
import 'package:myfit/screens/otp_verify_page.dart';
import 'package:myfit/services/auth_service.dart';

class _Auth implements FirebaseAuth {
  final tokens = <String>[];
  @override
  Future<UserCredential> signInWithCustomToken(String token) async {
    tokens.add(token);
    return _Credential();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Credential implements UserCredential {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

http.Response _error(int status, String reason, [int? retry]) => http.Response(
  jsonEncode({
    'error': {'reason': reason, 'message': 'm', 'retryAfterSeconds': ?retry},
  }),
  status,
);

void main() {
  group('SMS sign-in via Worker', () {
    test(
      'sends the normalized phone and signs in with the custom token',
      () async {
        final seen = <http.Request>[];
        final client = MockClient((request) async {
          seen.add(request);
          return request.url.path == '/auth/sms/send'
              ? http.Response('{"sent":true}', 200)
              : http.Response('{"customToken":"ct-1"}', 200);
        });
        final firebase = _Auth();
        final auth = AuthService(auth: firebase, client: client);
        await auth.requestSmsCode('90 123 45 67');
        await auth.verifySmsCode(
          phoneNumber: '+998901234567',
          code: ' 123456 ',
        );
        expect(seen.map((r) => r.url.toString()), [
          '$kVideoApiBaseUrl/auth/sms/send',
          '$kVideoApiBaseUrl/auth/sms/verify',
        ]);
        expect(jsonDecode(seen[0].body), {'phone': '+998901234567'});
        expect(jsonDecode(seen[1].body), {
          'phone': '+998901234567',
          'code': '123456',
        });
        expect(seen[0].headers.containsKey('Authorization'), isFalse);
        expect(firebase.tokens, ['ct-1']);
      },
    );

    test('maps Worker errors with retry hints', () async {
      Future<SmsAuthException> fail(http.Response response) async {
        final auth = AuthService(
          auth: _Auth(),
          client: MockClient((_) async => response),
        );
        try {
          await auth.requestSmsCode('+998901234567');
        } on SmsAuthException catch (error) {
          return error;
        }
        throw StateError('no error');
      }

      final soon = await fail(_error(429, 'resend-too-soon', 42));
      expect(soon.reason, 'resend-too-soon');
      expect(soon.retryAfterSeconds, 42);
      expect(
        (await fail(_error(400, 'invalid-phone'))).reason,
        'invalid-phone',
      );
      expect(
        (await fail(http.Response('<html>', 503))).reason,
        'sms-unavailable',
      );
      final offline = AuthService(
        auth: _Auth(),
        client: MockClient((_) => throw http.ClientException('offline')),
      );
      expect(
        () => offline.requestSmsCode('+998901234567'),
        throwsA(
          isA<SmsAuthException>().having((e) => e.reason, 'reason', 'network'),
        ),
      );
    });
  });

  group('OTP page', () {
    Future<void> pump(WidgetTester tester, AuthService auth) async {
      await tester.pumpWidget(
        MaterialApp(
          home: OtpVerifyPage(
            authService: auth,
            phoneNumber: '+998901234567',
            autoSend: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('shows a wrong code and keeps the page open', (tester) async {
      final client = MockClient(
        (request) async => request.url.path == '/auth/sms/send'
            ? http.Response('{"sent":true}', 200)
            : _error(400, 'invalid-code'),
      );
      await pump(tester, AuthService(auth: _Auth(), client: client));
      expect(
        find.text('SMS kod yuborildi. Xabarlarni tekshiring.'),
        findsOneWidget,
      );
      await tester.enterText(find.byType(TextFormField), '000000');
      await tester.tap(find.text('Tasdiqlash'));
      await tester.pumpAndSettle();
      expect(find.text('SMS kod noto‘g‘ri.'), findsOneWidget);
      expect(find.byType(OtpVerifyPage), findsOneWidget);
      await tester.pump(const Duration(seconds: 61));
    });

    testWidgets('a recent code still lets the user type it', (tester) async {
      final client = MockClient(
        (_) async => _error(429, 'resend-too-soon', 30),
      );
      await pump(tester, AuthService(auth: _Auth(), client: client));
      expect(find.text('Yangi kodni biroz kutib so‘rang.'), findsOneWidget);
      final field = tester.widget<TextFormField>(find.byType(TextFormField));
      expect(field.enabled, isTrue);
      expect(find.text('Qayta yuborish (30 s)'), findsOneWidget);
      await tester.pump(const Duration(seconds: 31));
    });

    testWidgets('provider outages show a clear message', (tester) async {
      final client = MockClient((_) async => _error(503, 'sms-unavailable'));
      await pump(tester, AuthService(auth: _Auth(), client: client));
      expect(
        find.text(
          'SMS xizmati vaqtincha ishlamayapti. Keyinroq urinib ko‘ring.',
        ),
        findsOneWidget,
      );
    });
  });
}
