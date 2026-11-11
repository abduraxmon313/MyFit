import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/food_nutrition.dart';
import 'calorie_api_service.dart';
import 'fatsecret_service.dart';

/// Open Food Facts packaged-food database fallback.
///
/// Read requests do not require an API key. Results are community-provided, so
/// this service only returns products that contain usable macro information.
class OpenFoodFactsService {
  OpenFoodFactsService({
    http.Client? client,
    FatSecretService? fatSecret,
    this.calorieApi,
  }) : _client = client ?? http.Client(),
       _fatSecret = fatSecret ?? FatSecretService();

  final FatSecretService _fatSecret;

  /// Tried first for barcodes when set (Calorie API via the Worker).
  final CalorieApiService? calorieApi;

  static const _host = 'world.openfoodfacts.org';
  static const _userAgent =
      'MyFit/1.0 (Flutter nutrition app; read-only Open Food Facts client)';

  final http.Client _client;
  final Map<String, List<FoodNutrition>> _cache = {};

  Future<FoodNutrition?> findByBarcode(
    String barcode, {
    String languageCode = 'uz',
  }) async {
    final calorie = await calorieApi?.findByBarcode(barcode);
    if (calorie != null && !calorie.hasMissingCoreNutrients) return calorie;
    final primary =
        await _findOpenFoodFactsBarcode(barcode, languageCode: languageCode) ??
        calorie;
    if (primary != null && !primary.hasMissingCoreNutrients) return primary;
    final secondary = await _fatSecret.findByBarcode(barcode);
    if (secondary != null && !secondary.hasMissingCoreNutrients) {
      return secondary;
    }
    return primary ?? secondary;
  }

