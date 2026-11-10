import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myfit/main.dart';
import 'package:myfit/screens/auth_gate.dart';
import 'package:myfit/screens/language_picker_page.dart';
import 'package:myfit/screens/profile_page.dart';
import 'package:myfit/screens/workouts_page.dart';
import 'package:myfit/services/locale_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'appearance_test.dart' show SignedOutAuth;
import 'auth_gate_regression_test.dart' show TestProfiles;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('first launch asks language, then shows login in it, light', (
    tester,
  ) async {
    await tester.pumpWidget(
      MyFitApp(
        authService: SignedOutAuth(),
        profileService: TestProfiles(),
        askLanguage: true,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(LanguagePickerPage), findsOneWidget);
    expect(find.byType(AuthGate), findsNothing);
    expect(
      Theme.of(tester.element(find.byType(LanguagePickerPage))).brightness,
      Brightness.light,
    );

    await tester.tap(find.byKey(const Key('language-ru')));
    await tester.pump();
    expect(find.text('Продолжить'), findsOneWidget);
    await tester.tap(find.byKey(const Key('language-continue')));
    await tester.pumpAndSettle();

    expect(find.byType(AuthGate), findsOneWidget);
    expect(
      Localizations.localeOf(tester.element(find.byType(AuthGate))),
      const Locale('ru'),
    );
    expect(await LocaleStore().load(), 'ru');
    expect(tester.takeException(), isNull);
  });

  testWidgets('saved language skips the picker', (tester) async {
    await tester.pumpWidget(
      MyFitApp(
        authService: SignedOutAuth(),
        profileService: TestProfiles(),
        initialLocale: 'en',
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(LanguagePickerPage), findsNothing);
    expect(
      Localizations.localeOf(tester.element(find.byType(AuthGate))),
      const Locale('en'),
    );
  });

  test('photo errors name the real cause', () {
    String text(Object error) => photoErrorMessage(error).$1;
    expect(
      text(FirebaseException(plugin: 'firebase_storage', code: 'unauthorized')),
      contains('qoidalari'),
    );
    expect(
      text(
        FirebaseException(plugin: 'firebase_storage', code: 'bucket-not-found'),
      ),
      contains('Blaze'),
    );
    expect(
      text(PlatformException(code: 'photo_access_denied')),
      contains('ruxsat'),
    );
    final other = photoErrorMessage(
      FirebaseException(plugin: 'firebase_storage', code: 'weird'),
    );
    expect(other.$2['code'], 'weird');
  });

  testWidgets('course tab lists lessons and opens a lesson', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 1000);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: WorkoutsPage())),
    );
    expect(find.text('Murabbiy video kursi'), findsOneWidget);
    await tester.tap(find.byKey(const Key('lesson-l1')));
    await tester.pumpAndSettle();
    expect(find.text('Video hali yuklanmagan'), findsOneWidget);
    await tester.tap(find.text('Keyingi'));
    await tester.pumpAndSettle();
    expect(find.text('To‘g‘ri isinish'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
