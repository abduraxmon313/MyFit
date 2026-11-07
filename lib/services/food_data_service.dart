import 'dart:convert';

import 'package:http/http.dart' as http;

import '../data/uzbek_food_catalog.dart';
import '../models/food_nutrition.dart';
import 'food_query_translator.dart';
import 'fatsecret_service.dart';
import 'open_food_facts_service.dart';
import 'custom_food_store.dart';

class FoodDataService {
  FoodDataService({
    http.Client? client,
    FoodQueryTranslator? translator,
    FatSecretService? fatSecret,
    OpenFoodFactsService? openFoodFacts,
  }) : this._internal(
         client ?? http.Client(),
         translator,
         fatSecret,
         openFoodFacts,
       );

  FoodDataService._internal(
    this._client,
    FoodQueryTranslator? translator,
    FatSecretService? fatSecret,
    OpenFoodFactsService? openFoodFacts,
  ) : _translator = translator ?? FoodQueryTranslator(client: _client),
      _fatSecret = fatSecret ?? FatSecretService(),
      _openFoodFacts = openFoodFacts ?? OpenFoodFactsService(client: _client);

  /// USDA bepul kalit. DEMO_KEY limiti past — shaxsiy kalit tavsiya etiladi:
  /// https://fdc.nal.usda.gov/api-key-signup.html
  /// Ishga tushirish: flutter run --dart-define=USDA_API_KEY=YOUR_KEY
  static const _apiKey = String.fromEnvironment(
    'USDA_API_KEY',
    defaultValue: 'DEMO_KEY',
  );
  static const _host = 'api.nal.usda.gov';

  final http.Client _client;
  final FoodQueryTranslator _translator;
  final FatSecretService _fatSecret;
  final OpenFoodFactsService _openFoodFacts;
  final Map<String, List<FoodNutrition>> _cache = {};

  Future<FatSecretSearchPage> searchAdditionalPage(String query, {required String languageCode, int page = 1}) async {
    final translated = await _translator.translate(query.trim());
    return _fatSecret.searchPage(translated.english.trim().toLowerCase(), languageCode: languageCode, page: page);
  }

