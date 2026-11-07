import 'package:flutter_test/flutter_test.dart';
import 'package:myfit/data/uzbek_food_catalog.dart';
import 'package:myfit/models/food_nutrition.dart';

void main() {
  final oils = kUzbekDishes
      .where((dish) => dish.nutrition.productType == 'OLIVE OIL')
      .toList();

  test('all 20 oils are searchable in Uzbek, Russian and English', () {
    expect(oils, hasLength(20));
    for (final query in ['zaytun', 'olivka yogi', 'olive oil', 'оливковое']) {
      expect(
        searchUzbekFoods(query).map((f) => f.fdcId),
        containsAll(oils.map((d) => d.nutrition.fdcId)),
      );
    }
    for (final dish in oils) {
      expect(
        searchUzbekFoods(dish.nutrition.name).map((f) => f.fdcId),
        contains(dish.nutrition.fdcId),
      );
      expect(dish.nutrition.labelDetails, contains('taxminiy'));
      expect(dish.nutrition.labelDetails, contains('https://fdc.nal.usda.gov'));
    }
    final ids = kUzbekDishes.map((d) => d.nutrition.fdcId).toList();
    expect(ids.toSet(), hasLength(ids.length));
  });

  test(
    'light oil keeps full fat; portions and saved metadata remain correct',
    () {
      final light = oils.singleWhere(
        (d) => d.nutrition.name == 'Light Olive Oil',
      );
      expect(light.nutrition.fat, 100);
      final portion = light.nutrition.forGrams(13.5);
      expect(portion.calories, closeTo(119.34, .00001));
      expect(portion.fat, 13.5);
      expect(portion.protein, 0);
      expect(portion.monounsaturatedFat, closeTo(72.961 * .135, .00001));
      final restored = FoodNutrition.fromMap(portion.toMap());
      expect(restored.labelDetails, portion.labelDetails);
      expect(restored.knownNutrients, contains('cholesterolMg'));
      expect(restored.knownNutrients, isNot(contains('vitaminK2Mcg')));
      expect(
        oils.last.nutrition.labelDetails,
        contains('qo‘shimchalar hisoblanmagan'),
      );
    },
  );
}
