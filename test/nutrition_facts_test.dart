import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myfit/data/uzbek_food_catalog.dart';
import 'package:myfit/l10n/app_localizations.dart';
import 'package:myfit/models/food_nutrition.dart';
import 'package:myfit/widgets/nutrition_facts.dart';
import 'package:myfit/widgets/food_portion_sheet.dart';

void main() {
  final egg = kUzbekDishes
      .singleWhere((d) => d.nutrition.fdcId == -1200)
      .nutrition;
  test('Medium egg matches reference without rounding before scaling', () {
    expect(foodPieceSizes(egg), [38, 44, 50]);
    final medium = egg.forGrams(44);
    expect(medium.calories.round(), 65);
    expect((medium.calories * 4.184).round(), 271);
    expect(medium.protein.toStringAsFixed(2), '5.54');
    expect(medium.fat.toStringAsFixed(2), '4.37');
    expect(medium.carbohydrates.toStringAsFixed(2), '0.34');
    expect(medium.saturatedFat.toStringAsFixed(3), '1.364');
    expect(medium.monounsaturatedFat!.toStringAsFixed(3), '1.676');
    expect(medium.polyunsaturatedFat!.toStringAsFixed(3), '0.600');
    expect(medium.sugars.toStringAsFixed(2), '0.34');
    expect(medium.sodiumMg.round(), 62);
    expect(medium.cholesterolMg.round(), 186);
    final restored = FoodNutrition.fromMap(
      medium.withMealType('breakfast').toMap(),
    );
    expect(restored.monounsaturatedFat, medium.monounsaturatedFat);
    expect(restored.polyunsaturatedFat, medium.polyunsaturatedFat);
    expect(restored.knownNutrients, contains('fiber'));
    final twice = restored.forGrams(88);
    expect(twice.protein, closeTo(11.0704, 0.000001));
    expect(twice.sodiumMg, closeTo(123.2, 0.000001));
    expect(twice.cholesterolMg, closeTo(372.24, 0.000001));
  });

  testWidgets('Russian table renders reference values on a narrow screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ru'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(
          body: SingleChildScrollView(
            child: NutritionFacts(
              food: egg.forGrams(44),
              portion: '1 средняя штука (44 г)',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (final text in ['5,54 г', '4,37 г', '0,34 г']) {
      expect(find.text(text), findsOneWidget);
    }
    // Faqat kaloriya, oqsil, uglevod va yog' ko'rsatiladi.
    for (final text in ['1,364 г', '62 мг', '186 мг']) {
      expect(find.text(text), findsNothing);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('Missing details show a dash instead of a fabricated zero', (
    tester,
  ) async {
    final unknown = FoodNutrition.fromMap({'name': 'Unknown'});
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: NutritionFacts(food: unknown, portion: '100 g'),
          ),
        ),
      ),
    );
    // Qo'shimcha moddalar (natriy, kletchatka va h.k.) endi ko'rsatilmaydi.
    for (final label in ['Natriy', 'Kletchatka', 'Shakar', 'Kaliy']) {
      expect(find.text(label), findsNothing);
    }
    expect(find.text('Oqsil'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
