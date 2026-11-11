import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:myfit/models/food_nutrition.dart';
import 'package:myfit/widgets/food_thumbnail.dart';

FoodNutrition food(String name, {String? local}) => FoodNutrition(
  fdcId: 1,
  name: name,
  localName: local,
  calories: 10,
  protein: 1,
  fat: 1,
  carbohydrates: 1,
  water: 0,
);

void main() {
  test('each food gets its own picture, not a neighbour category', () {
    final cases = {
      'Tomatoes, red, ripe, raw': '🍅',
      'Pomidor': '🍅',
      'Carrots, raw': '🥕',
      'Sabzi': '🥕',
      'Rice, white, long-grain, raw': '🍚',
      'Guruch (oq)': '🍚',
      'Apples, raw, with skin': '🍎',
      'Potatoes, boiled': '🥔',
      'Kartoshka': '🥔',
      'Onions, raw': '🧅',
      'Cucumber, with peel, raw': '🥒',
      'Bananas, raw': '🍌',
      'Chicken breast, cooked': '🍗',
      'Mol go‘shti': '🥩',
      'Egg, whole, raw': '🥚',
      'Eggplant, raw': '🍆',
      'Salmon, Atlantic, raw': '🐟',
      'Milk, nonfat': '🥛',
      'Tandir non': '🍞',
      'Pomidor sharbati': '🧃',
      'Coca-Cola': '🥤',
      'Plov (osh)': '🍛',
      'Manti': '🥟',
      'Tuxum barak': '🥟',
      'Oats, rolled': '🥣',
      'Ёнғоқ walnut': '🌰',
      'Strawberries, raw': '🍓',
      'Помидоры свежие': '🍅',
    };
    for (final entry in cases.entries) {
      expect(foodEmoji(food(entry.key)), entry.value, reason: entry.key);
    }
  });

  test('the local name wins and unknown foods fall back to the icon', () {
    expect(foodEmoji(food('Solanum lycopersicum', local: 'Pomidor')), '🍅');
    expect(foodEmoji(food('Mystery protein bar 3000')), isNull);
    expect(
      foodEmoji(food('Molasses')),
      isNull,
      reason: '"mol" is a whole word only',
    );
  });

  test('category icons no longer turn raw rice or raw meat into fruit', () {
    expect(foodCategoryIcon(food('Rice, white, raw')), LucideIcons.wheat);
    expect(foodCategoryIcon(food('Guruch, xom')), LucideIcons.wheat);
    expect(foodCategoryIcon(food('Tomatoes, raw')), LucideIcons.carrot);
    expect(foodCategoryIcon(food('Apples, raw')), LucideIcons.apple);
    expect(foodCategoryIcon(food('Something, raw')), LucideIcons.utensils);
    expect(foodCategoryIcon(food('Goat cheese')), LucideIcons.milk);
  });

  testWidgets('thumbnail shows the emoji, or the icon when unknown', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Row(
          children: [
            FoodThumbnail.forFood(food('Pomidor')),
            FoodThumbnail.forFood(food('Unknown thing')),
          ],
        ),
      ),
    );
    expect(find.text('🍅'), findsOneWidget);
    expect(find.byKey(const Key('food-emoji')), findsOneWidget);
    expect(find.byIcon(LucideIcons.utensils), findsOneWidget);
  });
}
