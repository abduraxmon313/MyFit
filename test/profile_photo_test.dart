import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:myfit/models/user_profile.dart';
import 'package:myfit/screens/profile_page.dart';
import 'package:myfit/services/profile_photo_picker.dart';
import 'package:myfit/widgets/profile_avatar.dart';

const profile = UserProfile(
  firstName: 'Aziz',
  lastName: 'Karimov',
  gender: 'male',
  age: 28,
  heightCm: 178,
  weightKg: 75,
  activityLevel: 'medium',
  goal: 'maintain',
);

class TestPhotoPicker extends ProfilePhotoPicker {
  Uint8List? bytes = Uint8List.fromList([1, 2, 3]);
  ImageSource? source;
  bool fail = false;
  @override
  Future<Uint8List?> pick(ImageSource source) async {
    this.source = source;
    if (fail) throw StateError('permission denied');
    return bytes;
  }
}

Future<void> openPhoto(WidgetTester tester, String action) async {
  await tester.tap(find.byKey(const Key('profile-photo-button')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(action));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
}

void main() {
  testWidgets(
    'gallery upload is single-flight, shows progress and updates avatar',
    (tester) async {
      final picker = TestPhotoPicker();
      final upload = Completer<String>();
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProfilePage(
              profile: profile,
              phoneNumber: '',
              onSave: (_) async {},
              onSignOut: () async {},
              photoPicker: picker,
              onPhotoUpload: (bytes) {
                calls++;
                expect(bytes, [1, 2, 3]);
                return upload.future;
              },
            ),
          ),
        ),
      );
      await openPhoto(tester, 'Galereyadan tanlash');
      expect(picker.source, ImageSource.gallery);
      expect(calls, 1);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.tap(find.byKey(const Key('profile-photo-button')));
      await tester.pump();
      expect(calls, 1);
      upload.complete('https://example.com/new-avatar.png');
      await tester.pumpAndSettle();
      expect(
        tester.widget<ProfileAvatar>(find.byType(ProfileAvatar)).photoUrl,
        'https://example.com/new-avatar.png',
      );
      expect(find.text('Profil rasmi yangilandi.'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    },
  );

  testWidgets('cancelled picker never uploads; camera errors allow retry', (
    tester,
  ) async {
    final picker = TestPhotoPicker()..bytes = null;
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProfilePage(
            profile: profile,
            phoneNumber: '',
            onSave: (_) async {},
            onSignOut: () async {},
            photoPicker: picker,
            onPhotoUpload: (_) async {
              calls++;
              return 'url';
            },
          ),
        ),
      ),
    );
    await openPhoto(tester, 'Galereyadan tanlash');
    await tester.pumpAndSettle();
    expect(calls, 0);
    expect(find.text('Rasm qo‘shish'), findsOneWidget);
    picker.fail = true;
    await openPhoto(tester, 'Kamerada suratga olish');
    await tester.pumpAndSettle();
    expect(picker.source, ImageSource.camera);
    expect(calls, 0);
    expect(
      find.text(
        'Rasmni yangilab bo‘lmadi. Ruxsat va internetni tekshirib, qayta urinib ko‘ring.',
      ),
      findsOneWidget,
    );
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets(
    'failed replacement retains old photo and removal updates the avatar',
    (tester) async {
      final existing = UserProfile.fromMap({
        ...profile.toMap(),
        'photoUrl': 'https://example.com/old.png',
      });
      var removals = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProfilePage(
              profile: existing,
              phoneNumber: '',
              onSave: (_) async {},
              onSignOut: () async {},
              photoPicker: TestPhotoPicker(),
              onPhotoUpload: (_) async => throw StateError('offline'),
              onPhotoRemove: () async {
                removals++;
              },
            ),
          ),
        ),
      );
      await openPhoto(tester, 'Galereyadan tanlash');
      await tester.pumpAndSettle();
      expect(
        tester.widget<ProfileAvatar>(find.byType(ProfileAvatar)).photoUrl,
        existing.photoUrl,
      );
      await openPhoto(tester, 'Rasmni olib tashlash');
      await tester.pumpAndSettle();
      expect(removals, 1);
      expect(
        tester.widget<ProfileAvatar>(find.byType(ProfileAvatar)).photoUrl,
        isNull,
      );
      expect(find.text('AK'), findsOneWidget);
    },
  );

  testWidgets('disposed profile safely completes a pending upload', (
    tester,
  ) async {
    final upload = Completer<String>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProfilePage(
            profile: profile,
            phoneNumber: '',
            onSave: (_) async {},
            onSignOut: () async {},
            photoPicker: TestPhotoPicker(),
            onPhotoUpload: (_) => upload.future,
          ),
        ),
      ),
    );
    await openPhoto(tester, 'Galereyadan tanlash');
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    upload.complete('https://example.com/photo.png');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('real image normalization retains aspect ratio and limits size', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final recorder = ui.PictureRecorder();
      Canvas(recorder).drawColor(const Color(0xFF13765E), BlendMode.src);
      final picture = recorder.endRecording();
      final source = await picture.toImage(2048, 1024);
      final png = await source.toByteData(format: ui.ImageByteFormat.png);
      final bytes = await ProfilePhotoPicker.prepare(png!.buffer.asUint8List());
      expect(bytes.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
      final codec = await ui.instantiateImageCodec(bytes);
      final normalized = (await codec.getNextFrame()).image;
      expect(normalized.width, 1024);
      expect(normalized.height, 512);
      expect(bytes.length, lessThan(5 * 1024 * 1024));
      normalized.dispose();
      codec.dispose();
      source.dispose();
      picture.dispose();
      await expectLater(
        ProfilePhotoPicker.prepare(Uint8List(0)),
        throwsFormatException,
      );
      await expectLater(
        ProfilePhotoPicker.prepare(Uint8List.fromList([1, 2, 3])),
        throwsA(anything),
      );
    });
  });
}
