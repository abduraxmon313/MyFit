import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:myfit/models/food_nutrition.dart';
import 'package:myfit/services/body_fat_calculator.dart';
import 'package:myfit/services/calorie_needs_calculator.dart';
import 'package:myfit/services/food_data_service.dart';
import 'package:myfit/services/open_food_facts_service.dart';

const food = FoodNutrition(
  fdcId: 1,
  name: 'Test',
  calories: 200,
  protein: 10,
  fat: 5,
  carbohydrates: 20,
  water: 50,
  vitaminDMcg: 4,
);

void main() {
  test('Changing an existing portion preserves its per-gram nutrients', () {
    final portion = food.forGrams(150).forGrams(200);
    expect(portion.calories, 400);
    expect(portion.protein, 20);
    expect(portion.vitaminDMcg, 8);
  });

  test('Non-finite and non-positive portions are rejected', () {
    for (final grams in [double.nan, double.infinity, -1.0, 0.0]) {
      expect(() => food.forGrams(grams), throwsArgumentError);
    }
  });

  test('Calorie calculator rejects NaN measurements', () {
    expect(
      () => const CalorieNeedsCalculator().calculate(
        age: 30,
        sex: BiologicalSex.male,
        heightCm: 175,
        weightKg: double.nan,
        activityFactor: 1.2,
      ),
      throwsA(isA<CalorieNeedsException>()),
    );
  });

  test('Body fat calculator rejects NaN weight', () {
    expect(
      () => const BodyFatCalculator().calculate(
        age: 30,
        sex: BiologicalSex.male,
        heightCm: 175,
        weightKg: double.nan,
        neckCm: 38,
        waistCm: 90,
      ),
      throwsA(isA<BodyFatException>()),
    );
  });

  test('Malformed USDA response still uses Open Food Facts fallback', () async {
    final client = MockClient((request) async {
      if (request.url.host == 'api.nal.usda.gov') {
        return http.Response('<html>temporarily unavailable</html>', 200);
      }
      if (request.url.host == 'world.openfoodfacts.org') {
        return http.Response(
          jsonEncode({
            'products': [
              {
                'code': '12345678',
                'product_name': 'Fallback food',
                'nutriments': {'energy-kcal_100g': 100, 'proteins_100g': 2},
              },
            ],
          }),
          200,
        );
      }
      return http.Response('{}', 200);
    });
    final results = await FoodDataService(
      client: client,
    ).search('quinoa', languageCode: 'en');
    expect(results.any((item) => item.name == 'Fallback food'), isTrue);
  });

  test('Barcode lookup accepts explicitly zero-calorie drinks', () async {
    final service = OpenFoodFactsService(
      client: MockClient((_) async {
        return http.Response(
          jsonEncode({
            'status': 1,
            'product': {
              'code': '12345678',
              'product_name': 'Zero drink',
              'nutriments': {
                'energy-kcal_100g': 0,
                'proteins_100g': 0,
                'fat_100g': 0,
                'carbohydrates_100g': 0,
              },
            },
          }),
          200,
        );
      }),
    );
    final result = await service.findByBarcode('12345678');
    expect(result, isNotNull);
    expect(result!.calories, 0);
  });

  test('Products with no nutrition data remain excluded', () async {
    final service = OpenFoodFactsService(
      client: MockClient((_) async {
        return http.Response(
          jsonEncode({
            'status': 1,
            'product': {
              'code': '12345678',
              'product_name': 'Missing data',
              'nutriments': {},
            },
          }),
          200,
        );
      }),
    );
    expect(await service.findByBarcode('12345678'), isNull);
  });

  test('USDA nutrient IDs distinguish total fat from saturated fat', () async {
    final service = FoodDataService(
      client: MockClient((request) async {
        if (request.url.host != 'api.nal.usda.gov') {
          return http.Response('{}', 200);
        }
        return http.Response(
          jsonEncode({
            'foods': [
              {
                'fdcId': 42,
                'description': 'Quinoa test',
                'foodNutrients': [
                  {
                    'nutrientId': 1258,
                    'nutrientName': 'Fatty acids, total saturated',
                    'value': 2,
                    'unitName': 'G',
                  },
                  {
                    'nutrientId': 1004,
                    'nutrientName': 'Total lipid (fat)',
                    'value': 10,
                    'unitName': 'G',
                  },
                  {
                    'nutrientId': 1008,
                    'nutrientName': 'Energy',
                    'value': 100,
                    'unitName': 'KCAL',
                  },
                ],
              },
            ],
          }),
          200,
        );
      }),
    );
    final result = (await service.search(
      'quinoa',
      languageCode: 'en',
    )).singleWhere((item) => item.fdcId == 42);
    expect(result.fat, 10);
    expect(result.hasWaterData, isFalse);
  });
}
