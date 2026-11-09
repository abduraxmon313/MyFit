// Renders every main screen to PNG for visual review.
// Run: MYFIT_PREVIEW_DIR=/path flutter test test/design_gallery_preview_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myfit/data/uzbek_food_catalog.dart';
import 'package:myfit/l10n/app_localizations.dart';
import 'package:myfit/models/food_nutrition.dart';
import 'package:myfit/models/user_profile.dart';
import 'package:myfit/screens/body_fat_calculator_page.dart';
import 'package:myfit/screens/calculator_page.dart';
import 'package:myfit/screens/calorie_calculator_page.dart';
import 'package:myfit/screens/custom_food_page.dart';
import 'package:myfit/screens/home_page.dart';
import 'package:myfit/screens/meals_page.dart';
import 'package:myfit/screens/national_food_picker_page.dart';
import 'package:myfit/screens/phone_login_page.dart';
import 'package:myfit/screens/water_calculator_page.dart';
import 'package:myfit/services/food_data_service.dart';
import 'package:myfit/services/food_log_service.dart';
import 'package:myfit/services/search_history_store.dart';
import 'package:myfit/theme/app_theme.dart';
import 'package:myfit/widgets/food_portion_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_gate_regression_test.dart' show TestAuth, TestUser;

class _User extends TestUser {
  @override
  String? get phoneNumber => '+998 90 123 45 67';
}

class _Auth extends TestAuth {
  @override
  User? get currentUser => _User();
}

FoodNutrition _food(String name, String meal, double kcal, double grams) =>
    FoodNutrition(
      fdcId: name.hashCode,
      name: name,
      localName: name,
      calories: kcal,
      protein: kcal * .06,
      carbohydrates: kcal * .1,
      fat: kcal * .03,
      water: 0,
      grams: grams,
      mealType: meal,
    );

final _today = [
  _food('Sut 3,25%', 'breakfast', 122, 200),
  _food('Gerkules bo‘tqasi', 'breakfast', 210, 250),
  _food('Tovuq filesi', 'lunch', 248, 150),
  _food('Guruch, qaynatilgan', 'lunch', 195, 150),
];

