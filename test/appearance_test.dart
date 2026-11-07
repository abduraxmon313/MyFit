import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:myfit/main.dart';
import 'package:myfit/screens/auth_gate.dart';
import 'package:myfit/services/appearance_store.dart';
import 'package:myfit/theme/app_theme.dart';
import 'package:myfit/widgets/appearance_selector.dart';

import 'auth_gate_regression_test.dart' show TestAuth, TestProfiles;

class SignedOutAuth extends TestAuth {
  @override
  Stream<User?> authStateChanges() => Stream.value(null);
}

class FailingAppearanceStore extends AppearanceStore {
  @override
  Future<void> save(String mode) async => throw StateError('Disk unavailable');
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'appearance survives reopening and ignores invalid stored values',
    () async {
      expect(await AppearanceStore().load(), isNull);
      for (final mode in ['light', 'dark']) {
        await AppearanceStore().save(mode);
        expect(await AppearanceStore().load(), mode);
      }
      SharedPreferences.setMockInitialValues({
        AppearanceStore.storageKey: 'invalid',
      });
      expect(await AppearanceStore().load(), isNull);
      await expectLater(AppearanceStore().save('invalid'), throwsArgumentError);
    },
  );

  testWidgets('offline cloud writes cannot block or reverse local changes', (
    tester,
  ) async {
    var mode = 'dark';
    final pendingCloud = <Completer<void>>[];
    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) => MaterialApp(
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: mode == 'dark' ? ThemeMode.dark : ThemeMode.light,
          home: Scaffold(
            body: AppearanceSelector(
              selected: mode,
              onChanged: (value) => setState(() => mode = value),
              onSave: (_) {
                final pending = Completer<void>();
                pendingCloud.add(pending);
                return pending.future;
              },
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Oq rejim'));
    await tester.pump();
    expect(
      tester
          .widget<SegmentedButton<String>>(find.byType(SegmentedButton<String>))
          .selected,
      {'light'},
    );
    await tester.pumpAndSettle();
    expect(mode, 'light');
    expect(await AppearanceStore().load(), 'light');
    expect(
      tester
          .widget<SegmentedButton<String>>(find.byType(SegmentedButton<String>))
          .selected,
      {'light'},
    );
    await tester.tap(find.text('Qora rejim'));
    await tester.pumpAndSettle();
    expect(mode, 'dark');
    expect(await AppearanceStore().load(), 'dark');
    for (final pending in pendingCloud) {
      pending.completeError(StateError('Offline'));
    }
    await tester.pumpAndSettle();
    expect(mode, 'dark');
    expect(tester.takeException(), isNull);
  });

  testWidgets('local save failure restores the previous appearance', (
    tester,
  ) async {
    var mode = 'dark';
    var cloudWrites = 0;
    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) => MaterialApp(
          home: Scaffold(
            body: AppearanceSelector(
              selected: mode,
              store: FailingAppearanceStore(),
              onChanged: (value) => setState(() => mode = value),
              onSave: (_) async {
                cloudWrites++;
              },
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Oq rejim'));
    await tester.pumpAndSettle();
    expect(mode, 'dark');
    expect(cloudWrites, 0);
    expect(find.byType(SnackBar), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'startup uses saved light mode and stale cloud cannot override it',
    (tester) async {
      await AppearanceStore().save('light');
      await tester.pumpWidget(
        MyFitApp(
          authService: SignedOutAuth(),
          profileService: TestProfiles(),
          initialAppearance: await AppearanceStore().load(),
        ),
      );
      await tester.pumpAndSettle();
      BuildContext pageContext() => tester.element(find.byType(AuthGate));
      expect(Theme.of(pageContext()).brightness, Brightness.light);
      tester.widget<AuthGate>(find.byType(AuthGate)).onProfileThemeChanged!(
        'dark',
      );
      await tester.pumpAndSettle();
      expect(Theme.of(pageContext()).brightness, Brightness.light);
      tester.widget<AuthGate>(find.byType(AuthGate)).onThemeChanged!('dark');
      await tester.pumpAndSettle();
      expect(Theme.of(pageContext()).brightness, Brightness.dark);
      expect(tester.takeException(), isNull);
    },
  );

  test('system bars follow the current appearance', () {
    expect(
      AppTheme.systemOverlay(AppTheme.light).statusBarIconBrightness,
      Brightness.dark,
    );
    expect(
      AppTheme.systemOverlay(AppTheme.dark).statusBarIconBrightness,
      Brightness.light,
    );
    expect(
      AppTheme.systemOverlay(AppTheme.light).systemNavigationBarColor,
      AppTheme.light.scaffoldBackgroundColor,
    );
    expect(
      AppTheme.systemOverlay(AppTheme.dark).systemNavigationBarIconBrightness,
      Brightness.light,
    );
  });
}