  Future<List<FoodNutrition>> search(
    String query, {
    String languageCode = 'uz',
  }) async {
    final trimmed = query.trim();
    if (trimmed.length < 2) return const [];

    final localFoods = [...searchUzbekFoods(trimmed, languageCode: languageCode)];
    try {
      final customFoods = await CustomFoodStore().load().timeout(const Duration(seconds: 1));
      localFoods.addAll(customFoods.where((food) => trimmed.toLowerCase().split(RegExp(r'\s+')).every(food.name.toLowerCase().contains)));
    } catch (_) {
      // A device-storage failure must not disable the public catalog.
    }

    final translated = await _translator.translate(trimmed);
    // USDA va zaxira bazalarga bir xil kanonik so‘rov yuboriladi:
    // foydalanuvchi katta, kichik yoki aralash harfda yozishi natijani
    // o‘zgartirmaydi.
    final englishQuery = translated.english.trim().toLowerCase();
    if (englishQuery.length < 2) return const [];

    // Bir tildagi ko‘rsatish nomi boshqa til keshiga aralashib ketmasin.
    final customIds = localFoods.where((food) => food.dataSource == 'User label').map((food) => food.fdcId).join(',');
    final cacheKey = '$languageCode:${trimmed.toLowerCase()}:$englishQuery:$customIds';
    final cached = _cache[cacheKey];
    if (cached != null) {
      return cached
          .map(
            (food) => FoodNutrition(
              fdcId: food.fdcId,
              basisUnit: food.basisUnit,
              servings: food.servings,
              name: food.name,
              calories: food.calories,
              protein: food.protein,
              fat: food.fat,
              carbohydrates: food.carbohydrates,
              water: food.water,
              fiber: food.fiber,
              localName: food.localName,
              hasWaterData: food.hasWaterData,
              productType: food.productType,
              ingredients: food.ingredients,
              sugars: food.sugars,
              saturatedFat: food.saturatedFat,
              monounsaturatedFat: food.monounsaturatedFat,
              polyunsaturatedFat: food.polyunsaturatedFat,
              knownNutrients: food.knownNutrients,
              dataSource: food.dataSource,
              missingNutrients: food.missingNutrients,
              salt: food.salt,
              sodiumMg: food.sodiumMg,
              potassiumMg: food.potassiumMg,
              ironMg: food.ironMg,
              calciumMg: food.calciumMg,
              cholesterolMg: food.cholesterolMg,
              labelDetails: food.labelDetails,
              phosphorusMg: food.phosphorusMg,
              magnesiumMg: food.magnesiumMg,
              vitaminEMg: food.vitaminEMg,
              zincMg: food.zincMg,
              vitaminDMcg: food.vitaminDMcg,
              vitaminK2Mcg: food.vitaminK2Mcg,
            ),
          )
          .toList();
    }

    List<FoodNutrition> results = await _fatSecret.search(
      englishQuery,
      languageCode: languageCode,
    );
    if (results.isNotEmpty && languageCode != 'en') {
      results = await Future.wait(
        results.map((food) async {
          final localized = await _translator.localizeEnglish(
            food.name,
            languageCode,
          );
          return FoodNutrition(
            fdcId: food.fdcId,
            basisUnit: food.basisUnit,
            servings: food.servings,
            name: food.name,
            calories: food.calories,
            protein: food.protein,
            fat: food.fat,
            carbohydrates: food.carbohydrates,
            water: food.water,
            fiber: food.fiber,
            localName: localized,
            hasWaterData: food.hasWaterData,
            productType: food.productType,
            ingredients: food.ingredients,
            sugars: food.sugars,
            saturatedFat: food.saturatedFat,
            monounsaturatedFat: food.monounsaturatedFat,
            polyunsaturatedFat: food.polyunsaturatedFat,
            knownNutrients: food.knownNutrients,
            dataSource: food.dataSource,
            missingNutrients: food.missingNutrients,
            salt: food.salt,
            sodiumMg: food.sodiumMg,
            potassiumMg: food.potassiumMg,
            ironMg: food.ironMg,
            calciumMg: food.calciumMg,
            cholesterolMg: food.cholesterolMg,
            labelDetails: food.labelDetails,
            phosphorusMg: food.phosphorusMg,
            magnesiumMg: food.magnesiumMg,
            vitaminEMg: food.vitaminEMg,
            zincMg: food.zincMg,
            vitaminDMcg: food.vitaminDMcg,
            vitaminK2Mcg: food.vitaminK2Mcg,
          );
        }),
      );
    }
    FoodDataException? usdaError;
    if (results.isEmpty) {
      try {
        // Brend nomi yozilgan bo‘lsa, aynan ishlab chiqaruvchi yorlig‘idagi
        // Branded yozuvini ustun qo‘yamiz. Oddiy mahsulotlarda laboratoriya
        // va survey bazalari aniqroq.
        results = await _searchUsda(
          englishQuery,
          preferAccurate: !_looksLikeBrandedProduct(englishQuery),
          brandedOnly: _looksLikeBrandedProduct(englishQuery),
        );
        if (englishQuery == 'cola') {
          final zeroVariants = await Future.wait(
            ['coca-cola zero sugar', 'pepsi zero sugar'].map((variant) async {
              try {
                return await _searchUsda(
                  variant,
                  preferAccurate: false,
                  brandedOnly: true,
                );
              } on FoodDataException {
                return const <FoodNutrition>[];
              }
            }),
          );
          final seenIds = <int>{};
          results = [
            ...results,
            ...zeroVariants.expand((foods) => foods.take(5)),
          ].where((food) => seenIds.add(food.fdcId)).toList(growable: false);
        }
        if (results.isEmpty) {
          results = await _searchUsda(englishQuery, preferAccurate: false);
        }

        // O‘zbekcha tarjima yomon chiqqan bo‘lsa, originalni ham sinaymiz.
        if (results.isEmpty &&
            translated.english.toLowerCase() != trimmed.toLowerCase()) {
          results = await _searchUsda(trimmed, preferAccurate: true);
        }
      } on FoodDataException catch (error) {
        usdaError = error;
        results = const [];
      }
    }

    // USDA topmasa yoki vaqtincha ishlamasa, packaged mahsulotlar uchun
    // kalitsiz Open Food Facts bazasidan foydalanamiz.
    if (results.isEmpty) {
      results = await _openFoodFacts.search(
        englishQuery,
        languageCode: languageCode,
      );
      if (results.isEmpty &&
          englishQuery.toLowerCase() != trimmed.toLowerCase()) {
        results = await _openFoodFacts.search(
          trimmed,
          languageCode: languageCode,
        );
      }
    }
    if (results.isEmpty && usdaError != null && localFoods.isEmpty) {
      throw usdaError;
    }

    final withLocal = results
        .map(
          (food) => FoodNutrition(
            fdcId: food.fdcId,
            basisUnit: food.basisUnit,
            servings: food.servings,
            name: food.name,
            calories: food.calories,
            protein: food.protein,
            fat: food.fat,
            carbohydrates: food.carbohydrates,
            water: food.water,
            fiber: food.fiber,
            localName: food.localName ?? translated.localLabel,
            hasWaterData: food.hasWaterData,
            productType: food.productType,
            ingredients: food.ingredients,
            sugars: food.sugars,
            saturatedFat: food.saturatedFat,
            monounsaturatedFat: food.monounsaturatedFat,
            polyunsaturatedFat: food.polyunsaturatedFat,
            knownNutrients: food.knownNutrients,
            dataSource: food.dataSource,
            missingNutrients: food.missingNutrients,
            salt: food.salt,
            sodiumMg: food.sodiumMg,
            potassiumMg: food.potassiumMg,
            ironMg: food.ironMg,
            calciumMg: food.calciumMg,
            cholesterolMg: food.cholesterolMg,
            labelDetails: food.labelDetails,
            phosphorusMg: food.phosphorusMg,
            magnesiumMg: food.magnesiumMg,
            vitaminEMg: food.vitaminEMg,
            zincMg: food.zincMg,
            vitaminDMcg: food.vitaminDMcg,
            vitaminK2Mcg: food.vitaminK2Mcg,
          ),
        )
        .toList();

    final seen = <String>{};
    final combined = <FoodNutrition>[...localFoods, ...withLocal]
        .where((food) {
          final key = '${food.name}|${food.localName ?? ''}'.toLowerCase();
          return seen.add(key);
        })
        .toList(growable: false);

    if (combined.isNotEmpty) {
      _cache[cacheKey] = combined;
    }
    return combined;
  }

