import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myfit/data/uzbek_food_catalog.dart';
import 'package:myfit/models/food_nutrition.dart';
import 'package:myfit/l10n/app_localizations.dart';
import 'package:myfit/screens/meals_page.dart';
import 'package:myfit/screens/national_food_picker_page.dart';
import 'package:myfit/services/food_data_service.dart';
import 'package:myfit/widgets/food_portion_sheet.dart';

FoodNutrition food(int id) =>
    kUzbekDishes.singleWhere((dish) => dish.nutrition.fdcId == id).nutrition;

class OfflineFoods extends FoodDataService {
  @override
  Future<List<FoodNutrition>> search(
    String query, {
    String languageCode = 'uz',
  }) async => [];
}

void main() {
  test('Whole foods and individual dishes have size options', () {
    expect(foodPieceSizes(food(-2001)), [106, 138, 212]);
    expect(foodPieceSizes(food(-1007)), [40, 60, 80]);
    expect(foodPieceSizes(food(-1030)), [70, 120, 170]);
    expect(foodPieceSizes(food(-1204)), isNull);
    expect(foodPieceSizes(food(-1001)), isNull);
    final juice = FoodNutrition.fromMap({
      ...food(-2001).toMap(),
      'name': 'Apple juice',
    });
    expect(foodPieceSizes(juice), isNull);
  });

  testWidgets('Piece size changes preserve count and update nutrition', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FoodPortionSheet(
            food: food(-2001),
            title: 'Apple',
            subtitle: '',
          ),
        ),
      ),
    );
    final field = find.byKey(const Key('portion-amount'));
    await tester.enterText(field, '2');
    for (final selection in {
      'Katta dona (≈ 212 g)': '424 g · 220.5 kcal',
      'Kichik dona (≈ 106 g)': '212 g · 110.2 kcal',
    }.entries) {
      await tester.tap(find.byKey(const Key('portion-unit')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(selection.key).last);
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(field).controller!.text, '2');
      expect(find.text(selection.value), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });

  test('Only plain egg foods have piece portions', () {
    expect(eggPieceGrams(food(-1200)), 50);
    expect(eggPieceGrams(food(-1201)), 50);
    expect(eggPieceGrams(food(-1203)), 46);
    expect(eggPieceGrams(food(-1206)), 33);
    expect(eggPieceGrams(food(-1204)), isNull); // Omelet.
    expect(eggPieceGrams(food(-2001)), isNull); // Apple.
  });

  test('Common whole-egg and egg-white aliases keep piece portions', () {
    const base = FoodNutrition(
      fdcId: -9999,
      name: 'egg whole hard boiled',
      calories: 143,
      protein: 12.6,
      fat: 9.5,
      carbohydrates: 0.7,
      water: 76.2,
    );
    const white = FoodNutrition(
      fdcId: -9998,
      name: 'egg white raw fresh',
      calories: 52,
      protein: 10.9,
      fat: 0.2,
      carbohydrates: 0.7,
      water: 87.6,
    );
    const omelet = FoodNutrition(
      fdcId: -9997,
      name: 'omelet with milk',
      calories: 154,
      protein: 10.6,
      fat: 11.2,
      carbohydrates: 2.6,
      water: 74.4,
    );

    expect(eggPieceGrams(base), 50);
    expect(eggPieceGrams(white), 33);
    expect(eggPieceGrams(omelet), isNull);
  });

  testWidgets('Egg picker adds three eggs with scaled nutrients', (
    tester,
  ) async {
    List<FoodNutrition>? selected;
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
                selected = await Navigator.push<List<FoodNutrition>>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => NationalFoodPickerPage(
                      meal: MealType.breakfast,
                      foodDataService: OfflineFoods(),
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
    await tester.enterText(find.byType(TextField), 'Oddiy tuxum');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Oddiy tuxum').last);
    await tester.pumpAndSettle();
    final field = find.byKey(const Key('portion-amount'));
    expect(tester.widget<TextField>(field).controller!.text, '1');
    await tester.enterText(field, '3');
    await tester.pump();
    expect(find.text('132 g · 194.0 kcal'), findsOneWidget);
    await tester.tap(find.text('Saqlash'));
    await tester.pumpAndSettle();
    expect(selected, isNull, reason: 'Saqlash faqat savatga qo‘shadi');
    await tester.tap(find.byKey(const Key('basket-add')));
    await tester.pumpAndSettle();
    expect(selected, hasLength(1));
    expect(selected!.single.grams, 132);
    expect(selected!.single.calories, closeTo(194.04, .001));
    expect(selected!.single.protein, closeTo(16.6056, .001));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Switching units preserves egg quantity', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FoodPortionSheet(food: food(-1200), title: 'Egg', subtitle: ''),
        ),
      ),
    );
    final field = find.byKey(const Key('portion-amount'));
    await tester.enterText(field, '3');
    await tester.tap(find.byKey(const Key('portion-unit')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gramm'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(field).controller!.text, '132');
    await tester.tap(find.byKey(const Key('portion-unit')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dona (≈ 44 g)').last);
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(field).controller!.text, '3');
    await tester.enterText(field, '0,5');
    await tester.pump();
    expect(find.text('22 g · 32.3 kcal'), findsOneWidget);
  });

  testWidgets('Other foods keep the default 100 gram input', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FoodPortionSheet(
            food: food(-1204),
            title: 'Omelet',
            subtitle: '',
          ),
        ),
      ),
    );
    expect(find.text('Dona'), findsNothing);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('portion-amount')))
          .controller!
          .text,
      '100',
    );
  });

  testWidgets('Zero and excessive egg quantities show validation errors', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FoodPortionSheet(food: food(-1200), title: 'Egg', subtitle: ''),
        ),
      ),
    );
    final field = find.byKey(const Key('portion-amount'));
    for (final value in ['0', '114']) {
      await tester.enterText(field, value);
      await tester.tap(find.byType(FilledButton));
      await tester.pump();
      expect(tester.widget<TextField>(field).decoration!.errorText, isNotNull);
      expect(tester.takeException(), isNull);
    }
  });
}
