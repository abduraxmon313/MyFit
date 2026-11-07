import 'dart:io';
import 'dart:ui' as ui;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
// Firebase's official test helper is exposed by its platform package.
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:myfit/l10n/app_localizations.dart';
import 'package:myfit/models/user_profile.dart';
import 'package:myfit/data/uzbek_food_catalog.dart';
import 'package:myfit/screens/calculator_page.dart';
import 'package:myfit/screens/calorie_calculator_page.dart';
import 'package:myfit/screens/body_fat_calculator_page.dart';
import 'package:myfit/screens/water_calculator_page.dart';
import 'package:myfit/screens/food_search_page.dart';
import 'package:myfit/screens/national_food_picker_page.dart';
import 'package:myfit/screens/meals_page.dart';
import 'package:myfit/services/food_data_service.dart';
import 'package:myfit/widgets/food_portion_sheet.dart';
import 'package:myfit/screens/home_page.dart';
import 'package:myfit/theme/app_theme.dart';
import 'package:myfit/models/food_nutrition.dart';
import 'package:myfit/services/food_log_service.dart';

import 'auth_gate_regression_test.dart' show TestAuth, TestUser;

class _SignedInAuth extends TestAuth {
  @override
  User? get currentUser => TestUser();
}

class _RetryLogs implements FoodLogService {
  bool fail = true;
  List<FoodNutrition> foods = [];
  int writes = 0;
  @override
  Future<List<FoodNutrition>> loadToday(String uid) async {
    if (fail) throw StateError('offline');
    return foods;
  }

  @override
  Future<Map<DateTime, double>> loadCurrentWeekCalories(String uid) async => {};

