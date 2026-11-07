import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myfit/models/user_profile.dart';
import 'package:myfit/screens/auth_gate.dart';
import 'package:myfit/screens/profile_setup_page.dart';
import 'package:myfit/services/auth_service.dart';
import 'package:myfit/services/profile_service.dart';

class StubAuth implements FirebaseAuth {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class StubFirestore implements FirebaseFirestore {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class StubStorage implements FirebaseStorage {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class TestUser implements User {
  @override
  String get uid => 'test-user';
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class TestAuth extends AuthService {
  TestAuth() : super(auth: StubAuth());
  int subscriptions = 0;
  @override
  Stream<User?> authStateChanges() {
    subscriptions++;
    return Stream.value(TestUser());
  }
}

class TestProfiles extends ProfileService {
  TestProfiles() : super(firestore: StubFirestore(), storage: StubStorage());
  int subscriptions = 0;
  @override
  Stream<UserProfile?> watchProfile(String uid) {
    subscriptions++;
    return Stream.value(null);
  }
}

void main() {
  testWidgets('Parent rebuild preserves auth and profile subscriptions', (
    tester,
  ) async {
    final auth = TestAuth();
    final profiles = TestProfiles();
    Widget app(Color color) => MaterialApp(
      theme: ThemeData(colorSchemeSeed: color),
      home: AuthGate(
        authService: auth,
        profileService: profiles,
        onLocaleChanged: (_) {},
      ),
    );
    await tester.pumpWidget(app(Colors.green));
    await tester.pumpAndSettle();
    expect(find.byType(ProfileSetupPage), findsOneWidget);
    await tester.pumpWidget(app(Colors.blue));
    await tester.pumpAndSettle();
    expect(auth.subscriptions, 1);
    expect(profiles.subscriptions, 1);
  });
}