class _Logs implements FoodLogService {
  @override
  Future<List<FoodNutrition>> loadToday(String uid) async => _today;
  @override
  Future<Map<DateTime, double>> loadCurrentWeekCalories(String uid) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final monday = today.subtract(Duration(days: today.weekday - 1));
    return {
      for (var i = 0; i < today.weekday; i++)
        monday.add(Duration(days: i)): const <double>[
          1850,
          2200,
          1640,
          2050,
          1980,
          2300,
          775,
        ][i],
    };
  }

  @override
  Future<Map<DateTime, List<FoodNutrition>>> loadRange(
    String uid,
    DateTime start,
    DateTime end,
  ) async => {
    for (var d = start; !d.isAfter(end); d = d.add(const Duration(days: 1)))
      d: [
        for (final meal in ['breakfast', 'lunch', 'dinner', 'snack'])
          _food('Ovqat', meal, 380.0 + d.day * 9 % 120, 200),
      ],
  };

  @override
  Future<void> saveToday(String uid, List<FoodNutrition> foods) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Offline extends FoodDataService {
  @override
  Future<List<FoodNutrition>> search(
    String query, {
    String languageCode = 'uz',
  }) async => [];
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

const _profile = UserProfile(
  firstName: 'Abduraxmon',
  lastName: 'Xakimjonov',
  gender: 'male',
  age: 28,
  heightCm: 182,
  weightKg: 84,
  activityLevel: 'medium',
  goal: 'maintain',
);

Future<void> _loadFonts() async {
  final inter = FontLoader('Inter');
  for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
    inter.addFont(
      Future.value(
        ByteData.sublistView(
          File('assets/fonts/inter/Inter-$w.ttf').readAsBytesSync(),
        ),
      ),
    );
  }
  await inter.load();
  final lucide = FontLoader('packages/lucide_icons_flutter/Lucide')
    ..addFont(
      rootBundle.load('packages/lucide_icons_flutter/assets/lucide.ttf'),
    );
  await lucide.load();
  final material = FontLoader('MaterialIcons')
    ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
  await material.load();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  TestFirebaseCoreHostApi.setUp(_Fb());
  setUpAll(() async => Firebase.initializeApp());

  testWidgets('design gallery', (tester) async {
    final out = Platform.environment['MYFIT_PREVIEW_DIR'];
    if (out == null) return;
    SharedPreferences.setMockInitialValues({});
    await _loadFonts();
    await SearchHistoryStore.shared.load();
    for (final q in ['Oddiy tuxum', 'Sut 3,25%', 'Malina']) {
      await SearchHistoryStore.shared.add(q);
    }
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Future<void> shot(GlobalKey key, String name) async {
      for (var r = 0; r < 2; r++) {
        await tester.runAsync(() async {
          for (final e in find.byType(Image).evaluate()) {
            await precacheImage((e.widget as Image).image, e);
          }
        });
        for (var i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 300));
        }
      }
      await tester.runAsync(() async {
        final image =
            await (key.currentContext!.findRenderObject()
                    as RenderRepaintBoundary)
                .toImage(pixelRatio: 2);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        Directory(out).createSync(recursive: true);
        File('$out/$name.png').writeAsBytesSync(data!.buffer.asUint8List());
      });
    }

    Future<GlobalKey> show(Widget home, bool dark, Size size) async {
      tester.view.physicalSize = size;
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: dark ? AppTheme.dark : AppTheme.light,
            locale: const Locale('uz'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: home,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      return key;
    }

    const phone = Size(390, 844);
    for (final dark in [false, true]) {
      final m = dark ? 'dark' : 'light';
      HomePage home() => HomePage(
        authService: _Auth(),
        profile: _profile,
        foodLogService: _Logs(),
      );
      var key = await show(home(), dark, const Size(390, 1100));
      await shot(key, '01-home-$m');
      for (final (tab, name) in [
        (1, '02-meals'),
        (2, '03-workouts'),
        (3, '04-profile'),
        (4, '05-reports'),
      ]) {
        key = await show(home(), dark, const Size(390, 1300));
        await tester.tap(find.byType(NavigationDestination).at(tab));
        await shot(key, '$name-$m');
      }
      key = await show(home(), dark, const Size(1280, 860));
      await shot(key, '06-home-desktop-$m');

      key = await show(
        NationalFoodPickerPage(
          meal: MealType.breakfast,
          foodDataService: _Offline(),
        ),
        dark,
        phone,
      );
      await shot(key, '07-search-$m');
      await tester.enterText(find.byType(TextField), 'malina');
      await tester.pump(const Duration(milliseconds: 600));
      await shot(key, '08-search-results-$m');

      final malina = kUzbekDishes
          .firstWhere((d) => d.nameUz == 'Malina')
          .nutrition;
      key = await show(
        Scaffold(
          body: SafeArea(
            child: FoodPortionSheet(
              food: malina,
              title: 'Malina',
              subtitle: 'Hudud: O‘rmon mevalari',
              actionLabel: 'Saqlash',
            ),
          ),
        ),
        dark,
        phone,
      );
      await shot(key, '09-portion-$m');
      key = await show(const CalculatorPage(), dark, phone);
      await shot(key, '10-calculators-$m');
      key = await show(
        const CalorieCalculatorPage(),
        dark,
        const Size(390, 1500),
      );
      await shot(key, '11-calorie-$m');
      key = await show(
        const BodyFatCalculatorPage(),
        dark,
        const Size(390, 1300),
      );
      await shot(key, '12-bodyfat-$m');
      key = await show(const WaterCalculatorPage(), dark, phone);
      await shot(key, '13-water-$m');
      key = await show(const CustomFoodPage(), dark, const Size(390, 1300));
      await shot(key, '14-custom-food-$m');
      key = await show(PhoneLoginPage(authService: _Auth()), dark, phone);
      await shot(key, '15-login-$m');
    }
  });
}
