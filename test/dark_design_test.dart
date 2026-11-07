import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myfit/l10n/app_localizations.dart';
import 'package:myfit/models/user_profile.dart';
import 'package:myfit/screens/calculator_page.dart';
import 'package:myfit/screens/calorie_calculator_page.dart';
import 'package:myfit/screens/body_fat_calculator_page.dart';
import 'package:myfit/screens/water_calculator_page.dart';
import 'package:myfit/screens/meals_page.dart';
import 'package:myfit/screens/profile_page.dart';
import 'package:myfit/screens/workouts_page.dart';
import 'package:myfit/theme/app_theme.dart';

void main() {
  test('existing appearance choices persist across profile versions', () {
    expect(UserProfile.fromMap({'themeMode': 'light'}).themeMode, 'light');
    expect(
      UserProfile.fromMap({
        'themeMode': 'light',
        'appearanceVersion': 2,
      }).themeMode,
      'light',
    );
    final profile = UserProfile.fromMap({});
    expect(UserProfile.fromMap(profile.toMap()).themeMode, 'dark');
  });
  testWidgets('both appearances fit narrow screens and enlarged text', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
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
    final pages = <Widget>[
      MealsPage(onMealSelected: (_) {}),
      ProfilePage(
        profile: profile,
        phoneNumber: '',
        onSave: (_) async {},
        onSignOut: () async {},
      ),
      WorkoutsPage(
        weightKg: 75,
        logs: const [],
        onAdded: (_) {},
        onRemoved: (_) {},
      ),
      const CalculatorPage(),
      const CalorieCalculatorPage(),
      const BodyFatCalculatorPage(),
      const WaterCalculatorPage(),
    ];
    for (final theme in [AppTheme.light, AppTheme.dark]) {
      for (final width in [320.0, 430.0]) {
        tester.view.physicalSize = Size(width, 960);
        for (final page in pages) {
          await tester.pumpWidget(
            MaterialApp(
              theme: theme,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              locale: const Locale('uz'),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(1.5)),
                child: child!,
              ),
              home: Scaffold(body: page),
            ),
          );
          await tester.pumpAndSettle();
          expect(
            tester.takeException(),
            isNull,
            reason: '${page.runtimeType} at $width',
          );
        }
      }
    }
  });

  testWidgets('meals midnight preview uses working add buttons', (
    tester,
  ) async {
    final previousShadows = debugDisableShadows;
    debugDisableShadows = false;
    addTearDown(() => debugDisableShadows = previousShadows);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(430, 1300);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final fontDir = Platform.environment['MYFIT_FONT_DIRECTORY'];
    if (fontDir != null) {
      final font = FontLoader('Roboto');
      for (final name in [
        'roboto-regular.ttf',
        'roboto-medium.ttf',
        'roboto-bold.ttf',
      ]) {
        font.addFont(
          Future.value(
            ByteData.sublistView(File('$fontDir/$name').readAsBytesSync()),
          ),
        );
      }
      await font.load();
      final icons = FontLoader('MaterialIcons');
      icons.addFont(
        Future.value(
          ByteData.sublistView(
            File('$fontDir/materialicons-regular.otf').readAsBytesSync(),
          ),
        ),
      );
      await icons.load();
    }
    for (final theme in [AppTheme.light, AppTheme.dark]) {
      final boundary = GlobalKey();
      MealType? selected;
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('uz'),
          home: RepaintBoundary(
            key: boundary,
            child: Scaffold(
              body: SafeArea(
                child: MealsPage(onMealSelected: (meal) => selected = meal),
              ),
              bottomNavigationBar: NavigationBar(
                selectedIndex: 1,
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.home_outlined),
                    label: 'Bosh sahifa',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.restaurant_outlined),
                    label: 'Ovqatlar',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.fitness_center_outlined),
                    label: 'Mashqlar',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.person_outline),
                    label: 'Profil',
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(
        () => precacheImage(
          const AssetImage('assets/images/meal_photography.png'),
          boundary.currentContext!,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nonushta'));
      expect(selected, MealType.breakfast);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Nonushta'));
      await tester.pumpAndSettle();
      final previewDir = Platform.environment['MYFIT_PREVIEW_DIR'];
      if (previewDir != null) {
        await tester.runAsync(() async {
          final image =
              await (boundary.currentContext!.findRenderObject()
                      as RenderRepaintBoundary)
                  .toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          Directory(previewDir).createSync(recursive: true);
          File(
            '$previewDir/meals-${theme.brightness == Brightness.dark ? 'midnight' : 'light'}.png',
          ).writeAsBytesSync(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
    }
    debugDisableShadows = previousShadows;
  });
}