  Future<List<FoodNutrition>> _searchUsda(
    String query, {
    required bool preferAccurate,
    bool brandedOnly = false,
  }) async {
    final dataType = brandedOnly
        ? 'Branded'
        : preferAccurate
        ? 'Foundation,SR Legacy,Survey (FNDDS)'
        : 'Foundation,SR Legacy,Survey (FNDDS),Branded';

    final uri = Uri.https(_host, '/fdc/v1/foods/search', {
      'api_key': _apiKey,
      'query': query,
      'pageSize': brandedOnly ? '50' : '25',
      'dataType': dataType,
    });

    late final http.Response response;
    try {
      response = await _client.get(uri).timeout(const Duration(seconds: 12));
    } catch (_) {
      throw const FoodDataException(
        'Internetga ulanishda xatolik. Qayta urinib ko‘ring.',
      );
    }

    if (response.statusCode == 429) {
      throw const FoodDataException(
        'USDA API limiti tugadi. Biroz kuting yoki shaxsiy API kalit ulang '
        '(fdc.nal.usda.gov).',
      );
    }
    if (response.statusCode == 403) {
      throw const FoodDataException(
        'API kaliti noto‘g‘ri. USDA kalitini tekshiring.',
      );
    }
    if (response.statusCode != 200) {
      throw FoodDataException(
        'Server xatosi (${response.statusCode}). Keyinroq urinib ko‘ring.',
      );
    }

    try {
      final body = jsonDecode(response.body);
      if (body is! Map<String, dynamic> || body['foods'] is! List) {
        throw const FormatException('Invalid USDA foods response');
      }
      return (body['foods'] as List)
          .whereType<Map<String, dynamic>>()
          .where(
            (item) =>
                item['foodNutrients'] is List &&
                (item['foodNutrients'] as List).isNotEmpty,
          )
          .map(_parseFood)
          .toList();
    } on FormatException {
      throw const FoodDataException('USDA returned invalid nutrition data.');
    } on TypeError {
      throw const FoodDataException('USDA returned invalid nutrition data.');
    }
  }

