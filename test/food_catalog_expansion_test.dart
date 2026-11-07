import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:myfit/data/uzbek_food_catalog.dart';
import 'package:myfit/models/food_nutrition.dart';
import 'package:myfit/services/custom_food_store.dart';
import 'package:myfit/services/fatsecret_service.dart';
import 'package:myfit/widgets/food_portion_sheet.dart';

void main() {
  test('Every new food retains the source macros and mineral units', () {
    final snapshot =
        jsonDecode(
              File('data_sources/everyday_catalog.json').readAsStringSync(),
            )
            as Map;
    final records = snapshot['foods'] as List;
    expect(records.length, 122);
    for (final record in records.cast<Map>()) {
      final food = kUzbekDishes
          .singleWhere(
            (dish) => dish.nutrition.fdcId == -(record['fdcId'] as int),
          )
          .nutrition;
      final stored = food.toMap();
      for (final entry in (record['nutrients'] as Map).entries) {
        expect(
          stored[entry.key],
          closeTo((entry.value as num).toDouble(), 1e-10),
          reason: '${food.name}: ${entry.key}',
        );
      }
      expect(food.calories.isFinite, isTrue);
      expect(food.basisUnit, 'g');
      expect(food.labelDetails, contains('https://fdc.nal.usda.gov/'));
      final scaled = FoodNutrition.fromMap(
        food.forGrams(250).withMealType('lunch').toMap(),
      );
      expect(scaled.protein, closeTo(food.protein * 2.5, 1e-10));
      expect(scaled.fat, closeTo(food.fat * 2.5, 1e-10));
      expect(scaled.servings.length, food.servings.length);
    }
  });

  test('New staple groups are searchable without inventing brand matches', () {
    for (final query in [
      'sut',
      'kefir',
      'qatiq',
      'smetana',
      'sariyog',
      'pishloq',
      'baliq',
      'tunets',
      'forel',
      'grechka',
      'makaron',
      'bodom',
      'yeryong',
      'pista',
      'choy',
      'qahva',
      'kola',
      'sharbat',
      'asal',
      'shakar',
      'mayonez',
      'ketchup',
      'lavash',
      'doner',
      'hot-dog',
      'pizza',
      'muzqaymoq',
    ]) {
      expect(searchUzbekFoods(query), isNotEmpty, reason: query);
    }
    final dry = kUzbekDishes
        .singleWhere((d) => d.nutrition.fdcId == -170685)
        .nutrition;
    final cooked = kUzbekDishes
        .singleWhere((d) => d.nutrition.fdcId == -170686)
        .nutrition;
    expect(dry.calories, greaterThan(cooked.calories));
    final milk = kUzbekDishes
        .singleWhere((d) => d.nutrition.fdcId == -172217)
        .nutrition;
    expect(milk.servings.any((s) => s.description.contains('cup')), isTrue);
    expect(
      searchUzbekFoods('grechka', languageCode: 'ru').first.localName,
      contains('Греч'),
    );
  });

  test('Liquid units and original servings survive scaling and storage', () {
    final food = FatSecretService.parseFood({
      'id': 42,
      'name': 'Drink',
      'calories': 40,
      'protein': 0,
      'fat': 0,
      'carbohydrates': 10,
      'basisUnit': 'ml',
      'sodiumMg': 12,
      'sugars': 10,
      'knownNutrients': ['protein', 'fat', 'sodiumMg', 'sugars'],
      'servings': [
        {'description': '1 bottle', 'amount': 250, 'unit': 'ml'},
        {'description': 'incompatible mass', 'amount': 100, 'unit': 'g'},
      ],
    });
    final restored = FoodNutrition.fromMap(
      food.forGrams(250).withMealType('snack').toMap(),
    );
    expect(restored.basisUnit, 'ml');
    expect(restored.calories, 100);
    expect(restored.sodiumMg, 30);
    expect(restored.servings.single.amount, 250);
    expect(restored.missingNutrients, contains('fiber'));
    expect(restored.knownNutrients, contains('fat'));
    expect(restored.hasWaterData, isFalse);
    expect(restored.hasMissingCoreNutrients, isFalse);
    final missing = FatSecretService.parseFood({
      'id': 1,
      'name': 'Incomplete',
      'calories': 0,
      'fat': 0,
      'carbohydrates': 0,
      'sugars': -1,
      'knownNutrients': ['sugars'],
    });
    expect(missing.hasMissingCoreNutrients, isTrue);
    expect(missing.missingNutrients, contains('protein'));
    expect(missing.knownNutrients, isNot(contains('sugars')));
    expect(missing.monounsaturatedFat, isNull);
  });

  test('Concurrent custom label writes survive a new store instance', () async {
    SharedPreferences.setMockInitialValues({});
    const one = FoodNutrition(
      fdcId: -1,
      name: 'Local milk',
      calories: 50,
      protein: 3,
      fat: 2,
      carbohydrates: 5,
      water: 0,
      hasWaterData: false,
      basisUnit: 'ml',
    );
    const two = FoodNutrition(
      fdcId: -2,
      name: 'Local bread',
      calories: 240,
      protein: 8,
      fat: 2,
      carbohydrates: 46,
      water: 0,
    );
    await Future.wait([
      CustomFoodStore().save(one),
      CustomFoodStore().save(two),
    ]);
    final restored = await CustomFoodStore().load();
    expect(
      restored.map((f) => f.name),
      containsAll(['Local milk', 'Local bread']),
    );
    expect(restored.singleWhere((f) => f.fdcId == -1).basisUnit, 'ml');
  });

  testWidgets(
    'Liquid source servings display ml and preview a complete bottle',
    (tester) async {
      const food = FoodNutrition(
        fdcId: 1,
        name: 'Drink',
        calories: 40,
        protein: 0,
        fat: 0,
        carbohydrates: 10,
        water: 0,
        basisUnit: 'ml',
        servings: [
          FoodServing(description: '1 bottle', amount: 250, unit: 'ml'),
        ],
      );
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FoodPortionSheet(
              food: food,
              title: 'Drink',
              subtitle: '100 ml',
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('source-portion-unit')));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('1 bottle').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('portion-amount')), '1');
      await tester.pump();
      expect(find.text('250 ml'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
