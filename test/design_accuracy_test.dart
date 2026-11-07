import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:myfit/data/uzbek_food_catalog.dart';
import 'package:myfit/l10n/app_localizations.dart';
import 'package:myfit/services/open_food_facts_service.dart';
import 'package:myfit/services/food_data_service.dart';
import 'package:myfit/theme/app_theme.dart';
import 'package:myfit/widgets/food_portion_sheet.dart';

void main() {
  test(
    'OFF preserves zero kcal, converts mineral grams, and flags missing protein',
    () async {
      final client = MockClient(
        (_) async => http.Response(
          jsonEncode({
            'products': [
              {
                'code': '1234',
                'product_name': 'Test food',
                'nutriments': {
                  'energy-kcal_100g': 0,
                  'energy-kj_100g': 10,
                  'fat_100g': 0,
                  'carbohydrates_100g': 0,
                  'sodium_100g': .062,
                  'cholesterol_100g': .186,
                  'monounsaturated-fat_100g': 1.676,
                },
              },
            ],
          }),
          200,
        ),
      );
      final food = (await OpenFoodFactsService(
        client: client,
      ).search('Test food')).single;
      expect(food.calories, 0);
      expect(food.sodiumMg, 62);
      expect(food.cholesterolMg, 186);
      expect(food.missingNutrients, {'protein'});
      expect(food.forGrams(200).sodiumMg, 124);
      expect(food.forGrams(200).dataSource, 'Open Food Facts');
    },
  );

  test('USDA uses deterministic kcal and converts grams to mg', () async {
    final client = MockClient((request) async {
      if (request.url.host != 'api.nal.usda.gov') {
        return http.Response('{}', 200);
      }
      return http.Response(
        jsonEncode({
          'foods': [
            {
              'fdcId': 999,
              'description': 'Test quinoa',
              'foodNutrients': [
                {'nutrientId': 1062, 'unitName': 'KJ', 'value': 418.4},
                {'nutrientId': 1008, 'unitName': 'KCAL', 'value': 99},
                {'nutrientId': 1003, 'unitName': 'G', 'value': 4},
                {'nutrientId': 1004, 'unitName': 'G', 'value': 2},
                {'nutrientId': 1005, 'unitName': 'G', 'value': 15},
                {'nutrientId': 1093, 'unitName': 'G', 'value': .14},
                {'nutrientId': 1292, 'unitName': 'G', 'value': 1},
              ],
            },
          ],
        }),
        200,
      );
    });
    final service = FoodDataService(client: client);
    for (var i = 0; i < 2; i++) {
      final food = (await service.search(
        'quinoa',
        languageCode: 'en',
      )).singleWhere((f) => f.fdcId == 999);
      expect(food.calories, 99);
      expect(food.sodiumMg, closeTo(140, .000001));
      expect(food.monounsaturatedFat, 1);
      expect(food.dataSource, 'USDA FoodData Central');
      expect(food.missingNutrients, isEmpty);
    }
  });

  test('Primary text and button colors meet normal text contrast', () {
    double contrast(Color a, Color b) {
      final values = [a.computeLuminance(), b.computeLuminance()]..sort();
      return (values.last + .05) / (values.first + .05);
    }

    for (final theme in [AppTheme.light, AppTheme.dark]) {
      final c = theme.colorScheme;
      expect(contrast(c.primary, c.onPrimary), greaterThanOrEqualTo(4.5));
      expect(
        contrast(c.primaryContainer, c.onPrimaryContainer),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        contrast(c.surface, c.onSurfaceVariant),
        greaterThanOrEqualTo(4.5),
      );
    }
  });

  testWidgets(
    'Portion sheet fits narrow screens with enlarged text in both themes',
    (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final egg = kUzbekDishes
          .singleWhere((d) => d.nutrition.fdcId == -1200)
          .nutrition;
      for (final theme in [AppTheme.light, AppTheme.dark]) {
        for (final locale in AppLocalizations.supportedLocales) {
          await tester.pumpWidget(
            MaterialApp(
              theme: theme,
              locale: locale,
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(1.5)),
                child: child!,
              ),
              home: Scaffold(
                body: FoodPortionSheet(
                  food: egg,
                  title: 'Tuxum',
                  subtitle: '100 g',
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
      }
    },
  );
}
