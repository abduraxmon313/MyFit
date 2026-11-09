import '../models/food_nutrition.dart';

/// Source tag for dishes the user assembled from ingredients.
const kUserRecipeSource = 'User recipe';

/// Sum of the ingredient portions (each already scaled to its own grams).
class RecipeTotals {
  const RecipeTotals({
    required this.grams,
    required this.calories,
    required this.protein,
    required this.fat,
    required this.carbohydrates,
    required this.fiber,
    required this.sugars,
    required this.saturatedFat,
    required this.sodiumMg,
    required this.salt,
  });

  factory RecipeTotals.of(Iterable<FoodNutrition> ingredients) {
    double sum(double Function(FoodNutrition food) value) =>
        ingredients.fold(0, (total, food) => total + value(food));
    return RecipeTotals(
      grams: sum((f) => f.grams),
      calories: sum((f) => f.calories),
      protein: sum((f) => f.protein),
      fat: sum((f) => f.fat),
      carbohydrates: sum((f) => f.carbohydrates),
      fiber: sum((f) => f.fiber),
      sugars: sum((f) => f.sugars),
      saturatedFat: sum((f) => f.saturatedFat),
      sodiumMg: sum((f) => f.sodiumMg),
      salt: sum((f) => f.salt),
    );
  }

  final double grams;
  final double calories;
  final double protein;
  final double fat;
  final double carbohydrates;
  final double fiber;
  final double sugars;
  final double saturatedFat;
  final double sodiumMg;
  final double salt;
}

/// Builds a per-100 g food from ingredient portions.
///
/// [cookedWeight] is the weight of the finished dish. It defaults to the sum
/// of the ingredients; a smaller value (water boiled off) concentrates the
/// nutrients, a larger value dilutes them.
FoodNutrition buildRecipe({
  required String name,
  required List<FoodNutrition> ingredients,
  double? cookedWeight,
  String languageCode = 'uz',
  int? id,
}) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) throw ArgumentError.value(name, 'name');
  if (ingredients.isEmpty) throw ArgumentError('No ingredients');
  final totals = RecipeTotals.of(ingredients);
  final weight = cookedWeight ?? totals.grams;
  if (!weight.isFinite || weight <= 0) {
    throw ArgumentError.value(cookedWeight, 'cookedWeight');
  }
  final factor = 100 / weight;
  String grams(double value) =>
      value == value.roundToDouble() ? value.round().toString() : '$value';
  final list = ingredients
      .map((f) => '${f.displayNameFor(languageCode)} — ${grams(f.grams)} g')
      .join('; ');
  return FoodNutrition(
    fdcId: id ?? -DateTime.now().microsecondsSinceEpoch,
    name: trimmed,
    localName: trimmed,
    calories: totals.calories * factor,
    protein: totals.protein * factor,
    fat: totals.fat * factor,
    carbohydrates: totals.carbohydrates * factor,
    fiber: totals.fiber * factor,
    sugars: totals.sugars * factor,
    saturatedFat: totals.saturatedFat * factor,
    sodiumMg: totals.sodiumMg * factor,
    salt: totals.salt * factor,
    water: 0,
    hasWaterData: false,
    dataSource: kUserRecipeSource,
    productType: 'RECIPE',
    ingredients: list,
    knownNutrients: const {'calories', 'protein', 'fat', 'carbohydrates'},
    servings: [FoodServing(description: '1 ta tayyor ovqat', amount: weight)],
    labelDetails:
        'Tayyor vazn ${grams(weight)} g, masalliqlar jami '
        '${grams(totals.grams)} g. Qiymatlar 100 g tayyor ovqat uchun.',
  );
}
