import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:myfit/config/app_config.dart';
import 'package:myfit/models/food_nutrition.dart';
import 'package:myfit/services/calorie_api_service.dart';
import 'package:myfit/services/food_data_service.dart';
import 'package:myfit/services/food_vision_service.dart';
import 'package:myfit/services/open_food_facts_service.dart';

const cola = {
  'id': 'upc-5449000000996',
  'name': 'Coca-Cola',
  'brand': 'Coca-Cola',
  'barcode': '5449000000996',
  'basisUnit': 'ml',
  'per100': {
    'calories': 42,
    'protein': 0,
    'carbohydrates': 10.6,
    'fat': 0,
    'fiber': null,
    'sugars': 10.6,
    'saturatedFat': null,
    'salt': 0,
    'sodiumMg': 10,
  },
  'serving': {'label': '1 can (330 ml)', 'amount': 330, 'unit': 'ml'},
  'ingredients': 'Water, sugar',
  'source': 'Calorie API',
};

const egg = {
  'id': '8153861',
  'name': 'Egg',
  'brand': null,
  'barcode': null,
  'basisUnit': 'g',
  'per100': {'calories': 120, 'protein': 12, 'carbohydrates': 0, 'fat': 8},
  'serving': {'label': '1 Small Egg', 'amount': 48, 'unit': 'g'},
};

CalorieApiService service(
  Future<http.Response> Function(http.Request) handler, {
  String? token = 'tok',
}) => CalorieApiService(
  client: MockClient(handler),
  idToken: ({bool forceRefresh = false}) async => token,
);

class _NoSearch extends FoodDataService {
  int calls = 0;
  @override
  Future<List<FoodNutrition>> search(
    String query, {
    String languageCode = 'uz',
  }) async {
    calls++;
    return const [];
  }
}

void main() {
  test(
    'barcode goes to the Worker with the ID token, not the API key',
    () async {
      late http.Request seen;
      final food = await service((request) async {
        seen = request;
        return http.Response(jsonEncode({'food': cola}), 200);
      }).findByBarcode('5449 0000 00996');
      expect(seen.url.toString(), '$kVideoApiBaseUrl/food/barcode');
      expect(seen.headers['Authorization'], 'Bearer tok');
      expect(jsonDecode(seen.body), {'barcode': '5449000000996'});
      expect(food!.name, 'Coca-Cola');
      expect(food.calories, 42);
      expect(food.carbohydrates, 10.6);
      expect(food.basisUnit, 'ml');
      expect(food.servings.single.amount, 330);
      expect(food.dataSource, kCalorieApiSource);
      expect(food.hasMissingCoreNutrients, isFalse);
      expect(food.missingNutrients, isEmpty);
      expect(food.knownNutrients, isNot(contains('fiber')));
      expect(food.fdcId, 5449000000996);
    },
  );

  test('search parses foods for photo labels', () async {
    final foods = await service(
      (_) async => http.Response(
        jsonEncode({
          'foods': [egg],
        }),
        200,
      ),
    ).search('egg');
    expect(foods.single.name, 'Egg');
    expect(foods.single.protein, 12);
    expect(foods.single.servings.single.description, '1 Small Egg');
  });

  test('failures return null/empty so fallbacks keep working', () async {
    for (final status in [401, 429, 502, 503]) {
      final api = service((_) async => http.Response('{}', status));
      expect(await api.findByBarcode('5449000000996'), isNull);
      expect(await api.search('egg'), isEmpty);
    }
    expect(
      await service(
        (_) async => throw http.ClientException('offline'),
      ).findByBarcode('5449000000996'),
      isNull,
    );
    var calls = 0;
    final signedOut = service((_) async {
      calls++;
      return http.Response('{}', 200);
    }, token: null);
    expect(await signedOut.findByBarcode('5449000000996'), isNull);
    expect(await signedOut.findByBarcode('12'), isNull);
    expect(calls, 0);
  });

  test('barcode chain uses Calorie API first', () async {
    var offCalls = 0;
    final off = OpenFoodFactsService(
      client: MockClient((_) async {
        offCalls++;
        return http.Response('{}', 404);
      }),
      calorieApi: service(
        (_) async => http.Response(jsonEncode({'food': cola}), 200),
      ),
    );
    final food = await off.findByBarcode('5449000000996');
    expect(food!.dataSource, kCalorieApiSource);
    expect(offCalls, 0);
  });

  test('photo labels use Calorie API before the existing search', () async {
    final fallback = _NoSearch();
    final vision = FoodVisionService(
      foodDataService: fallback,
      calorieApi: service(
        (_) async => http.Response(
          jsonEncode({
            'foods': [egg],
          }),
          200,
        ),
      ),
    );
    final food = await vision.lookupLabel('egg cooked');
    expect(food!.name, 'Egg');
    expect(fallback.calls, 0);

    final empty = FoodVisionService(
      foodDataService: fallback,
      calorieApi: service((_) async => http.Response('{"foods":[]}', 200)),
    );
    expect(await empty.lookupLabel('pizza'), isNull);
    expect(fallback.calls, 1);
  });
}
