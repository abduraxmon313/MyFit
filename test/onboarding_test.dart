import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myfit/data/trainer_course.dart';
import 'package:myfit/main.dart';
import 'package:myfit/models/trainer_course.dart';
import 'package:myfit/screens/auth_gate.dart';
import 'package:myfit/screens/language_picker_page.dart';
import 'package:myfit/screens/profile_page.dart';
import 'package:myfit/screens/lessons_page.dart';
import 'package:myfit/services/locale_store.dart';
import 'package:myfit/services/profile_photo_api.dart';
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

  testWidgets('signed-out start shows the picker with the saved language', (
    tester,
  ) async {
    await tester.pumpWidget(
      MyFitApp(
        authService: SignedOutAuth(),
        profileService: TestProfiles(),
        initialLocale: 'en',
        askLanguage: true,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(LanguagePickerPage), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
    await tester.tap(find.byKey(const Key('language-continue')));
    await tester.pumpAndSettle();
    expect(
      Localizations.localeOf(tester.element(find.byType(AuthGate))),
      const Locale('en'),
    );
  });

  test('photo errors name the real cause', () {
    String text(Object error) => photoErrorMessage(error).$1;
    expect(
      text(const ProfilePhotoException('sign-in-required')),
      contains('qayta kiring'),
    );
    expect(
      text(const ProfilePhotoException('too-large')),
      contains('juda katta'),
    );
    expect(
      text(const ProfilePhotoException('unsupported-format')),
      contains('formatda'),
    );
    expect(text(const ProfilePhotoException('network')), contains('Internet'));
    expect(
      text(const ProfilePhotoException('storage-unavailable')),
      contains('ombori'),
    );
    expect(
      text(PlatformException(code: 'photo_access_denied')),
      contains('ruxsat'),
    );
    final other = photoErrorMessage(const ProfilePhotoException('weird'));
    expect(other.$2['code'], 'weird');
    expect(
      photoErrorMessage(
        FirebaseException(plugin: 'cloud_firestore', code: 'aborted'),
      ).$2['code'],
      'aborted',
    );
  });

  testWidgets('lessons tab lists categories and opens one', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 1000);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: LessonsPage())),
    );
    expect(kLessonCategories, hasLength(13));
    expect(find.text('Darslar'), findsOneWidget);
    expect(find.text('FullBody mashqlar'), findsOneWidget);
    await tester.tap(find.byKey(const Key('category-fullbody')));
    await tester.pumpAndSettle();
    expect(find.byType(LessonCategoryPage), findsOneWidget);
    expect(find.byKey(const Key('category-empty')), findsOneWidget);
    await tester.tap(find.byKey(const Key('category-back')));
    await tester.pumpAndSettle();
    expect(find.byType(LessonCategoryPage), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('category videos open in order, any one can be picked', (
    tester,
  ) async {
    const course = TrainerCourse(
      id: 'superset',
      title: 'SuperSet mashqlar',
      description: '',
      lessons: [
        CourseLesson(id: 'b', order: 2, title: 'Ikkinchi', description: ''),
        CourseLesson(id: 'a', order: 1, title: 'Birinchi', description: ''),
        CourseLesson(id: 'c', order: 3, title: 'Uchinchi', description: ''),
      ],
    );
    await tester.pumpWidget(
      const MaterialApp(home: LessonCategoryPage(course: course)),
    );
    expect(
      tester.getTopLeft(find.byKey(const Key('lesson-a'))).dy,
      lessThan(tester.getTopLeft(find.byKey(const Key('lesson-b'))).dy),
    );
    await tester.tap(find.byKey(const Key('lesson-b')));
    await tester.pumpAndSettle();
    expect(find.text('Ikkinchi'), findsOneWidget);
    await tester.tap(find.text('Keyingi'));
    await tester.pumpAndSettle();
    expect(find.text('Uchinchi'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
