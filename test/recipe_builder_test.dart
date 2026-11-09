import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myfit/l10n/app_localizations.dart';
import 'package:myfit/models/food_nutrition.dart';
import 'package:myfit/screens/recipe_builder_page.dart';
import 'package:myfit/services/custom_food_store.dart';
import 'package:myfit/services/food_data_service.dart';
import 'package:myfit/services/recipe_builder.dart';
import 'package:myfit/widgets/food_thumbnail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Offline extends FoodDataService {
  @override
  Future<List<FoodNutrition>> search(
    String query, {
    String languageCode = 'uz',
  }) async => [];
}

FoodNutrition _per100(String name, double kcal, double p, double c, double f) =>
    FoodNutrition(
      fdcId: name.hashCode,
      name: name,
      calories: kcal,
      protein: p,
      carbohydrates: c,
      fat: f,
      water: 0,
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('recipe totals and per-100 g values follow ingredient grams', () {
    final beef = _per100('Beef', 250, 26, 0, 15).forGrams(300);
    final potato = _per100('Potato', 77, 2, 17, .1).forGrams(400);
    final water = _per100('Water', 0, 0, 0, 0).forGrams(1300);

    final soup = buildRecipe(
      name: ' Sho‘rva ',
      ingredients: [beef, potato, water],
    );
    expect(soup.name, 'Sho‘rva');
    expect(soup.dataSource, kUserRecipeSource);
    // 750 + 308 kcal in 2000 g → 52.9 kcal / 100 g.
    expect(soup.calories, closeTo((750 + 308) / 20, 1e-9));
    expect(soup.protein, closeTo((78 + 8) / 20, 1e-9));
    expect(soup.servings.single.amount, 2000);
    expect(soup.ingredients, contains('Beef — 300 g'));

    // Water boiled off: same nutrients, less weight → more concentrated.
    final reduced = buildRecipe(
      name: 'Sho‘rva',
      ingredients: [beef, potato, water],
      cookedWeight: 1600,
    );
    expect(reduced.calories, closeTo(1058 / 16, 1e-9));
    expect(reduced.forGrams(1600).calories, closeTo(1058, 1e-6));
    expect(
      () => buildRecipe(name: '', ingredients: [beef]),
      throwsArgumentError,
    );
    expect(
      () => buildRecipe(name: 'x', ingredients: const []),
      throwsArgumentError,
    );
  });

  test('common vegetables get the vegetable icon, not the fruit icon', () {
    for (final name in ['Potato, raw', 'Onions, raw', 'Carrots, raw']) {
      expect(foodCategoryIcon(_per100(name, 40, 1, 9, 0)), LucideIcons.carrot);
    }
    expect(
      foodCategoryIcon(_per100('Apples, raw', 52, 0, 14, 0)),
      LucideIcons.apple,
    );
  });

  testWidgets('builder adds ingredients from search and saves the dish', (
    tester,
  ) async {
    final store = CustomFoodStore();
    FoodNutrition? created;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('uz'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              child: const Text('Open'),
              onPressed: () async {
                created = await Navigator.push<FoodNutrition>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RecipeBuilderPage(
                      foodDataService: _Offline(),
                      store: store,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    // Validation: name and at least one ingredient are required.
    await tester.tap(find.byKey(const Key('recipe-create')));
    await tester.pumpAndSettle();
    expect(find.text('Majburiy maydon'), findsOneWidget);
    expect(find.text('Kamida bitta masalliq qo‘shing.'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('recipe-name')), 'Sho‘rva');
    await tester.tap(find.byKey(const Key('recipe-add-ingredient')));
    await tester.pumpAndSettle();
    expect(find.text('Masalliq qo‘shish'), findsOneWidget); // picker title
    await tester.enterText(find.byType(TextField), 'Sut 3,25%');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sut 3,25%').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('portion-amount')), '200');
    await tester.tap(find.text('Saqlash'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('basket-add')));
    await tester.pumpAndSettle();

    // Milk 3.25 %: 61 kcal / 100 g → 122 kcal for 200 g.
    // "3,25%" must not be misread as "25% yog‘li".
    expect(find.text('Sut 3,25% — to‘liq yog‘li'), findsOneWidget);
    expect(find.textContaining('25% yog‘li'), findsNothing);
    expect(find.text('Majburiy maydon'), findsNothing);
    expect(
      tester.widget<Text>(find.byKey(const Key('recipe-total-kcal'))).data,
      '122',
    );
    await tester.tap(find.byKey(const Key('recipe-create')));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(created, isNotNull);
    expect(created!.name, 'Sho‘rva');
    expect(created!.calories, closeTo(61, .01));
    final saved = await store.load();
    expect(saved.map((f) => f.name), contains('Sho‘rva'));
  });
}
