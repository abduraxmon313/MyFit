import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myfit/models/food_nutrition.dart';
import 'package:myfit/screens/food_search_page.dart';
import 'package:myfit/screens/otp_verify_page.dart';
import 'package:myfit/screens/water_calculator_page.dart';
import 'package:myfit/services/auth_service.dart';
import 'package:myfit/services/food_data_service.dart';

FoodNutrition food(String name) => FoodNutrition(
  fdcId: 1,
  name: name,
  calories: 100,
  protein: 2,
  fat: 1,
  carbohydrates: 20,
  water: 50,
);

class PendingSearch extends FoodDataService {
  final requests = <String, Completer<List<FoodNutrition>>>{};

  @override
  Future<List<FoodNutrition>> search(
    String query, {
    String languageCode = 'uz',
  }) {
    return (requests[query] = Completer<List<FoodNutrition>>()).future;
  }
}

class UnusedAuth implements FirebaseAuth {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class SignedInCredential implements UserCredential {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class AutoVerifiedAuth extends AuthService {
  AutoVerifiedAuth() : super(auth: UnusedAuth());
  void Function(PhoneAuthCredential)? complete;

  @override
  Future<void> sendOtp({
    required String phoneNumber,
    required void Function(String, int?) onCodeSent,
    required void Function(FirebaseAuthException) onError,
    void Function(PhoneAuthCredential)? onAutoVerified,
    Duration timeout = const Duration(seconds: 60),
    int? forceResendingToken,
  }) async {
    complete = onAutoVerified;
  }

  @override
  Future<UserCredential> signInWithCredential(
    PhoneAuthCredential credential,
  ) async {
    return SignedInCredential();
  }
}

void main() {
  testWidgets('An older search response cannot replace the latest results', (
    tester,
  ) async {
    final service = PendingSearch();
    await tester.pumpWidget(
      MaterialApp(home: FoodSearchPage(service: service)),
    );
    await tester.enterText(find.byType(TextField), 'first');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'second');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();
    service.requests['second']!.complete([food('Newest result')]);
    await tester.pumpAndSettle();
    service.requests['first']!.complete([food('Old result')]);
    await tester.pumpAndSettle();
    expect(find.text('Newest result'), findsOneWidget);
    expect(find.text('Old result'), findsNothing);
  });

  testWidgets('Automatic SMS verification closes the OTP route', (
    tester,
  ) async {
    final auth = AutoVerifiedAuth();
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => OtpVerifyPage(
                    authService: auth,
                    phoneNumber: '+998901234567',
                    autoSend: true,
                  ),
                ),
              ),
              child: const Text('Open OTP'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open OTP'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(auth.complete, isNotNull);
    auth.complete!(
      PhoneAuthProvider.credential(verificationId: 'test', smsCode: '123456'),
    );
    await tester.pumpAndSettle();
    expect(find.byType(OtpVerifyPage), findsNothing);
    expect(find.text('Open OTP'), findsOneWidget);
  });

  testWidgets('Water calculator rejects non-finite input without crashing', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: WaterCalculatorPage()));
    await tester.enterText(find.byType(TextField).first, 'NaN');
    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.textContaining('NaN'), findsOneWidget); // Only the input.
    expect(find.textContaining('litr'), findsNothing);
  });
}
