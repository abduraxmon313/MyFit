import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/food_nutrition.dart';

/// Manufacturer-label entries, stored on this device. No guessed brand values.
class CustomFoodStore {
  static const _key = 'myfit.customFoods.v1';
  static Future<void> _writes = Future<void>.value();

  Future<List<FoodNutrition>> load() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_key);
    if (raw == null) return const [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) throw const FormatException('Invalid saved foods');
    return decoded.whereType<Map>().map((item) => FoodNutrition.fromMap(Map<String, dynamic>.from(item))).toList(growable: false);
  }

  Future<void> save(FoodNutrition food) {
    final operation = _writes.catchError((Object _) {}).then((_) async {
      final foods = await load();
      final preferences = await SharedPreferences.getInstance();
      final updated = [food, ...foods.where((item) => item.fdcId != food.fdcId)];
      if (!await preferences.setString(_key, jsonEncode(updated.map((item) => item.toMap()).toList()))) {
        throw StateError('Could not save food');
      }
    });
    _writes = operation;
    return operation;
  }
}