  Future<FoodNutrition?> _findOpenFoodFactsBarcode(
    String barcode, {
    String languageCode = 'uz',
  }) async {
    final cleaned = barcode.replaceAll(RegExp(r'\D'), '');
    if (cleaned.length < 8 || cleaned.length > 14) return null;

    final uri = Uri.https(_host, '/api/v2/product/$cleaned.json', {
      'fields':
          'code,product_name,product_name_uz,product_name_ru,product_name_en,'
          'brands,nutriments,'
          'nutrition_data_per',
    });
    try {
      final response = await _client
          .get(uri, headers: const {'User-Agent': _userAgent})
          .timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) return null;
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic> || decoded['status'] != 1) {
        return null;
      }
      final product = decoded['product'];
      if (product is! Map<String, dynamic>) return null;
      return _parseProduct(product, languageCode: languageCode);
    } catch (_) {
      return null;
    }
  }

  Future<List<FoodNutrition>> search(
    String query, {
    String languageCode = 'uz',
  }) async {
    final trimmed = query.trim();
    if (trimmed.length < 2) return const [];

    final cacheKey = '$languageCode:${trimmed.toLowerCase()}';
    final cached = _cache[cacheKey];
    if (cached != null) return List.unmodifiable(cached);

    final uri = Uri.https(_host, '/cgi/search.pl', {
      'action': 'process',
      'search_terms': trimmed,
      'search_simple': '1',
      'json': '1',
      'page_size': '20',
      'fields':
          'code,product_name,product_name_uz,product_name_ru,product_name_en,'
          'brands,nutriments,'
          'nutrition_data_per',
    });

    try {
      final response = await _client
          .get(uri, headers: const {'User-Agent': _userAgent})
          .timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) return const [];

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return const [];
      final products = decoded['products'];
      if (products is! List) return const [];

      final results = products
          .whereType<Map<String, dynamic>>()
          .map((product) => _parseProduct(product, languageCode: languageCode))
          .whereType<FoodNutrition>()
          .toList(growable: false);
      if (results.isNotEmpty) _cache[cacheKey] = results;
      return results;
    } catch (_) {
      // Open Food Facts is a fallback. Its outage must not break USDA results.
      return const [];
    }
  }

  FoodNutrition? _parseProduct(
    Map<String, dynamic> product, {
    required String languageCode,
  }) {
    final nutriments = product['nutriments'];
    if (nutriments is! Map<String, dynamic>) return null;

    double? measured(String key) {
      final raw = nutriments[key];
      final parsed = raw is num
          ? raw.toDouble()
          : double.tryParse(raw?.toString() ?? '');
      return parsed != null && parsed.isFinite && parsed >= 0 ? parsed : null;
    }

    double value(String key) => measured(key) ?? 0;

    var calories = value('energy-kcal_100g');
    if (measured('energy-kcal_100g') == null) {
      final kilojoules = value('energy-kj_100g');
      if (kilojoules > 0) calories = kilojoules / 4.184;
    }

    final protein = value('proteins_100g');
    final fat = value('fat_100g');
    final carbohydrates = value('carbohydrates_100g');
    final water = value('water_100g');
    final fiber = value('fiber_100g');
    final hasNutrition =
        [
          'energy-kcal_100g',
          'energy-kj_100g',
          'proteins_100g',
          'fat_100g',
          'carbohydrates_100g',
          'water_100g',
        ].any((key) {
          final raw = nutriments[key];
          final parsed = raw is num
              ? raw.toDouble()
              : double.tryParse(raw?.toString() ?? '');
          return parsed != null && parsed.isFinite && parsed >= 0;
        });
    if (!hasNutrition) return null;

    String localizedName(String code) =>
        (product['product_name_$code'] as String?)?.trim() ?? '';
    final preferredName = localizedName(languageCode);
    final primaryName = preferredName.isNotEmpty
        ? preferredName
        : ((product['product_name'] as String?)?.trim().isNotEmpty ?? false)
        ? (product['product_name'] as String).trim()
        : localizedName('en');
    final brands = (product['brands'] as String?)?.trim() ?? '';
    final name = [
      primaryName,
      if (brands.isNotEmpty && !primaryName.contains(brands)) brands,
    ].where((part) => part.isNotEmpty).join(' — ');
    if (name.isEmpty) return null;

    final barcode = product['code']?.toString() ?? '';
    // OFF per-100g mineral values are in grams; the model stores milligrams.
    const detailKeys = {
      'sugars': 'sugars',
      'saturatedFat': 'saturated-fat',
      'monounsaturatedFat': 'monounsaturated-fat',
      'polyunsaturatedFat': 'polyunsaturated-fat',
      'sodiumMg': 'sodium',
      'cholesterolMg': 'cholesterol',
      'potassiumMg': 'potassium',
      'calciumMg': 'calcium',
      'ironMg': 'iron',
      'phosphorusMg': 'phosphorus',
      'magnesiumMg': 'magnesium',
      'zincMg': 'zinc',
      'vitaminEMg': 'vitamin-e',
      'vitaminDMcg': 'vitamin-d',
      'salt': 'salt',
      'fiber': 'fiber',
    };
    final details = <String, double>{};
    for (final entry in detailKeys.entries) {
      final key = '${entry.value}_100g';
      final raw = nutriments[key];
      final parsed = raw is num
          ? raw.toDouble()
          : double.tryParse(raw?.toString() ?? '');
      if (parsed != null && parsed.isFinite && parsed >= 0) {
        details[entry.key] =
            parsed *
            (entry.key.endsWith('Mcg')
                ? 1000000
                : entry.key.endsWith('Mg')
                ? 1000
                : 1);
      }
    }
    return FoodNutrition(
      fdcId: int.tryParse(barcode) ?? barcode.hashCode,
      name: name,
      basisUnit: product['nutrition_data_per'] == '100ml' ? 'ml' : 'g',
      dataSource: 'Open Food Facts',
      missingNutrients: {
        if (measured('energy-kcal_100g') == null &&
            measured('energy-kj_100g') == null)
          'calories',
        if (measured('proteins_100g') == null) 'protein',
        if (measured('fat_100g') == null) 'fat',
        if (measured('carbohydrates_100g') == null) 'carbohydrates',
      },
      sugars: details['sugars'] ?? 0,
      saturatedFat: details['saturatedFat'] ?? 0,
      monounsaturatedFat: details['monounsaturatedFat'],
      polyunsaturatedFat: details['polyunsaturatedFat'],
      sodiumMg: details['sodiumMg'] ?? 0,
      cholesterolMg: details['cholesterolMg'] ?? 0,
      potassiumMg: details['potassiumMg'] ?? 0,
      calciumMg: details['calciumMg'] ?? 0,
      ironMg: details['ironMg'] ?? 0,
      phosphorusMg: details['phosphorusMg'] ?? 0,
      magnesiumMg: details['magnesiumMg'] ?? 0,
      zincMg: details['zincMg'] ?? 0,
      vitaminEMg: details['vitaminEMg'] ?? 0,
      vitaminDMcg: details['vitaminDMcg'] ?? 0,
      salt: details['salt'] ?? 0,
      knownNutrients: details.keys.toSet(),
      calories: calories,
      protein: protein,
      fat: fat,
      carbohydrates: carbohydrates,
      water: water,
      fiber: fiber,
      hasWaterData: measured('water_100g') != null,
    );
  }
}
