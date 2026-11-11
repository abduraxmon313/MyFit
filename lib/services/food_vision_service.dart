import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';

import '../models/food_nutrition.dart';
import 'calorie_api_service.dart';
import 'food_data_service.dart';

class FoodVisionService {
  FoodVisionService({FoodDataService? foodDataService, this.calorieApi})
    : _foodDataService = foodDataService ?? FoodDataService();

  final FoodDataService _foodDataService;

  /// Tried first for each photo label when set (Calorie API via the Worker).
  final CalorieApiService? calorieApi;

  /// First usable food for a photo label: Calorie API, then the app's
  /// existing search (local catalog, FatSecret, USDA, Open Food Facts).
  Future<FoodNutrition?> lookupLabel(String query) async {
    final calorie = await calorieApi?.search(query, limit: 3) ?? const [];
    for (final food in calorie) {
      if (!food.hasMissingCoreNutrients) return food;
    }
    final foods = await _foodDataService.search(query);
    return foods.isNotEmpty ? foods.first : null;
  }

  static const _genericLabels = {
    'food',
    'dish',
    'cuisine',
    'recipe',
    'ingredient',
    'meal',
    'tableware',
    'plate',
    'serveware',
    'comfort food',
    'fast food',
    'produce',
    'natural foods',
  };

  static const _queryOverrides = {
    'baked goods': 'bread baked',
    'bread': 'bread',
    'bun': 'bread roll',
    'pastry': 'pastry',
    'dessert': 'dessert',
    'cake': 'cake',
    'cookie': 'cookie',
    'fruit': 'fresh fruit',
    'vegetable': 'fresh vegetable',
    'meat': 'meat cooked',
    'chicken': 'chicken cooked',
    'beef': 'beef cooked',
    'rice': 'rice cooked',
    'noodle': 'noodles cooked',
    'soup': 'soup',
    'salad': 'salad',
    'sandwich': 'sandwich',
    'pizza': 'pizza',
    'hamburger': 'hamburger',
    'fried food': 'fried food',
    'seafood': 'seafood cooked',
    'fish': 'fish cooked',
    'egg': 'egg cooked',
    'cheese': 'cheese',
  };

  Future<FoodNutrition> analyzeFile(String imagePath) async {
    final labeler = ImageLabeler(
      options: ImageLabelerOptions(confidenceThreshold: 0.45),
    );
    try {
      final labels = await labeler.processImage(
        InputImage.fromFilePath(imagePath),
      );
      if (labels.isEmpty) {
        throw const FoodVisionException(
          'Rasmda ovqat aniqlanmadi. Taomni yaqinroq va yorug‘ joyda oling.',
        );
      }

      final useful = labels.where((label) {
        final text = label.label.trim().toLowerCase();
        return text.isNotEmpty && !_genericLabels.contains(text);
      }).toList()..sort((a, b) => b.confidence.compareTo(a.confidence));

      if (useful.isEmpty) {
        throw const FoodVisionException(
          'Ovqat turi aniq topilmadi. Boshqa burchakdan qayta suratga oling.',
        );
      }

      FoodNutrition? bestFood;
      ImageLabel? matchedLabel;
      for (final label in useful.take(5)) {
        final raw = label.label.trim();
        final query = _queryOverrides[raw.toLowerCase()] ?? raw;
        final food = await lookupLabel(query);
        if (food != null) {
          bestFood = food;
          matchedLabel = label;
          break;
        }
      }

      if (bestFood == null || matchedLabel == null) {
        throw const FoodVisionException(
          'Taom ko‘rindi, ammo unga mos oziq qiymati topilmadi.',
        );
      }

      return FoodNutrition.fromMap({
        ...bestFood.toMap(),
        'localName': matchedLabel.label,
        'confidence': matchedLabel.confidence.clamp(0, 1),
      });
    } finally {
      await labeler.close();
    }
  }
}

class FoodVisionException implements Exception {
  const FoodVisionException(this.message);
  final String message;

  @override
  String toString() => message;
}