  bool _looksLikeBrandedProduct(String query) {
    const brands = [
      'coca-cola',
      'coca cola',
      'coke',
      'pepsi',
      'fanta',
      'sprite',
      'mirinda',
      '7up',
      'mountain dew',
      'dr pepper',
      'schweppes',
      'red bull',
      'monster',
      'adrenaline rush',
      'gatorade',
      'powerade',
    ];
    return query == 'cola' ||
        brands.any(query.contains) ||
        (query.contains('cola') &&
            (query.contains('zero') || query.contains('diet')));
  }

  FoodNutrition _parseFood(Map<String, dynamic> json) {
    final nutrients = (json['foodNutrients'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();
    // Prefer food-specific Atwater energy, then reported kcal, general kcal,
    // and only then kJ. API array order must not change the chosen value.
    int energyRank(Map<String, dynamic> item) => switch (item['nutrientId']) {
      2048 => 0,
      1008 => 1,
      2047 => 2,
      1062 => 3,
      _ => 4,
    };
    nutrients.sort((a, b) => energyRank(a).compareTo(energyRank(b)));

    double nutrient({
      required Set<int> ids,
      required List<String> names,
      bool energy = false,
      double fallback = 0,
      String expectedUnit = 'G',
    }) {
      for (final raw in nutrients) {
        final item = raw;
        final id = (item['nutrientId'] as num?)?.toInt();
        final number = item['nutrientNumber']?.toString();
        final name = (item['nutrientName'] as String? ?? '').toLowerCase();
        final unit = (item['unitName'] as String? ?? '').trim().toUpperCase();

        final idMatch = id != null && ids.contains(id);
        final nameMatch = names.any((candidate) => name == candidate);
        final numberMatch =
            energy && (number == '208' || number == '957' || number == '958');

        // A known nutrient ID is more precise than a partial name match.
        if (id != null && !idMatch && !numberMatch) continue;
        if (!idMatch && !nameMatch && !numberMatch) continue;

        var value =
            (item['value'] as num?)?.toDouble() ??
            (item['amount'] as num?)?.toDouble();
        if (value == null || !value.isFinite || value < 0) continue;

        if (energy &&
            (unit == 'KJ' ||
                unit == 'KJOULES' ||
                (unit.isEmpty && id == 1062))) {
          value = value / 4.184;
        } else if (energy && unit.isNotEmpty && unit != 'KCAL') {
          continue;
        } else if (!energy && unit.isNotEmpty && unit != expectedUnit) {
          const gramsPerUnit = {
            'G': 1.0,
            'MG': 0.001,
            'UG': 0.000001,
            'MCG': 0.000001,
          };
          final from = gramsPerUnit[unit];
          final to = gramsPerUnit[expectedUnit];
          if (from == null || to == null) continue;
          value = value * from / to;
        }
        return value;
      }
      return fallback;
    }

    final detailSpecs = <String, (int, String, String)>{
      'sugars': (2000, 'sugars, total including nlea', 'G'),
      'saturatedFat': (1258, 'fatty acids, total saturated', 'G'),
      'monounsaturatedFat': (1292, 'fatty acids, total monounsaturated', 'G'),
      'polyunsaturatedFat': (1293, 'fatty acids, total polyunsaturated', 'G'),
      'sodiumMg': (1093, 'sodium, na', 'MG'),
      'cholesterolMg': (1253, 'cholesterol', 'MG'),
      'potassiumMg': (1092, 'potassium, k', 'MG'),
      'fiber': (1079, 'fiber, total dietary', 'G'),
    };
    final details = <String, double>{};
    for (final entry in detailSpecs.entries) {
      final spec = entry.value;
      final value = nutrient(
        ids: {spec.$1, if (entry.key == 'sugars') 1063},
        names: [spec.$2, if (entry.key == 'sugars') 'sugars, total'],
        expectedUnit: spec.$3,
        fallback: double.nan,
      );
      if (value.isFinite) details[entry.key] = value;
    }

    final description = json['description'] as String? ?? 'Noma’lum ovqat';
    final core = <String, double>{
      'calories': nutrient(
        ids: {1008, 1062, 2047, 2048},
        names: ['energy', 'calories'],
        energy: true,
        fallback: double.nan,
      ),
      'protein': nutrient(
        ids: {1003},
        names: ['protein'],
        fallback: double.nan,
      ),
      'fat': nutrient(
        ids: {1004},
        names: ['total lipid (fat)', 'fat'],
        fallback: double.nan,
      ),
      'carbohydrates': nutrient(
        ids: {1005},
        names: ['carbohydrate, by difference', 'carbohydrate'],
        fallback: double.nan,
      ),
    };
    final brandName = (json['brandName'] as String?)?.trim() ?? '';
    final brandOwner = (json['brandOwner'] as String?)?.trim() ?? '';
    final brand = brandName.isNotEmpty ? brandName : brandOwner;
    final fullName =
        brand.isNotEmpty &&
            !description.toLowerCase().contains(brand.toLowerCase())
        ? '$description — $brand'
        : description;

    return FoodNutrition(
      fdcId: (json['fdcId'] as num?)?.toInt() ?? 0,
      name: fullName,
      dataSource: 'USDA FoodData Central',
      missingNutrients: core.entries
          .where((entry) => !entry.value.isFinite)
          .map((entry) => entry.key)
          .toSet(),
      sugars: details['sugars'] ?? 0,
      saturatedFat: details['saturatedFat'] ?? 0,
      monounsaturatedFat: details['monounsaturatedFat'],
      polyunsaturatedFat: details['polyunsaturatedFat'],
      sodiumMg: details['sodiumMg'] ?? 0,
      cholesterolMg: details['cholesterolMg'] ?? 0,
      potassiumMg: details['potassiumMg'] ?? 0,
      knownNutrients: details.keys.toSet(),
      calories: core['calories']!.isFinite ? core['calories']! : 0,
      protein: core['protein']!.isFinite ? core['protein']! : 0,
      fat: core['fat']!.isFinite ? core['fat']! : 0,
      carbohydrates: core['carbohydrates']!.isFinite
          ? core['carbohydrates']!
          : 0,
      water: nutrient(ids: {1051}, names: ['water']),
      hasWaterData: nutrients.whereType<Map<String, dynamic>>().any(
        (item) =>
            item['nutrientId'] == 1051 ||
            (item['nutrientName'] as String? ?? '').toLowerCase() == 'water',
      ),
      fiber: nutrient(
        ids: {1079},
        names: ['fiber, total dietary', 'dietary fiber', 'fiber'],
      ),
    );
  }
}

class FoodDataException implements Exception {
  const FoodDataException(this.message);
  final String message;

  @override
  String toString() => message;
}
