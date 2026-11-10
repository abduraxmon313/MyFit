import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myfit/models/user_profile.dart';
import 'package:myfit/screens/profile_setup_page.dart';
import 'package:myfit/services/onboarding_store.dart';
import 'package:myfit/services/phone_format.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_gate_regression_test.dart' show TestProfiles;

class _SavingProfiles extends TestProfiles {
  UserProfile? saved;

  @override
  Future<void> saveProfile(String uid, UserProfile profile) async {
    saved = profile;
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('phone format', () {
    test('formats full numbers for display', () {
      expect(formatUzPhone('+998333134422'), '+998 33 313 44 22');
      expect(formatUzPhone('998901234567'), '+998 90 123 45 67');
      expect(formatUzPhone('333134422'), '+998 33 313 44 22');
      expect(formatUzPhone('+7 999'), '+7 999');
    });

    test('input formatter groups digits while typing', () {
      const formatter = UzPhoneInputFormatter();
      String type(String text) => formatter
          .formatEditUpdate(
            TextEditingValue.empty,
            TextEditingValue(text: text),
          )
          .text;
      expect(type('33'), '33');
      expect(type('33313'), '33 313');
      expect(type('3331344'), '33 313 44');
      expect(type('333134422'), '33 313 44 22');
      expect(type('3331344229'), '33 313 44 22');
      expect(type('+998 33 313 44 22'), '33 313 44 22');
    });
  });

  testWidgets('profile setup is a 4-step wizard ending with Yakunlash', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 900);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final profiles = _SavingProfiles();
    await tester.pumpWidget(
      MaterialApp(
        home: ProfileSetupPage(uid: 'u1', profileService: profiles),
      ),
    );
    await tester.pumpAndSettle();
    expect(await OnboardingStore().isInProgress(), isTrue);

    // 1: personal info; empty fields block the step.
    expect(find.text('1 / 4 qadam'), findsOneWidget);
    await tester.tap(find.byKey(const Key('setup-continue')));
    await tester.pump();
    expect(find.text('1 / 4 qadam'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('setup-first-name')), 'Ali');
    await tester.enterText(find.byKey(const Key('setup-last-name')), 'Valiyev');
    await tester.enterText(find.byKey(const Key('setup-age')), '25');
    await tester.tap(find.byKey(const Key('setup-continue')));
    await tester.pumpAndSettle();

    // 2: body measurements.
    expect(find.text('2 / 4 qadam'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('setup-height')), '180');
    await tester.enterText(find.byKey(const Key('setup-weight')), '80');
    await tester.tap(find.byKey(const Key('setup-continue')));
    await tester.pumpAndSettle();

    // 3: activity; back keeps the entered values.
    expect(find.text('3 / 4 qadam'), findsOneWidget);
    await tester.tap(find.byKey(const Key('setup-back')));
    await tester.pumpAndSettle();
    expect(find.text('180'), findsOneWidget);
    await tester.tap(find.byKey(const Key('setup-continue')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('setup-activity-high')));
    await tester.tap(find.byKey(const Key('setup-continue')));
    await tester.pumpAndSettle();

    // 4: goal, then Yakunlash saves.
    expect(find.text('4 / 4 qadam'), findsOneWidget);
    expect(find.text('Yakunlash'), findsOneWidget);
    await tester.tap(find.byKey(const Key('setup-goal-gain')));
    await tester.tap(find.byKey(const Key('setup-continue')));
    await tester.pumpAndSettle();

    final saved = profiles.saved!;
    expect(saved.firstName, 'Ali');
    expect(saved.age, 25);
    expect(saved.heightCm, 180);
    expect(saved.weightKg, 80);
    expect(saved.activityLevel, 'high');
    expect(saved.goal, 'gain');
    expect(await OnboardingStore().isInProgress(), isFalse);
    expect(tester.takeException(), isNull);
  });
}
