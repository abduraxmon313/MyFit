import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/food_nutrition.dart';

const kCalorieApiSource = 'Calorie API';

typedef CalorieIdToken = Future<String?> Function({bool forceRefresh});

Future<String?> _firebaseIdToken({bool forceRefresh = false}) async {
  if (Firebase.apps.isEmpty) return null;
  return FirebaseAuth.instance.currentUser?.getIdToken(forceRefresh);
}

/// Calorie API (calorieapi.com) through the MyFit Worker (`/food/*`).
///
/// The API key stays on the Worker. Every method returns `null` / empty on
/// any failure, so callers keep their existing fallbacks (Open Food Facts,
/// FatSecret, USDA) working.
class CalorieApiService {
  CalorieApiService({this.client, String? apiBase, CalorieIdToken? idToken})
    : apiBase = apiBase ?? kVideoApiBaseUrl,
      idToken = idToken ?? _firebaseIdToken;

  final http.Client? client;
  final String apiBase;
  final CalorieIdToken idToken;

  /// Product for an EAN/UPC [barcode], or `null` when unknown/unavailable.
  Future<FoodNutrition?> findByBarcode(String barcode) async {
    final digits = barcode.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 8 || digits.length > 14) return null;
    final json = await _post('/food/barcode', {'barcode': digits});
    final food = json?['food'];
    return food is Map ? parseFood(Map<String, dynamic>.from(food)) : null;
  }

  /// Foods matching [query] (e.g. a photo label like "apple").
  Future<List<FoodNutrition>> search(String query, {int limit = 5}) async {
    final trimmed = query.trim();
    if (trimmed.length < 2) return const [];
    final json = await _post('/food/search', {
      'query': trimmed,
      'limit': limit,
    });
    final foods = json?['foods'];
    if (foods is! List) return const [];
    return [
      for (final raw in foods)
        if (raw is Map) ?parseFood(Map<String, dynamic>.from(raw)),
    ];
  }

  Future<Map<String, dynamic>?> _post(String path, Object body) async {
    final base = apiBase.trim().replaceAll(RegExp(r'/+$'), '');
    if (!base.startsWith('https://')) return null;
    final httpClient = client ?? http.Client();
    try {
      for (var attempt = 0; attempt < 2; attempt++) {
        final String? token;
        try {
          token = await idToken(forceRefresh: attempt > 0);
        } catch (_) {
          return null;
        }
        if (token == null || token.isEmpty) return null;
        final response = await httpClient
            .post(
              Uri.parse('$base$path'),
              headers: {
                'Authorization': 'Bearer $token',
                'Content-Type': 'application/json',
              },
              body: jsonEncode(body),
            )
            .timeout(const Duration(seconds: 15));
        if (response.statusCode == 200) {
          final decoded = jsonDecode(utf8.decode(response.bodyBytes));
          return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
        }
        if (response.statusCode != 401) return null;
      }
      return null;
    } catch (_) {
      return null;
    } finally {
      if (client == null) httpClient.close();
    }
  }

  /// Worker JSON (per 100 g/ml) -> [FoodNutrition].
  static FoodNutrition? parseFood(Map<String, dynamic> json) {
    final name = (json['name'] as String?)?.trim() ?? '';
    if (name.isEmpty) return null;
    final per100 = json['per100'] is Map
        ? Map<String, dynamic>.from(json['per100'] as Map)
        : const <String, dynamic>{};
    double? value(String key) {
      final raw = per100[key];
      return raw is num && raw.isFinite && raw >= 0 ? raw.toDouble() : null;
    }

    const core = ['calories', 'protein', 'fat', 'carbohydrates'];
    final missing = {
      for (final key in core)
        if (value(key) == null) key,
    };
    if (missing.length == core.length) return null;
    const extra = ['fiber', 'sugars', 'saturatedFat', 'salt', 'sodiumMg'];
    final basisUnit = json['basisUnit'] == 'ml' ? 'ml' : 'g';
    final brand = (json['brand'] as String?)?.trim() ?? '';
    final serving = json['serving'] is Map
        ? Map<String, dynamic>.from(json['serving'] as Map)
        : null;
    final servingAmount = serving?['amount'];
    final barcode = (json['barcode'] as String?) ?? '';
    final id = '${json['id'] ?? ''}';
    return FoodNutrition(
      fdcId: int.tryParse(barcode) ?? int.tryParse(id) ?? id.hashCode,
      name:
          brand.isNotEmpty && !name.toLowerCase().contains(brand.toLowerCase())
          ? '$name — $brand'
          : name,
      calories: value('calories') ?? 0,
      protein: value('protein') ?? 0,
      fat: value('fat') ?? 0,
      carbohydrates: value('carbohydrates') ?? 0,
      water: 0,
      hasWaterData: false,
      fiber: value('fiber') ?? 0,
      sugars: value('sugars') ?? 0,
      saturatedFat: value('saturatedFat') ?? 0,
      salt: value('salt') ?? 0,
      sodiumMg: value('sodiumMg') ?? 0,
      basisUnit: basisUnit,
      servings: [
        if (serving != null &&
            servingAmount is num &&
            servingAmount > 0 &&
            serving['unit'] == basisUnit)
          FoodServing(
            id: 'calorieapi',
            description: '${serving['label'] ?? '$servingAmount $basisUnit'}',
            amount: servingAmount.toDouble(),
            unit: basisUnit,
          ),
      ],
      ingredients: (json['ingredients'] as String?)?.trim(),
      dataSource: kCalorieApiSource,
      missingNutrients: missing,
      knownNutrients: {
        for (final key in [...core, ...extra])
          if (value(key) != null) key,
      },
    );
  }
}
