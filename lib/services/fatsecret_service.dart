import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';

import '../models/food_nutrition.dart';

class FatSecretSearchPage {
  const FatSecretSearchPage(this.foods, this.nextPage);
  final List<FoodNutrition> foods;
  final int? nextPage;
}

class FatSecretService {
  FatSecretService([this._functions]);

  final FirebaseFunctions? _functions;

  /// Shared by search and barcode so missing values and units have one meaning.
  static FoodNutrition parseFood(Map<String, dynamic> item) {
    final values = <String, dynamic>{...item, 'fdcId': item['id'], 'dataSource': 'FatSecret', 'hasWaterData': item['hasWaterData'] == true};
    final missing = <String>{
      ...((item['missingNutrients'] as List?)?.whereType<String>() ?? const <String>[]),
    };
    for (final key in ['calories', 'protein', 'fat', 'carbohydrates', 'water', 'fiber', 'sugars', 'saturatedFat', 'monounsaturatedFat', 'polyunsaturatedFat', 'salt', 'sodiumMg', 'potassiumMg', 'ironMg', 'calciumMg', 'cholesterolMg', 'phosphorusMg', 'magnesiumMg', 'vitaminEMg', 'zincMg', 'vitaminDMcg', 'vitaminK2Mcg']) {
      final value = item[key];
      if (value is! num || !value.isFinite || value < 0) {
        values[key] = key == 'monounsaturatedFat' || key == 'polyunsaturatedFat' ? null : 0;
        missing.add(key);
      }
    }
    values['missingNutrients'] = missing.toList();
    values['knownNutrients'] = ((item['knownNutrients'] as List?)?.whereType<String>() ?? const <String>[]).where((key) => !missing.contains(key)).toList();
    return FoodNutrition.fromMap(values);
  }

  Future<FoodNutrition?> findByBarcode(String barcode) async {
    if (Firebase.apps.isEmpty) return null;
    try {
      final response = await (_functions ?? FirebaseFunctions.instanceFor(region: 'europe-west1'))
          .httpsCallable('fatSecretBarcode', options: HttpsCallableOptions(timeout: const Duration(seconds: 25)))
          .call<Map<String, dynamic>>({'barcode': barcode});
      final raw = response.data['food'];
      return raw is Map ? parseFood(Map<String, dynamic>.from(raw)) : null;
    } catch (_) {
      return null;
    }
  }

  Future<List<FoodNutrition>> search(
    String query, {
    required String languageCode,
  }) async {
    return (await searchPage(query, languageCode: languageCode)).foods;
  }

  Future<FatSecretSearchPage> searchPage(String query, {required String languageCode, int page = 0}) async {
    if (query.trim().length < 2 || Firebase.apps.isEmpty) return const FatSecretSearchPage([], null);
    try {
      final callable =
          (_functions ?? FirebaseFunctions.instanceFor(region: 'europe-west1'))
              .httpsCallable(
                'fatSecretSearch',
                options: HttpsCallableOptions(
                  timeout: const Duration(seconds: 35),
                ),
              );
      final response = await callable.call<Map<String, dynamic>>({
        'query': query.trim(),
        'languageCode': languageCode,
        'page': page,
      });
      final rawFoods = response.data['foods'] as List<dynamic>? ?? const [];
      final foods = rawFoods
          .map((raw) {
            final item = Map<String, dynamic>.from(raw as Map);
            return parseFood(item);
          })
          .toList(growable: false);
      return FatSecretSearchPage(foods, (response.data['nextPage'] as num?)?.toInt());
    } on FirebaseFunctionsException {
      return const FatSecretSearchPage([], null);
    } catch (_) {
      return const FatSecretSearchPage([], null);
    }
  }
}
