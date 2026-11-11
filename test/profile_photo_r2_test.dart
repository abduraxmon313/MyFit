import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:myfit/config/app_config.dart';
import 'package:myfit/services/profile_photo_api.dart';

final png = Uint8List.fromList([
  0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0, 0, 0, 13, //
]);

ProfilePhotoApi api(
  http.Client client, {
  Future<String?> Function({bool forceRefresh})? token,
}) => ProfilePhotoApi(
  client: client,
  idToken: token ?? ({bool forceRefresh = false}) async => 'tok',
);

Future<String> reason(Future<Object?> Function() run) async {
  try {
    await run();
    return 'ok';
  } on ProfilePhotoException catch (error) {
    return error.reason;
  }
}

void main() {
  test('detects JPEG, PNG and WebP by content', () {
    expect(profileImageContentType(png), 'image/png');
    expect(
      profileImageContentType(Uint8List.fromList([0xff, 0xd8, 0xff, 0xe0])),
      'image/jpeg',
    );
    expect(
      profileImageContentType(
        Uint8List.fromList(ascii.encode('RIFF\x00\x00\x00\x00WEBPVP8 ')),
      ),
      'image/webp',
    );
    expect(
      profileImageContentType(Uint8List.fromList(ascii.encode('GIF89a'))),
      isNull,
    );
  });

  test('uploads raw bytes to the Worker with the ID token', () async {
    late http.Request seen;
    final client = MockClient((request) async {
      seen = request;
      return http.Response(
        jsonEncode({
          'url': 'https://pub.r2.dev/profile-images/u1/1-a.png',
          'objectKey': 'profile-images/u1/1-a.png',
        }),
        200,
      );
    });
    final url = await api(client).upload(uid: 'u1', bytes: png);
    expect(url, 'https://pub.r2.dev/profile-images/u1/1-a.png');
    expect(seen.method, 'POST');
    expect(seen.url.toString(), '$kVideoApiBaseUrl/profile/upload?uid=u1');
    expect(seen.headers['Authorization'], 'Bearer tok');
    expect(seen.headers['Content-Type'], 'image/png');
    expect(seen.bodyBytes, png);
  });

  test('validates format and size before any request', () async {
    var calls = 0;
    final client = MockClient((_) async {
      calls++;
      return http.Response('{}', 200);
    });
    expect(
      await reason(
        () => api(
          client,
        ).upload(uid: 'u1', bytes: Uint8List.fromList(ascii.encode('<svg/>'))),
      ),
      'unsupported-format',
    );
    final big = Uint8List(kMaxProfileImageBytes + 1)..setAll(0, png);
    expect(
      await reason(() => api(client).upload(uid: 'u1', bytes: big)),
      'too-large',
    );
    expect(
      await reason(() => api(client).upload(uid: 'u1', bytes: Uint8List(0))),
      'empty-file',
    );
    expect(calls, 0);
  });

  test('maps Worker 401/403/413/415 and network errors', () async {
    Future<String> status(int code, [String? workerReason]) => reason(
      () => api(
        MockClient(
          (_) async => http.Response(
            workerReason == null
                ? '<html>'
                : jsonEncode({
                    'error': {'reason': workerReason, 'message': 'm'},
                  }),
            code,
          ),
        ),
      ).upload(uid: 'u1', bytes: png),
    );
    expect(await status(401, 'sign-in-required'), 'sign-in-required');
    expect(await status(403, 'not-owner'), 'not-owner');
    expect(await status(413, 'too-large'), 'too-large');
    expect(await status(415, 'unsupported-format'), 'unsupported-format');
    expect(await status(502), 'network');
    expect(
      await reason(
        () => api(
          MockClient((_) => throw http.ClientException('reset')),
        ).upload(uid: 'u1', bytes: png),
      ),
      'network',
    );
    expect(
      await reason(
        () => api(
          MockClient((_) async => http.Response('{}', 200)),
          token: ({bool forceRefresh = false}) async => null,
        ).upload(uid: 'u1', bytes: png),
      ),
      'sign-in-required',
    );
  });

  test('refreshes an expired token once', () async {
    final refreshes = <bool>[];
    var calls = 0;
    final client = MockClient((request) async {
      calls++;
      return calls == 1
          ? http.Response('{"error":{"reason":"token-expired"}}', 401)
          : http.Response('{"url":"https://pub.r2.dev/x.png"}', 200);
    });
    final url = await api(
      client,
      token: ({bool forceRefresh = false}) async {
        refreshes.add(forceRefresh);
        return 't';
      },
    ).upload(uid: 'u1', bytes: png);
    expect(url, 'https://pub.r2.dev/x.png');
    expect(refreshes, [false, true]);
  });

  test('delete posts the own uid as JSON', () async {
    late http.Request seen;
    final client = MockClient((request) async {
      seen = request;
      return http.Response('{"deleted":1}', 200);
    });
    await api(client).delete(uid: 'u1');
    expect(seen.url.toString(), '$kVideoApiBaseUrl/profile/delete');
    expect(jsonDecode(seen.body), {'uid': 'u1'});
    expect(seen.headers['Content-Type'], startsWith('application/json'));
  });
}