  @override
  Future<void> saveToday(String uid, List<FoodNutrition> foods) async {
    writes++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _PreviewAuth extends TestAuth {
  @override
  User? get currentUser => null;
}

class _PreviewFirebase extends MockFirebaseApp {
  @override
  Future<List<CoreInitializeResponse>> initializeCore() async => [
    CoreInitializeResponse(
      name: '[DEFAULT]',
      options: CoreFirebaseOptions(
        apiKey: 'preview',
        appId: 'preview',
        messagingSenderId: 'preview',
        projectId: 'preview',
        storageBucket: 'preview.appspot.com',
      ),
      pluginConstants: {},
    ),
  ];
}

const _profile = UserProfile(
  firstName: 'Aziz',
  lastName: 'Karimov',
  gender: 'male',
  age: 28,
  heightCm: 182,
  weightKg: 101,
  activityLevel: 'medium',
  goal: 'maintain',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  TestFirebaseCoreHostApi.setUp(_PreviewFirebase());
  setUpAll(() async => Firebase.initializeApp());
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Food log cards fit narrow screens with enlarged text', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 1000);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final logs = _RetryLogs()
      ..fail = false
      ..foods = [
        const FoodNutrition(
          fdcId: 1,
          name: 'A long food name for the daily food journal',
          calories: 127,
          protein: 5.3,
          fat: 3.4,
          carbohydrates: 19,
          water: 0,
        ),
      ];
    for (final theme in [AppTheme.light, AppTheme.dark]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.5)),
            child: child!,
          ),
          home: HomePage(
            authService: _SignedInAuth(),
            profile: _profile,
            foodLogService: logs,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byTooltip('Olib tashlash'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('5.3 g'), findsOneWidget);
      expect(find.text('19.0 g'), findsOneWidget);
      expect(find.byTooltip('Olib tashlash'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('Failed diary load blocks edits and supports retry', (
    tester,
  ) async {
    final logs = _RetryLogs();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: HomePage(
          authService: _SignedInAuth(),
          profile: _profile,
          foodLogService: logs,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Kundalikni yuklab bo‘lmadi.'), findsOneWidget);
    expect(find.text('Ovqatni skanerlash'), findsNothing);
    expect(logs.writes, 0);
    logs.fail = false;
    await tester.tap(find.text('Qayta urinish'));
    await tester.pumpAndSettle();
    expect(find.text('Kundalikni yuklab bo‘lmadi.'), findsNothing);
    expect(find.text('Ovqatni skanerlash'), findsOneWidget);
    expect(logs.writes, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Dark backgrounds stay dark and adapting twice preserves colors',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Builder(
            builder: (context) {
              for (final original in [
                Colors.white,
                const Color(0xFFA0AFC0),
                const Color(0xFF10223C),
                const Color(0xFFE8F8EF),
                const Color(0xFF718079),
              ]) {
                final adapted = context.appColor(original, surface: true);
                expect(
                  adapted.computeLuminance(),
                  lessThan(.08),
                  reason: '$original',
                );
                expect(context.appColor(adapted, surface: true), adapted);
              }
              final scheme = Theme.of(context).colorScheme;
              for (final surface in [
                scheme.surface,
                ...context.appPanelColors,
                scheme.surfaceContainerHigh,
                scheme.surfaceContainerHighest,
              ]) {
                for (final text in [
                  scheme.onSurface,
                  scheme.onSurfaceVariant,
                ]) {
                  final contrast =
                      (text.computeLuminance() + .05) /
                      (surface.computeLuminance() + .05);
                  expect(contrast, greaterThanOrEqualTo(4.5));
                }
              }
              return const Scaffold();
            },
          ),
        ),
      );
    },
  );

  testWidgets('Home actions and navigation fit both themes and all languages', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    for (final theme in [AppTheme.dark, AppTheme.light]) {
      for (final locale in AppLocalizations.supportedLocales) {
        for (final width in [320.0, 390.0]) {
          tester.view.physicalSize = Size(width, 1000);
          await tester.pumpWidget(
            MaterialApp(
              theme: theme,
              locale: locale,
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(1.3)),
                child: child!,
              ),
              home: HomePage(
                key: UniqueKey(),
                authService: _PreviewAuth(),
                profile: _profile,
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(
            tester.takeException(),
            isNull,
            reason: '${theme.brightness} $locale $width',
          );
        }
      }
    }
  });

  testWidgets('Home and all tabs export dark appearance previews', (
    tester,
  ) async {
    final previewDir = Platform.environment['MYFIT_PREVIEW_DIR'];
    if (previewDir == null) return;
    final previousShadows = debugDisableShadows;
    debugDisableShadows = false;
    addTearDown(() => debugDisableShadows = previousShadows);
    final font = FontLoader('Roboto');
    for (final path in [
      'C:/Windows/Fonts/arial.ttf',
      'C:/Windows/Fonts/arialbd.ttf',
    ]) {
      font.addFont(
        Future.value(ByteData.sublistView(File(path).readAsBytesSync())),
      );
    }
    await font.load();
    final icons = FontLoader('MaterialIcons');
    icons.addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 1000);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final boundary = GlobalKey();
    ThemeData previewTheme(ThemeData theme) => theme.copyWith(
      appBarTheme: theme.appBarTheme.copyWith(
        titleTextStyle: theme.appBarTheme.titleTextStyle?.copyWith(
          fontFamily: 'Roboto',
        ),
      ),
      chipTheme: theme.chipTheme.copyWith(
        labelStyle: theme.chipTheme.labelStyle?.copyWith(fontFamily: 'Roboto'),
        secondaryLabelStyle: theme.chipTheme.secondaryLabelStyle?.copyWith(
          fontFamily: 'Roboto',
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: theme.filledButtonTheme.style?.copyWith(
          textStyle: const WidgetStatePropertyAll(
            TextStyle(
              fontFamily: 'Roboto',
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
    Future<void> capture(String name) async {
      await tester.runAsync(() async {
        final image =
            await (boundary.currentContext!.findRenderObject()
                    as RenderRepaintBoundary)
                .toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        Directory(previewDir).createSync(recursive: true);
        File(
          '$previewDir/$name.png',
        ).writeAsBytesSync(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    for (final theme in [AppTheme.dark, AppTheme.light]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: previewTheme(theme),
          locale: const Locale('ru'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: RepaintBoundary(
            key: boundary,
            child: HomePage(
              key: ValueKey(theme.brightness),
              authService: _PreviewAuth(),
              profile: _profile,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (var tab = 0; tab < 4; tab++) {
        await tester.tap(find.byType(NavigationDestination).at(tab));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await capture('${theme.brightness.name}-tab-$tab');
      }
    }
    final oat = kUzbekDishes.firstWhere(
      (dish) => dish.region == 'Gerkules va suli',
    );
    for (final entry in <String, Widget>{
      'calculators': const CalculatorPage(),
      'calories': const CalorieCalculatorPage(),
      'body-fat': const BodyFatCalculatorPage(),
      'water': const WaterCalculatorPage(),
      'food-search': FoodSearchPage(service: FoodDataService()),
      'food-picker': const NationalFoodPickerPage(meal: MealType.breakfast),
      'portion': Scaffold(
        body: FoodPortionSheet(
          food: oat.nutrition,
          title: oat.nameUz,
          subtitle: '100 g',
        ),
      ),
    }.entries) {
      await tester.pumpWidget(
        MaterialApp(
          theme: previewTheme(AppTheme.dark),
          locale: const Locale('uz'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: RepaintBoundary(key: boundary, child: entry.value),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: entry.key);
      await capture('dark-${entry.key}');
    }
    debugDisableShadows = previousShadows;
  });

  testWidgets('Dark workout cards and popup menus use dark surfaces', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: HomePage(authService: _PreviewAuth(), profile: _profile),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    for (final material in tester.widgetList<Material>(find.byType(Material))) {
      final color = material.color;
      if (color != null && color.a == 1) {
        expect(color.computeLuminance(), lessThan(.12));
      }
    }
    await tester.tap(find.byType(PopupMenuItem<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(NavigationDestination).at(2));
    await tester.pumpAndSettle();
    expect(find.byType(Card), findsWidgets);
    for (final card in tester.widgetList<Card>(find.byType(Card))) {
      final context = tester.element(find.byWidget(card));
      final color = card.color ?? Theme.of(context).cardTheme.color!;
      expect(color.computeLuminance(), lessThan(.08));
      expect(
        (Theme.of(context).colorScheme.onSurface.computeLuminance() + .05) /
            (color.computeLuminance() + .05),
        greaterThan(4.5),
      );
    }
    expect(tester.takeException(), isNull);
  });
}
