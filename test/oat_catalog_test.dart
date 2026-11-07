import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:myfit/data/uzbek_food_catalog.dart';
import 'package:myfit/models/food_nutrition.dart';
import 'package:myfit/widgets/food_portion_sheet.dart';

void main() {
  final oats = kUzbekDishes.where((dish) => dish.region == 'Gerkules va suli');

  testWidgets('Oats with unknown water can be added; missing macros cannot', (
    tester,
  ) async {
    final dish = oats.firstWhere(
      (dish) => dish.nameEn.contains('cooked with milk'),
    );
    Future<void> showFood(FoodNutrition food) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FoodPortionSheet(
              key: ValueKey(food.missingNutrients.join(',')),
              food: food,
              title: dish.nameUz,
              subtitle: '',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    await showFood(dish.nutrition);
    expect(dish.nutrition.hasWaterData, isFalse);
    expect(dish.nutrition.hasMissingCoreNutrients, isFalse);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
    expect(find.textContaining('Asosiy oziq qiymatlari'), findsNothing);
    expect(find.textContaining('taxminiy'), findsNothing);
    await showFood(
      FoodNutrition.fromMap({
        ...dish.nutrition.toMap(),
        'missingNutrients': ['protein'],
      }),
    );
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    expect(find.textContaining('Asosiy oziq qiymatlari'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('oats are searchable by type and Latin or Cyrillic brand', () {
    expect(oats, hasLength(126));
    for (final query in [
      'gerkules',
      'suli',
      'овсянка',
      'oats',
      'Uvelka',
      'Увелка',
      'Yasno Solnyshko',
      'Ясно Солнышко',
      'Quaker',
      'Nordic',
      'Kolln',
      'steel cut',
      'sutda',
      'suvda',
    ]) {
      expect(searchUzbekFoods(query), isNotEmpty, reason: query);
    }
    final ids = kUzbekDishes.map((dish) => dish.nutrition.fdcId).toList();
    expect(ids.toSet().length, ids.length);
  });

  test('verified labels belong only to the exact dry product', () {
    final verified = oats
        .where(
          (dish) => dish.nutrition.dataSource == 'Ishlab chiqaruvchi yorlig‘i',
        )
        .toList();
    expect(verified, hasLength(2));
    final myllyn = verified.singleWhere(
      (dish) => dish.nameEn.contains('Myllyn'),
    );
    expect(myllyn.nutrition.calories, 350);
    expect(myllyn.nutrition.protein, 12);
    final kolln = verified.singleWhere(
      (dish) => dish.nameEn.contains('Delicate'),
    );
    expect(kolln.nutrition.calories, 361);
    expect(kolln.nutrition.fiber, 11);
    for (final dish in oats.where((dish) => !verified.contains(dish))) {
      expect(dish.nameUz, isNot(contains('taxminiy')));
    }
  });

  test('prepared portions use retained liquid and scale consistently', () {
    final water = oats
        .singleWhere(
          (dish) =>
              dish.nameEn.startsWith('Myllyn Paras 1928 thick') &&
              dish.nameEn.contains('cooked with water'),
        )
        .nutrition;
    final milk = oats
        .singleWhere(
          (dish) =>
              dish.nameEn.startsWith('Myllyn Paras 1928 thick') &&
              dish.nameEn.contains('cooked with milk'),
        )
        .nutrition;
    expect(water.calories, 87.5);
    expect(milk.calories, 126.5);
    expect(milk.fat, 3.375);
    expect(water.forGrams(200).calories, 175);
    expect(water.hasWaterData, isFalse);
    expect(water.missingNutrients, contains('water'));
  });
}
