import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myfit/models/user_profile.dart';
import 'package:myfit/screens/home_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_gate_regression_test.dart' show TestAuth;

class _Auth extends TestAuth {
  @override
  User? get currentUser => null;
}

class _Fb extends MockFirebaseApp {
  @override
  Future<List<CoreInitializeResponse>> initializeCore() async => [
    CoreInitializeResponse(
      name: '[DEFAULT]',
      options: CoreFirebaseOptions(
        apiKey: 'p',
        appId: 'p',
        messagingSenderId: 'p',
        projectId: 'p',
        storageBucket: 'p.appspot.com',
      ),
      pluginConstants: {},
    ),
  ];
}

UserProfile _profile(double weight) => UserProfile(
  firstName: 'Test',
  lastName: 'User',
  gender: 'male',
  age: 28,
  heightCm: 182,
  weightKg: weight,
  activityLevel: 'medium',
  goal: 'maintain',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  TestFirebaseCoreHostApi.setUp(_Fb());
  setUpAll(() async => Firebase.initializeApp());
  setUp(() => SharedPreferences.setMockInitialValues({}));

  // 182 cm: 101 kg → BMI 30.5 (semizlik), 84 kg → 25.4, 70 kg → 21.1.
  for (final (weight, band) in [(101.0, 3), (84.0, 2), (70.0, 1)]) {
    testWidgets('BMI marker and labels agree for $weight kg', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 1200);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: HomePage(authService: _Auth(), profile: _profile(weight)),
        ),
      );
      await tester.pumpAndSettle();

      final marker = tester.getCenter(find.byKey(const Key('bmi-marker'))).dx;
      final bandRect = tester.getRect(find.byKey(Key('bmi-band-$band')));
      expect(marker, inInclusiveRange(bandRect.left, bandRect.right));

      // Each boundary label is centred under the matching band edge.
      double labelX(String label) =>
          tester.getCenter(find.byKey(Key('bmi-label-$label'))).dx;
      final bands = [
        for (var i = 0; i < 4; i++)
          tester.getRect(find.byKey(Key('bmi-band-$i'))),
      ];
      expect(labelX('18.5'), closeTo(bands[0].right, 4));
      expect(labelX('25'), closeTo(bands[1].right, 4));
      expect(labelX('30'), closeTo(bands[2].right, 4));
      if (band == 3) expect(marker, greaterThan(labelX('30')));
      expect(tester.takeException(), isNull);
    });
  }
}
