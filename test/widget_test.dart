import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:myfit/data/uzbek_food_catalog.dart';
import 'package:myfit/l10n/app_localizations.dart';
import 'package:myfit/models/food_nutrition.dart';
import 'package:myfit/models/user_profile.dart';
import 'package:myfit/screens/calculator_page.dart';
import 'package:myfit/screens/calorie_calculator_page.dart';
import 'package:myfit/screens/body_fat_calculator_page.dart';
import 'package:myfit/screens/meals_page.dart';
import 'package:myfit/screens/national_food_picker_page.dart';
import 'package:myfit/screens/profile_page.dart';
import 'package:myfit/screens/water_calculator_page.dart';
import 'package:myfit/services/calorie_needs_calculator.dart';
import 'package:myfit/services/body_fat_calculator.dart';
import 'package:myfit/services/food_data_service.dart';
import 'package:myfit/services/food_query_translator.dart';
import 'package:myfit/services/open_food_facts_service.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

void main() {
  test('58 ta mol qismi katalogga to‘liq va takrorsiz qo‘shilgan', () {
    final beefParts = kUzbekDishes
        .where((dish) => dish.region == 'Mol qismlari')
        .toList(growable: false);
    expect(beefParts, hasLength(58));
    expect(
      beefParts.map((dish) => dish.nutrition.fdcId).toSet(),
      hasLength(58),
    );
    FoodNutrition part(String name) =>
        beefParts.singleWhere((dish) => dish.nameUz == 'Mol — $name').nutrition;
    expect(part('Jigar').protein, closeTo(20.36, .01));
    expect(part('Buyrak').water, closeTo(79.46, .01));
    expect(part('Ilikli suyak (faqat iligi)').fat, closeTo(84, .01));
    expect(part('Suyak').calories, 0);
    expect(part('Suyak').productType, contains('NON-EDIBLE'));
  });

  test(
    'batafsil tarkib faqat vitamin va mineral qo‘shimchalarda ko‘rinadi',
    () {
      final apple = searchUzbekFoods(
        'Olma',
      ).singleWhere((food) => food.fdcId == -2001);
      final protein = searchUzbekFoods('ISO-100').single;
      final vitamin = searchUzbekFoods('sports research d3 k2').single;
      final mineral = searchUzbekFoods('now magnesium').single;
      final omega = searchUzbekFoods('now omega 3').single;

      expect(showsDetailedCompositionInPicker(apple), isFalse);
      expect(showsDetailedCompositionInPicker(protein), isFalse);
      expect(showsDetailedCompositionInPicker(vitamin), isTrue);
      expect(showsDetailedCompositionInPicker(mineral), isTrue);
      expect(showsDetailedCompositionInPicker(omega), isTrue);
    },
  );

  test('74 ta sabzavot katalogga to‘liq va takrorsiz qo‘shilgan', () {
    final vegetables = kUzbekDishes
        .where((dish) => dish.region == 'Sabzavotlar')
        .toList(growable: false);
    expect(vegetables, hasLength(74));
    expect(
      vegetables.map((dish) => dish.nutrition.fdcId).toSet(),
      hasLength(74),
    );
    FoodNutrition vegetable(String name) =>
        vegetables.singleWhere((dish) => dish.nameUz == name).nutrition;
    expect(vegetable('Kartoshka').calories, 77);
    expect(vegetable('Bodring').water, closeTo(95.23, .01));
    expect(vegetable('Soya (quruq)').protein, closeTo(36.49, .01));
    expect(vegetable('Nohat (quruq)').fiber, closeTo(17.4, .01));
    expect(vegetable('Ukrop').calories, vegetable('Shivit').calories);
  });

  test('68 ta meva katalogga to‘liq va takrorsiz qo‘shilgan', () {
    final fruits = kUzbekDishes
        .where((dish) => dish.region == 'Mevalar')
        .toList(growable: false);
    expect(fruits, hasLength(68));
    expect(fruits.map((dish) => dish.nutrition.fdcId).toSet(), hasLength(68));
    FoodNutrition fruit(String name) =>
        fruits.singleWhere((dish) => dish.nameUz == name).nutrition;
    expect(fruit('Banan').calories, 89);
    expect(fruit('Tarvuz').water, closeTo(91.45, .01));
    expect(fruit('Kokos').fat, closeTo(33.49, .01));
  });

  test('27 ta quruq meva USDA qiymatlari bilan takrorsiz qo‘shilgan', () {
    final dried = kUzbekDishes
        .where((dish) => dish.region == 'Quruq mevalar')
        .toList(growable: false);
    expect(dried, hasLength(27));
    expect(dried.map((dish) => dish.nutrition.fdcId).toSet(), hasLength(27));
    FoodNutrition item(String name) =>
        dried.singleWhere((dish) => dish.nameUz == name).nutrition;
    expect(item('Kuraga (o‘rik qoqi)').calories, 241);
    expect(item('Oltin mayiz (sabza)').carbohydrates, closeTo(79.5, .6));
    expect(item('Finik (Medjool)').protein, closeTo(1.81, .01));
    expect(
      dried.every((dish) => dish.nutrition.dataSource!.startsWith('USDA')),
      isTrue,
    );
  });

  test('Sports Research D3 K2 bir softgel qiymatlari aynan mos', () {
    final food = searchUzbekFoods('sports research d3 k2').single;
    expect(food.productType, 'VITAMIN D3 + K2 SUPPLEMENT');
    final serving = food.forGrams(1);
    expect(serving.vitaminDMcg, closeTo(125, .01));
    expect(serving.vitaminK2Mcg, closeTo(100, .01));
    expect(serving.calories, 0);
    expect(food.labelDetails, contains('5000 IU'));
    expect(food.labelDetails, contains('625 foizi'));
    expect(food.labelDetails, contains('MK-7'));
  });

  test('NOW Zinc Picolinate bir kapsula qiymati aynan mos', () {
    final food = searchUzbekFoods('now zinc').single;
    expect(food.productType, 'ZINC MINERAL SUPPLEMENT');
    final serving = food.forGrams(1);
    expect(serving.zincMg, closeTo(50, .01));
    expect(serving.calories, 0);
    expect(food.labelDetails, contains('455 foizi'));
    expect(food.labelDetails, contains('271 mg zinc picolinate'));
  });

  test('NOW Foods E-400 bir softgel qiymati aynan mos', () {
    final food = searchUzbekFoods('now e-400').single;
    expect(food.productType, 'VITAMIN E ANTIOXIDANT SUPPLEMENT');
    final serving = food.forGrams(1);
    expect(serving.vitaminEMg, closeTo(268, .01));
    expect(serving.calories, 0);
    expect(food.labelDetails, contains('400 IU'));
    expect(food.labelDetails, contains('1787 foizi'));
    expect(food.ingredients, contains('d-alfa tokoferol'));
  });

  test('NOW Magnesium Glycinate ikki kapsula qiymati aynan mos', () {
    final food = searchUzbekFoods('now magnesium').single;
    expect(food.productType, 'MAGNESIUM MINERAL SUPPLEMENT');
    final serving = food.forGrams(2);
    expect(serving.magnesiumMg, closeTo(200, .01));
    expect(serving.calories, 0);
    expect(food.labelDetails, contains('BioPerine'));
    expect(food.labelDetails, contains('2,5 mg'));
  });

  test('NOW Foods Omega-3 ikki softgel qiymatlari aynan mos', () {
    final food = searchUzbekFoods('now omega 3').single;
    expect(food.productType, 'OMEGA-3 / FISH OIL SUPPLEMENT');
    final serving = food.forGrams(2);
    expect(serving.calories, closeTo(20, .01));
    expect(serving.fat, closeTo(2, .01));
    expect(serving.protein, 0);
    expect(serving.carbohydrates, 0);
    expect(food.labelDetails, contains('EPA'));
    expect(food.labelDetails, contains('360 mg'));
    expect(food.labelDetails, contains('DHA'));
    expect(food.labelDetails, contains('240 mg'));
  });

  test('Kevin Levrone Anabolic Mass 120 g porsiyasi aynan mos', () {
    final food = searchUzbekFoods('anabolic mass').single;
    expect(food.productType, 'ANABOLIC LEAN MASS GAINER');
    final serving = food.forGrams(120);
    expect(serving.calories, closeTo(414, .01));
    expect(serving.protein, closeTo(42, .01));
    expect(serving.fat, closeTo(3.12, .01));
    expect(serving.saturatedFat, closeTo(1.92, .01));
    expect(serving.carbohydrates, closeTo(54, .01));
    expect(serving.sugars, closeTo(12, .01));
    expect(serving.fiber, closeTo(1.2, .01));
    expect(serving.salt, closeTo(.12, .001));
    expect(food.labelDetails, contains('taurin 3600 mg'));
    expect(food.labelDetails, contains('kreatin monogidrat 1800 mg'));
  });

  test('MASS-TECH Extreme 2000 suvli 569 g porsiyasi aynan mos', () {
    final food = searchUzbekFoods('mass tech extreme 2000').single;
    expect(food.productType, 'HIGH-PROTEIN MASS GAINER');
    final serving = food.forGrams(569);
    expect(serving.calories, closeTo(2130, .01));
    expect(serving.protein, closeTo(60, .01));
    expect(serving.fat, closeTo(6, .01));
    expect(serving.saturatedFat, closeTo(3.5, .01));
    expect(serving.carbohydrates, closeTo(460, .01));
    expect(serving.sugars, closeTo(21, .01));
    expect(serving.fiber, closeTo(2, .01));
    expect(serving.cholesterolMg, closeTo(170, .01));
    expect(serving.sodiumMg, closeTo(730, .01));
    expect(serving.potassiumMg, closeTo(560, .01));
    expect(food.labelDetails, contains('2350 kcal va 80 g oqsil'));
    expect(food.labelDetails, contains('kreatin monogidrat 5 g'));
  });

  test('Critical Mass Professional 150 g porsiya qiymatlari aynan mos', () {
    final food = searchUzbekFoods('Critical Mass Professional').single;
    expect(food.productType, 'LEAN MASS GAINER');
    expect(food.calories, 377);
    expect(food.protein, 28);
    expect(food.fat, 6.7);
    expect(food.saturatedFat, 1.4);
    expect(food.carbohydrates, 49.8);
    expect(food.sugars, 1.9);
    expect(food.fiber, 3.1);
    expect(food.salt, .18);
    expect(food.labelDetails, contains('566 kcal'));
    expect(food.labelDetails, contains('kreatin monogidrat 3 g'));
  });

  test('Muscle Rulz GAIN RULZ 334 g porsiya qiymatlari aynan mos', () {
    final food = searchUzbekFoods('GAIN RULZ').single;
    expect(food.productType, 'MASS GAINER');
    final serving = food.forGrams(334);
    expect(serving.calories, closeTo(1250, .01));
    expect(serving.protein, closeTo(50, .01));
    expect(serving.fat, closeTo(8, .01));
    expect(serving.saturatedFat, closeTo(7, .01));
    expect(serving.carbohydrates, closeTo(244, .01));
    expect(serving.sugars, closeTo(20, .01));
    expect(serving.cholesterolMg, closeTo(125, .01));
    expect(serving.sodiumMg, closeTo(280, .01));
    expect(serving.calciumMg, closeTo(335, .01));
    expect(serving.ironMg, closeTo(1, .01));
    expect(serving.potassiumMg, closeTo(607, .01));
  });

  test('RED REX Beef Mass Plus 341 g porsiya qiymatlari aynan mos', () {
    final food = searchUzbekFoods('RED REX').single;
    expect(food.productType, 'BEEF PROTEIN MASS GAINER');
    final serving = food.forGrams(341);
    expect(serving.calories, closeTo(1350, .01));
    expect(serving.protein, closeTo(50, .01));
    expect(serving.fat, closeTo(1, .01));
    expect(serving.carbohydrates, closeTo(285, .01));
    expect(serving.sugars, closeTo(11, .01));
    expect(serving.sodiumMg, closeTo(490, .01));
    expect(food.labelDetails, contains('750 mg kreatin HCL'));
    expect(food.labelDetails, contains('1340 kcal'));
  });

  test('MUTANT MASS 100 g va porsiya qiymatlari aynan mos', () {
    final food = searchUzbekFoods('MUTANT MASS').single;
    expect(food.productType, 'MASS GAINER');
    expect(food.calories, 392);
    expect(food.protein, 20);
    expect(food.fat, 4.3);
    expect(food.saturatedFat, 2.1);
    expect(food.carbohydrates, 68.6);
    expect(food.sugars, 6.4);
    expect(food.fiber, 2.1);
    expect(food.salt, .34);
    expect(food.labelDetails, contains('550 kcal'));
    expect(food.labelDetails, contains('1100 kcal'));
  });

  test('Applied Nutrition Critical Mass 240 g qiymatlari aynan mos', () {
    final food = searchUzbekFoods(
      'Critical Mass',
    ).singleWhere((item) => item.productType == 'HIGH CALORIE MASS GAINER');
    expect(food.productType, 'HIGH CALORIE MASS GAINER');
    expect(food.calories, 376);
    expect(food.protein, 24.5);
    expect(food.fat, 4.5);
    expect(food.saturatedFat, 3.4);
    expect(food.carbohydrates, 57.4);
    expect(food.sugars, 33.2);
    expect(food.fiber, 3.71);
    expect(food.salt, .26);
    expect(food.labelDetails, contains('902 kcal'));
    expect(food.labelDetails, contains('58,8 g'));
    expect(food.ingredients, contains('L-glutamin'));
  });

  test('SERIOUS MASS 340 g porsiya muhim qiymatlari aynan mos', () {
    final food = searchUzbekFoods('SERIOUS MASS').single;
    expect(food.productType, 'MASS GAINER');
    final serving = food.forGrams(340);
    expect(serving.calories, closeTo(1250, .01));
    expect(serving.protein, closeTo(50, .01));
    expect(serving.fat, closeTo(5, .01));
    expect(serving.saturatedFat, closeTo(3, .01));
    expect(serving.carbohydrates, closeTo(252, .01));
    expect(serving.sugars, closeTo(31, .01));
    expect(serving.cholesterolMg, closeTo(200, .01));
    expect(serving.sodiumMg, closeTo(670, .01));
    expect(serving.calciumMg, closeTo(700, .01));
    expect(serving.ironMg, closeTo(5.8, .01));
    expect(serving.potassiumMg, closeTo(930, .01));
    expect(food.labelDetails, contains('kreatin monogidrat 3 g'));
  });

  test('Rule 1 R1 Clean Gainer 149 g porsiya qiymatlari aynan mos', () {
    final food = searchUzbekFoods('R1 Clean Gainer').single;
    expect(food.productType, 'CLEAN MASS GAINER');
    final serving = food.forGrams(149);
    expect(serving.calories, closeTo(560, .01));
    expect(serving.protein, closeTo(30, .01));
    expect(serving.fat, closeTo(5, .01));
    expect(serving.saturatedFat, closeTo(3.5, .01));
    expect(serving.carbohydrates, closeTo(99, .01));
    expect(serving.fiber, closeTo(4, .01));
    expect(serving.sugars, closeTo(9, .01));
    expect(serving.cholesterolMg, closeTo(80, .01));
    expect(serving.sodiumMg, closeTo(310, .01));
    expect(serving.calciumMg, closeTo(280, .01));
    expect(serving.ironMg, closeTo(4.8, .01));
    expect(serving.potassiumMg, closeTo(570, .01));
  });

  test('ISOPURE Zero Carb 31 g scoop muhim qiymatlari aynan mos', () {
    final food = searchUzbekFoods('ISOPURE').single;
    expect(food.productType, 'WHEY PROTEIN ISOLATE — ZERO CARB');
    final scoop = food.forGrams(31);
    expect(scoop.calories, closeTo(110, .01));
    expect(scoop.protein, closeTo(25, .01));
    expect(scoop.fat, closeTo(.5, .01));
    expect(scoop.carbohydrates, 0);
    expect(scoop.sugars, 0);
    expect(scoop.cholesterolMg, closeTo(5, .01));
    expect(scoop.sodiumMg, closeTo(190, .01));
    expect(scoop.calciumMg, closeTo(370, .01));
    expect(scoop.potassiumMg, closeTo(100, .01));
  });

  test('Rule 1 R1 Whey Blend 35 g scoop qiymatlari aynan mos', () {
    final food = searchUzbekFoods(
      'Rule 1',
    ).singleWhere((item) => item.productType == 'WHEY PROTEIN BLEND');
    expect(food.productType, 'WHEY PROTEIN BLEND');
    final scoop = food.forGrams(35);
    expect(scoop.calories, closeTo(130, .01));
    expect(scoop.protein, closeTo(24, .01));
    expect(scoop.fat, closeTo(2.5, .01));
    expect(scoop.saturatedFat, closeTo(1, .01));
    expect(scoop.carbohydrates, closeTo(4, .01));
    expect(scoop.fiber, closeTo(1, .01));
    expect(scoop.sugars, closeTo(1, .01));
    expect(scoop.cholesterolMg, closeTo(80, .01));
    expect(scoop.sodiumMg, closeTo(120, .01));
    expect(scoop.calciumMg, closeTo(170, .01));
    expect(scoop.ironMg, closeTo(1, .01));
    expect(scoop.potassiumMg, closeTo(250, .01));
  });

  test('Kevin Levrone Gold Whey 30 g scoop qiymatlari aynan mos', () {
    final food = searchUzbekFoods('Gold Whey').single;
    expect(food.productType, 'WHEY PROTEIN CONCENTRATE (WPC)');
    expect(food.calories, 393);
    expect(food.protein, 75);
    expect(food.fat, 4.1);
    expect(food.saturatedFat, 2.4);
    expect(food.carbohydrates, 14);
    expect(food.sugars, 4.5);
    expect(food.salt, .38);
    expect(food.labelDetails, contains('120 kcal'));
    expect(food.labelDetails, contains('23 g'));
  });

  test('ANABOLIC PRIME-PRO 30 g scoop qiymatlari aynan mos', () {
    final food = searchUzbekFoods('ANABOLIC PRIME-PRO').single;
    expect(food.productType, 'PROTEIN POWDER');
    expect(food.calories, 375);
    expect(food.protein, 75);
    expect(food.fat, 6.1);
    expect(food.saturatedFat, 4.4);
    expect(food.carbohydrates, 5);
    expect(food.sugars, 4.3);
    expect(food.salt, .5);
    expect(food.calciumMg, 390);
    expect(food.phosphorusMg, 354);
    expect(food.labelDetails, contains('112 kcal'));
    expect(food.labelDetails, contains('22,5 g'));
  });

  test('MuscleTech NITRO-TECH 34 g scoop qiymatlari aynan mos', () {
    final food = searchUzbekFoods('NITRO-TECH').single;
    expect(food.productType, 'WHEY PROTEIN BLEND');
    final scoop = food.forGrams(34);
    expect(scoop.calories, closeTo(130, .01));
    expect(scoop.protein, closeTo(24, .01));
    expect(scoop.fat, closeTo(2, .01));
    expect(scoop.saturatedFat, closeTo(1.5, .01));
    expect(scoop.carbohydrates, closeTo(3, .01));
    expect(scoop.sugars, closeTo(2, .01));
    expect(scoop.cholesterolMg, closeTo(70, .01));
    expect(scoop.calciumMg, closeTo(120, .01));
    expect(scoop.ironMg, closeTo(.3, .01));
    expect(scoop.sodiumMg, closeTo(260, .01));
    expect(scoop.potassiumMg, closeTo(140, .01));
  });

  test('ISO-100 yorliq va 32 g scoop qiymatlari aynan mos', () {
    final food = searchUzbekFoods('ISO-100').single;
    expect(food.productType, 'HYDROLYZED WHEY PROTEIN ISOLATE');
    final scoop = food.forGrams(32);
    expect(scoop.calories, 120);
    expect(scoop.protein, 25);
    expect(scoop.fat, 1);
    expect(scoop.carbohydrates, 2);
    expect(scoop.sugars, 1);
    expect(scoop.sodiumMg, 180);
    expect(scoop.potassiumMg, 230);
    expect(scoop.calciumMg, 120);
    expect(scoop.ironMg, .8);
    expect(scoop.cholesterolMg, 10);
    expect(food.labelDetails, contains('kletchatka <1 g'));
  });

  test('CARNIVOR yorliq va scoop qiymatlari aynan mos', () {
    final food = searchUzbekFoods('CARNIVOR').single;
    expect(food.productType, 'HYDROLYZED BEEF PROTEIN ISOLATE');
    final scoop = food.forGrams(33.9);
    expect(scoop.calories, closeTo(120, .01));
    expect(scoop.protein, closeTo(23, .01));
    expect(scoop.carbohydrates, closeTo(6, .01));
    expect(scoop.fiber, closeTo(1, .01));
    expect(scoop.fat, 0);
    expect(scoop.sodiumMg, closeTo(350, .01));
    expect(scoop.potassiumMg, closeTo(220, .01));
    expect(scoop.ironMg, closeTo(1, .01));
  });

  test('ISO-XP yorliq qiymatlari va isolate turi aynan saqlanadi', () {
    final food = searchUzbekFoods(
      'ISO-XP',
    ).singleWhere((item) => item.localName!.contains('Vanil'));
    expect(food.productType, 'ISOLATE');
    expect(food.calories, 374);
    expect(food.protein, 89.2);
    expect(food.fat, .4);
    expect(food.carbohydrates, 2);
    expect(food.sugars, .8);
    expect(food.saturatedFat, .3);
    expect(food.salt, .6);
    expect(food.ingredients, contains('97%'));

    final scoop = food.forGrams(25);
    expect(scoop.calories, closeTo(93.5, .001));
    expect(scoop.protein, closeTo(22.3, .001));
    expect(scoop.fat, closeTo(.1, .001));
    expect(scoop.carbohydrates, closeTo(.5, .001));
  });

  test('ISO-XP shokolad yorliq qiymatlari aynan mos', () {
    final food = searchUzbekFoods(
      'ISO-XP',
    ).singleWhere((item) => item.localName!.contains('Shokolad'));
    expect(food.productType, 'ISOLATE');
    expect(food.calories, 360);
    expect(food.protein, 87);
    expect(food.fat, 1.6);
    expect(food.saturatedFat, .8);
    expect(food.carbohydrates, 1.6);
    expect(food.sugars, .8);
    expect(food.salt, .56);
    expect(food.ingredients, contains('92%'));
    expect(food.labelDetails, contains('92 kcal'));
  });

  test('FatSecret tovuq filesi qiymatlari aynan mos', () {
    final result = searchUzbekFoods('tovuq filesi').single;
    expect(result.calories, 110);
    expect(result.protein, 23.09);
    expect(result.fat, 1.24);
    expect(result.carbohydrates, 0);
  });

  group('FoodNutrition', () {
    const reference = FoodNutrition(
      fdcId: 123,
      name: 'Pilaf',
      calories: 200,
      protein: 8,
      fat: 6,
      carbohydrates: 30,
      water: 54,
      fiber: 4,
      confidence: .96,
    );

    test('100 g qiymatlarini foydalanuvchi grammiga mos hisoblaydi', () {
      final portion = reference.forGrams(250);

      expect(portion.grams, 250);
      expect(portion.calories, closeTo(500, .001));
      expect(portion.protein, closeTo(20, .001));
      expect(portion.fat, closeTo(15, .001));
      expect(portion.carbohydrates, closeTo(75, .001));
      expect(portion.water, closeTo(135, .001));
      expect(portion.fiber, closeTo(10, .001));
      expect(portion.confidence, .96);
    });

    test('1 kg qiymati 100 g qiymatidan aynan 10 baravar hisoblanadi', () {
      final portion = reference.forGrams(1000);

      expect(portion.calories, 2000);
      expect(portion.protein, 80);
      expect(portion.fat, 60);
      expect(portion.carbohydrates, 300);
      expect(portion.water, 540);
      expect(portion.fiber, 40);
    });

    test('bir xil mahsulotlarning tayyorlanish turi nomda farqlanadi', () {
      const raw = FoodNutrition(
        fdcId: 1,
        name: 'Carrots, raw',
        localName: 'sabzi',
        calories: 41,
        protein: .9,
        fat: .2,
        carbohydrates: 9.6,
        water: 88,
      );
      const boiled = FoodNutrition(
        fdcId: 2,
        name: 'Carrots, cooked, boiled, drained, without salt',
        localName: 'sabzi',
        calories: 35,
        protein: .8,
        fat: .2,
        carbohydrates: 8.2,
        water: 90,
      );
      const dried = FoodNutrition(
        fdcId: 3,
        name: 'Carrots, dehydrated',
        localName: 'sabzi',
        calories: 341,
        protein: 8,
        fat: 1.5,
        carbohydrates: 79,
        water: 4,
      );

      expect(raw.displayNameFor('uz'), 'sabzi — xom');
      expect(
        boiled.displayNameFor('uz'),
        'sabzi — qaynatilgan, suvi to‘kilgan, tuzsiz',
      );
      expect(dried.displayNameFor('uz'), 'sabzi — quritilgan');
      expect(raw.displayNameFor('ru'), 'sabzi — сырой');
      expect(raw.displayNameFor('en'), 'Carrots, raw');
    });

    test('nom farqlash tuxum, pomidor, kartoshka va tovuqda ham ishlaydi', () {
      FoodNutrition food(String name, String localName) => FoodNutrition(
        fdcId: name.hashCode,
        name: name,
        localName: localName,
        calories: 1,
        protein: 1,
        fat: 1,
        carbohydrates: 1,
        water: 1,
      );

      expect(
        food('Egg, whole, cooked, hard-boiled', 'tuxum').displayNameFor('uz'),
        'tuxum — qattiq qaynatilgan',
      );
      expect(
        food(
          'Tomato products, canned, sauce, without salt',
          'pomidor',
        ).displayNameFor('uz'),
        'pomidor — sousi, konservalangan, tuzsiz',
      );
      expect(
        food('Potatoes, baked, skin', 'kartoshka').displayNameFor('uz'),
        'kartoshka — pechda pishirilgan, terisi',
      );
      expect(
        food('Chicken, breast, grilled', 'tovuq').displayNameFor('uz'),
        'tovuq — grilda pishirilgan, ko‘krak qismi',
      );
    });

    test('sut mahsulotlari yog‘lilik va turi bo‘yicha farqlanadi', () {
      FoodNutrition dairy(String name, String localName) => FoodNutrition(
        fdcId: name.hashCode,
        name: name,
        localName: localName,
        calories: 1,
        protein: 1,
        fat: 1,
        carbohydrates: 1,
        water: 1,
      );

      expect(
        dairy('Milk, lowfat, fluid, 1% milkfat', 'sut').displayNameFor('uz'),
        'sut — kam yog‘li, 1% yog‘li',
      );
      expect(
        dairy('Milk, lactose-free, whole', 'sut').displayNameFor('uz'),
        'sut — to‘liq yog‘li, laktozasiz',
      );
      expect(
        dairy('Kefir, lowfat, plain', 'kefir').displayNameFor('uz'),
        'kefir — kam yog‘li, tabiiy',
      );
      expect(
        dairy(
          'Cheese spread, Cheddar cheese base',
          'pishloq',
        ).displayNameFor('uz'),
        'pishloq — surtiladigan, Cheddar turi',
      );
      expect(
        dairy(
          'Yogurt, Greek, strawberry, nonfat',
          'yogurt',
        ).displayNameFor('ru'),
        'yogurt — обезжиренный, греческий, клубничный',
      );
      expect(
        dairy('Sour cream, light, 10% milkfat', 'smetana').displayNameFor('uz'),
        'smetana — yengil, 10% yog‘li',
      );
      expect(
        dairy('Yogurt, frozen, chocolate', 'yogurt').displayNameFor('uz'),
        'yogurt — muzlatilgan yogurt, shokoladli',
      );
      expect(
        dairy(
          'Cream, heavy, whipping, pasteurized',
          'qaymoq',
        ).displayNameFor('uz'),
        'qaymoq — quyuq qaymoq, ko‘pirtirish uchun, pasterizatsiyalangan',
      );
    });

    test('Firestore map round-trip ma’lumotlarni yo‘qotmaydi', () {
      final original = reference.forGrams(180, localName: 'Osh');
      final restored = FoodNutrition.fromMap(original.toMap());

      expect(restored.fdcId, original.fdcId);
      expect(restored.name, original.name);
      expect(restored.displayName, 'Osh (Pilaf)');
      expect(restored.grams, original.grams);
      expect(restored.calories, original.calories);
      expect(restored.protein, original.protein);
      expect(restored.fat, original.fat);
      expect(restored.fiber, original.fiber);
      expect(restored.carbohydrates, original.carbohydrates);
      expect(restored.water, original.water);
      expect(restored.confidence, original.confidence);
    });
  });

  test('UserProfile map round-trip barcha maydonlarni saqlaydi', () {
    const profile = UserProfile(
      firstName: 'Aziz',
      lastName: 'Karimov',
      gender: 'male',
      age: 27,
      heightCm: 178,
      weightKg: 76.5,
      activityLevel: 'medium',
      goal: 'maintain',
      photoUrl: 'https://example.com/avatar.jpg',
    );
    final restored = UserProfile.fromMap(profile.toMap());

    expect(restored.fullName, 'Aziz Karimov');
    expect(restored.gender, profile.gender);
    expect(restored.age, profile.age);
    expect(restored.photoUrl, profile.photoUrl);
    expect(restored.heightCm, profile.heightCm);
    expect(restored.weightKg, profile.weightKg);
    expect(restored.activityLevel, profile.activityLevel);
    expect(restored.goal, 'maintain');
  });

  test('O‘zbekcha ovqat nomi USDA so‘roviga tarjima qilinadi', () async {
    final translated = await FoodQueryTranslator().translate('osh');

    expect(translated.english, 'rice cooked');
    expect(translated.localLabel, 'osh');
  });

  test('sut mahsulotlari USDA uchun aniq nomga tarjima qilinadi', () async {
    final translator = FoodQueryTranslator();

    expect(
      (await translator.translate('quruq sut')).english,
      'dry milk powder',
    );
    expect(
      (await translator.translate('quyultirilgan sut')).english,
      'condensed milk',
    );
    expect(
      (await translator.translate('motsarella')).english,
      'mozzarella cheese',
    );
    expect(
      (await translator.translate('ryajenka')).english,
      'fermented baked milk',
    );
    expect((await translator.translate('smetana')).english, 'sour cream');
    expect((await translator.translate('quyuq qaymoq')).english, 'heavy cream');
    expect(
      (await translator.translate('qulupnayli yogurt')).english,
      'strawberry yogurt',
    );
  });

  test('mahsulot qidiruvi katta-kichik harfga bog‘liq emas', () async {
    final translator = FoodQueryTranslator();

    for (final query in ['smetana', 'Smetana', 'SMETANA', 'sMeTaNa']) {
      expect(
        (await translator.translate(query)).english,
        'sour cream',
        reason: query,
      );
    }
    for (final query in ['quyuq qaymoq', 'Quyuq Qaymoq', 'QUYUQ QAYMOQ']) {
      expect(
        (await translator.translate(query)).english,
        'heavy cream',
        reason: query,
      );
    }

    final lower = searchUzbekFoods('samarqand oshi');
    final upper = searchUzbekFoods('SAMARQAND OSHI');
    expect(lower.map((food) => food.fdcId), upper.map((food) => food.fdcId));
  });

  test('ichimlik nomlari USDA uchun aniq variantga tarjima qilinadi', () async {
    final translator = FoodQueryTranslator();

    expect(
      (await translator.translate('coca cola zero')).english,
      'coca-cola zero sugar',
    );
    expect(
      (await translator.translate('pepsi zero')).english,
      'pepsi zero sugar',
    );
    expect(
      (await translator.translate('fanta apelsin')).english,
      'fanta orange',
    );
    expect(
      (await translator.translate('energetik ichimlik')).english,
      'energy drink',
    );
  });

  test('brendli ichimlik qidiruvi USDA Branded bazasini tanlaydi', () async {
    late Uri sentUri;
    final client = MockClient((request) async {
      sentUri = request.url;
      return http.Response(
        jsonEncode({
          'foods': [
            {
              'fdcId': 999,
              'description': 'COCA-COLA ZERO SUGAR',
              'foodNutrients': [
                {
                  'nutrientId': 1008,
                  'nutrientName': 'Energy',
                  'unitName': 'KCAL',
                  'value': 0,
                },
                {
                  'nutrientId': 1005,
                  'nutrientName': 'Carbohydrate, by difference',
                  'unitName': 'G',
                  'value': 0,
                },
              ],
            },
          ],
        }),
        200,
      );
    });

    final foods = await FoodDataService(client: client).search('cola zero');

    // Nol kaloriyali ichimlik ham haqiqiy natija sifatida saqlanishi kerak.
    expect(sentUri.queryParameters['query'], 'cola zero sugar');
    expect(sentUri.queryParameters['dataType'], 'Branded');
    expect(foods, hasLength(1));
    expect(foods.single.displayNameFor('uz'), contains('Zero, shakarsiz'));
  });

  test(
    'cola qidiruvi Coca-Cola Zero va Pepsi Zero natijalarini qo‘shadi',
    () async {
      final queries = <String>{};
      final client = MockClient((request) async {
        final query = request.url.queryParameters['query']!;
        queries.add(query);
        final data = switch (query) {
          'coca-cola zero sugar' => (
            902,
            'COLA, ZERO SUGAR',
            'COCA-COLA ZERO SUGAR',
          ),
          'pepsi zero sugar' => (903, 'COLA, ZERO SUGAR', 'PEPSI ZERO SUGAR'),
          _ => (901, 'COLA, CLASSIC', 'COCA-COLA'),
        };
        return http.Response(
          jsonEncode({
            'foods': [
              {
                'fdcId': data.$1,
                'description': data.$2,
                'brandName': data.$3,
                'foodNutrients': [
                  {
                    'nutrientId': 1008,
                    'nutrientName': 'Energy',
                    'unitName': 'KCAL',
                    'value': query == 'cola' ? 42 : 0,
                  },
                ],
              },
            ],
          }),
          200,
        );
      });

      final foods = await FoodDataService(client: client).search('cola');
      final names = foods.map((food) => food.displayNameFor('uz')).join(' | ');

      expect(
        queries,
        containsAll(['cola', 'coca-cola zero sugar', 'pepsi zero sugar']),
      );
      expect(names, contains('Coca-Cola'));
      expect(names, contains('Pepsi'));
      expect(names, contains('Zero, shakarsiz'));
    },
  );

  test('USDA sabzavot qiymatlarini 100 g bazada o‘qiydi', () async {
    final client = MockClient((request) async {
      expect(request.url.host, 'api.nal.usda.gov');
      expect(request.url.path, '/fdc/v1/foods/search');
      expect(request.url.queryParameters['query'], 'tomato');
      return http.Response(
        jsonEncode({
          'foods': [
            {
              'fdcId': 170457,
              'description': 'Tomatoes, red, ripe, raw',
              'foodNutrients': [
                {
                  'nutrientId': 1008,
                  'nutrientName': 'Energy',
                  'unitName': 'KCAL',
                  'value': 18,
                },
                {
                  'nutrientId': 1003,
                  'nutrientName': 'Protein',
                  'unitName': 'G',
                  'value': 0.88,
                },
                {
                  'nutrientId': 1004,
                  'nutrientName': 'Total lipid (fat)',
                  'unitName': 'G',
                  'value': 0.2,
                },
                {
                  'nutrientId': 1005,
                  'nutrientName': 'Carbohydrate, by difference',
                  'unitName': 'G',
                  'value': 3.89,
                },
                {
                  'nutrientId': 1051,
                  'nutrientName': 'Water',
                  'unitName': 'G',
                  'value': 94.52,
                },
                {
                  'nutrientId': 1079,
                  'nutrientName': 'Fiber, total dietary',
                  'unitName': 'G',
                  'value': 1.2,
                },
              ],
            },
          ],
        }),
        200,
      );
    });

    final foods = await FoodDataService(client: client).search('pomidor');
    final tomato = foods.singleWhere((food) => food.fdcId == 170457);

    expect(tomato.grams, 100);
    expect(tomato.calories, 18);
    expect(tomato.protein, .88);
    expect(tomato.fat, .2);
    expect(tomato.carbohydrates, 3.89);
    expect(tomato.water, 94.52);
    expect(tomato.fiber, 1.2);
    expect(tomato.forGrams(1000).protein, 8.8);
  });

  test('Open Food Facts 100 g oziq qiymatlarini to‘g‘ri o‘qiydi', () async {
    late Map<String, String> sentHeaders;
    final client = MockClient((request) async {
      sentHeaders = request.headers;
      return http.Response(
        jsonEncode({
          'products': [
            {
              'code': '4780000000001',
              'product_name': 'O‘zbek noni',
              'brands': 'MyFit Test',
              'nutriments': {
                'energy-kcal_100g': 265,
                'proteins_100g': 8.5,
                'fat_100g': 3.2,
                'carbohydrates_100g': 49,
              },
            },
          ],
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final foods = await OpenFoodFactsService(client: client).search('non');

    expect(foods, hasLength(1));
    expect(foods.single.name, 'O‘zbek noni — MyFit Test');
    expect(foods.single.calories, 265);
    expect(foods.single.protein, 8.5);
    expect(foods.single.fat, 3.2);
    expect(foods.single.carbohydrates, 49);
    expect(foods.single.hasWaterData, isFalse);
    expect(sentHeaders['user-agent'], contains('MyFit/1.0'));
  });

  test('Shtrix-kod mahsulot oziq qiymatlarini qaytaradi', () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/api/v2/product/4780000000001.json');
      return http.Response(
        jsonEncode({
          'status': 1,
          'product': {
            'code': '4780000000001',
            'product_name': 'Test yogurt',
            'nutriments': {
              'energy-kcal_100g': 95,
              'proteins_100g': 4.2,
              'fat_100g': 2.8,
              'carbohydrates_100g': 12,
              'fiber_100g': 0.4,
            },
          },
        }),
        200,
      );
    });

    final food = await OpenFoodFactsService(
      client: client,
    ).findByBarcode('4780000000001');

    expect(food, isNotNull);
    expect(food!.name, 'Test yogurt');
    expect(food.calories, 95);
    expect(food.fiber, .4);
  });

  testWidgets('Ovqatlar sahifasi 5 mahalni ko‘rsatadi', (tester) async {
    MealType? selectedMeal;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MealsPage(
            onMealSelected: (meal) => selectedMeal = meal,
            dailyTarget: 2100,
            weekCalories: {today: 2100},
          ),
        ),
      ),
    );

    expect(find.text('HAFTALIK MAQSAD'), findsOneWidget);
    expect(find.text('2100 / 2100'), findsOneWidget);
    expect(find.byIcon(LucideIcons.check), findsOneWidget);
    expect(find.text('Kletchatka'), findsOneWidget);
    expect(find.text('Bugungi ovqatlanish rejasi'), findsNothing);
    expect(find.text('Nonushta'), findsOneWidget);
    expect(find.text('Tushlik (Abed)'), findsOneWidget);
    expect(find.text('Kechki ovqat'), findsOneWidget);
    expect(find.text('Perekus'), findsOneWidget);
    expect(find.text('Kechki tamaddi'), findsOneWidget);
    expect(find.text('5 mahal'), findsOneWidget);

    await tester.tap(find.text('Nonushta'));
    expect(selectedMeal, MealType.breakfast);
  });

  testWidgets('mahal kartasi qo‘shilgan ovqatni ochib ko‘rsatadi', (
    tester,
  ) async {
    const breakfast = FoodNutrition(
      fdcId: 9001,
      name: 'Tovuq shashlik',
      calories: 180,
      protein: 24,
      fat: 8,
      carbohydrates: 2,
      water: 60,
      grams: 100,
      mealType: 'breakfast',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MealsPage(
            onMealSelected: (_) {},
            foods: const [breakfast],
            onFoodRemoved: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Ro'yxat avtomatik yopiq turadi.
    expect(find.text('1 mahsulot · 180 kcal'), findsOneWidget);
    expect(find.text('Tovuq shashlik'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('meal-toggle-breakfast')));
    await tester.pumpAndSettle();
    expect(find.text('Tovuq shashlik'), findsOneWidget);
    expect(find.text('180 kcal'), findsOneWidget);
    expect(find.byIcon(LucideIcons.trash2), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('meal-toggle-breakfast')));
    await tester.pumpAndSettle();
    expect(find.text('Tovuq shashlik'), findsNothing);
  });

  testWidgets('Profil sahifasi shaxsiy ma’lumotlarni ko‘rsatadi', (
    tester,
  ) async {
    const profile = UserProfile(
      firstName: 'Samir',
      lastName: 'Aliyev',
      gender: 'male',
      age: 25,
      heightCm: 186,
      weightKg: 70,
      activityLevel: 'medium',
      goal: 'maintain',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProfilePage(
            profile: profile,
            phoneNumber: '+998901234567',
            onSave: (_) async {},
            onSignOut: () async {},
          ),
        ),
      ),
    );

    expect(find.text('Samir Aliyev'), findsOneWidget);
    expect(find.text('70.0 kg'), findsOneWidget);
    expect(find.text('186 cm'), findsOneWidget);
    expect(find.text('Vaznni saqlash'), findsOneWidget);
    expect(find.text('O‘rtacha faollik'), findsOneWidget);
    expect(find.text('Profilni tahrirlash'), findsOneWidget);
  });

  testWidgets('Rus tilida ovqatlanish sahifasi to‘liq tarjima qilinadi', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ru'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(
          body: MealsPage(onMealSelected: (_) {}, dailyTarget: 2100),
        ),
      ),
    );

    expect(find.text('НЕДЕЛЬНАЯ ЦЕЛЬ'), findsOneWidget);
    expect(find.text('Меню на сегодня'), findsOneWidget);
    expect(find.text('Завтрак'), findsOneWidget);
    expect(find.text('5 приёмов пищи'), findsOneWidget);
    expect(find.text('HAFTALIK MAQSAD'), findsNothing);
    expect(find.text('Bugungi menyu'), findsNothing);
    expect(find.text('Nonushta'), findsNothing);
    expect(find.text('5 mahal'), findsNothing);
  });

  testWidgets('Ingliz tilida kalkulyatorlar to‘liq tarjima qilinadi', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: const CalculatorPage(),
      ),
    );

    expect(find.text('Fitness calculators'), findsOneWidget);
    expect(find.text('Daily calories and BMR'), findsOneWidget);
    expect(find.text('Body fat percentage'), findsOneWidget);
    expect(find.text('Fitness kalkulyatorlari'), findsNothing);
  });

  testWidgets('Tushlik milliy taomlar katalogini ochadi', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('uz'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: const NationalFoodPickerPage(meal: MealType.lunch),
      ),
    );

    expect(find.text('Taom nomini yozib qidiring'), findsOneWidget);
    expect(find.text('Samarqand oshi'), findsNothing);
    await tester.enterText(find.byType(TextField), 'Manti');
    await tester.pump();
    expect(find.text('Manti'), findsWidgets);
    await tester.enterText(find.byType(TextField), 'Sumalak');
    await tester.pump();
    expect(find.text('Sumalak'), findsWidgets);
  });

  testWidgets('milliy taomni gramm bilan qo‘shish xatosiz yakunlanadi', (
    tester,
  ) async {
    List<FoodNutrition>? selectedFoods;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('uz'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () async {
                  selectedFoods = await Navigator.push<List<FoodNutrition>>(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          const NationalFoodPickerPage(meal: MealType.lunch),
                    ),
                  );
                },
                child: const Text('Ochish'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Ochish'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Samarqand oshi');
    await tester.pump();
    await tester.tap(find.text('Samarqand oshi').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '150');
    await tester.tap(find.text('Saqlash'));
    await tester.pumpAndSettle();
    // Savat boshqaruvi pastda emas, tepadagi AppBar ichida.
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.byKey(const Key('basket-add')),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('basket-open')),
        matching: find.text('1'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('basket-add')));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(selectedFoods, hasLength(1));
    expect(selectedFoods!.single.grams, 150);
    expect(selectedFoods!.single.calories, closeTo(348, .001));
  });

  testWidgets(
    'global mahsulotni ketma-ket qo‘shish dependents assertion bermaydi',
    (tester) async {
      var addedCount = 0;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('uz'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () async {
                    final selected = await Navigator.push<List<FoodNutrition>>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => NationalFoodPickerPage(
                          meal: MealType.breakfast,
                          foodDataService: _FakeFoodDataService(),
                        ),
                      ),
                    );
                    addedCount += selected?.length ?? 0;
                  },
                  child: const Text('Global qidiruv'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Global qidiruv'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'pomidor');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      // Bitta oynada uchta porsiya saqlanadi, keyin birdaniga qo'shiladi.
      for (var attempt = 0; attempt < 3; attempt++) {
        await tester.tap(find.text('pomidor — xom'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Saqlash'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      expect(
        find.descendant(
          of: find.byKey(const Key('basket-open')),
          matching: find.text('3'),
        ),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('basket-add')));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(addedCount, 3);
    },
  );

  test('osh qidiruvi barcha hududiy osh variantlarini qaytaradi', () {
    final results = searchUzbekFoods('osh');

    expect(results.map((food) => food.name), contains('Samarqand oshi'));
    expect(results.map((food) => food.name), contains('Toshkent oshi'));
    expect(results.map((food) => food.name), contains('Andijon oshi'));
    expect(results.map((food) => food.name), contains('Farg‘ona devzira oshi'));
    expect(results.map((food) => food.name), contains('Buxoro oshi sofi'));
    expect(results.map((food) => food.name), contains('Xorazm shivit oshi'));
    expect(results.every((food) => food.calories > 0), isTrue);
  });

  test('milliy taomlar katalogidagi 100 g qiymatlar valid', () {
    expect(kUzbekDishes.length, greaterThanOrEqualTo(50));
    expect(
      kUzbekDishes.map((dish) => dish.nutrition.fdcId).toSet(),
      hasLength(kUzbekDishes.length),
    );
    for (final dish in kUzbekDishes) {
      final food = dish.nutrition;
      expect(food.grams, 100, reason: dish.nameUz);
      final isSupplement = food.productType?.contains('SUPPLEMENT') == true;
      final calorieCeiling = isSupplement ? 1200 : 910;
      expect(
        food.calories,
        inInclusiveRange(0, calorieCeiling),
        reason: dish.nameUz,
      );
      expect(food.protein, inInclusiveRange(0, 100), reason: dish.nameUz);
      expect(food.fat, inInclusiveRange(0, 100), reason: dish.nameUz);
      expect(food.carbohydrates, inInclusiveRange(0, 100), reason: dish.nameUz);
      expect(food.fiber, inInclusiveRange(0, 50), reason: dish.nameUz);
      expect(food.water, inInclusiveRange(0, 100), reason: dish.nameUz);
      expect(dish.meals, isNotEmpty, reason: dish.nameUz);
    }
  });

  test('barcha ovqat mahallari aynan bitta to‘liq bazani ko‘rsatadi', () {
    final expectedIds = kUzbekDishes
        .map((dish) => dish.nutrition.fdcId)
        .toSet();
    for (final meal in MealType.values) {
      expect(
        uzbekDishesForMeal(
          meal.name,
        ).map((dish) => dish.nutrition.fdcId).toSet(),
        expectedIds,
        reason: meal.name,
      );
    }
  });

  test('hudud nomi faqat tegishli oshni qaytaradi', () {
    final results = searchUzbekFoods('Samarqand oshi');

    expect(results, hasLength(1));
    expect(results.single.name, 'Samarqand oshi');
    expect(results.single.forGrams(200).calories, closeTo(464, .001));
  });

  test(
    'Calculator.net Mifflin–St Jeor usulida kunlik kaloriyani hisoblaydi',
    () {
      final result = const CalorieNeedsCalculator().calculate(
        age: 25,
        sex: BiologicalSex.male,
        heightCm: 180,
        weightKg: 80,
        activityFactor: 1.2,
      );

      expect(result.bmr, 1805);
      expect(result.maintenance, 2166);
      expect(result.weightLoss, 1666);
    },
  );

  test('U.S. Navy usulida tana yog‘ini hisoblaydi', () {
    final result = const BodyFatCalculator().calculate(
      sex: BiologicalSex.male,
      age: 25,
      weightKg: 70,
      heightCm: 175,
      neckCm: 38,
      waistCm: 82,
    );

    expect(result.navyPercent, closeTo(14.5, .2));
    expect(result.category, 'Fitness');
    expect(result.fatMassKg + result.leanMassKg, closeTo(70, .001));
    expect(result.idealPercent, 10.5);
  });

  testWidgets('Fitness kalkulyatorlari kerakli bo‘limlarni ko‘rsatadi', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: CalculatorPage()));

    expect(find.text('Fitness kalkulyatorlari'), findsOneWidget);
    expect(find.text('Kunlik kaloriya va BMR'), findsOneWidget);
    expect(find.text('BMI va sog‘lom vazn'), findsNothing);
    expect(find.text('Tana yog‘i foizi'), findsOneWidget);
    expect(find.text('Ovqat tarkibi'), findsNothing);
    expect(find.text('Kunlik suv ehtiyoji'), findsOneWidget);
  });

  testWidgets('Kunlik kaloriya kalkulyatori natijalarni ko‘rsatadi', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: CalorieCalculatorPage()));
    await tester.tap(find.text('Hisoblash'));
    await tester.pump();

    expect(find.text('Vaznni saqlash'), findsOneWidget);
    expect(find.text('Tez vazn olish'), findsNothing);
    expect(find.textContaining('kcal'), findsWidgets);
    expect(find.textContaining('kcal/kun'), findsNothing);
    expect(find.textContaining('Uglevod'), findsNothing);
    expect(find.textContaining('Oqsil'), findsNothing);
    expect(find.textContaining('Yog‘'), findsNothing);
    expect(find.text('−0,25 kg / hafta'), findsOneWidget);
    expect(find.text('−0,5 kg / hafta'), findsOneWidget);
    expect(find.text('−1 kg / hafta'), findsOneWidget);
    expect(find.textContaining('%'), findsNothing);

    final toggle = find.byKey(const Key('toggle-gain-info'));
    await tester.ensureVisible(toggle);
    await tester.pumpAndSettle();
    await tester.tap(toggle);
    await tester.pump();
    expect(find.text('Yengil vazn olish'), findsOneWidget);
    expect(find.text('Vazn olish'), findsOneWidget);
    expect(find.text('Tez vazn olish'), findsOneWidget);
    expect(find.text('Vazn olish rejalarini yopish'), findsOneWidget);
    expect(find.text('+0,25 kg / hafta'), findsOneWidget);
    expect(find.text('+0,5 kg / hafta'), findsOneWidget);
    expect(find.text('+1 kg / hafta'), findsOneWidget);
  });

  testWidgets('BMR rejimida faqat BMR natijasi chiqadi', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: CalorieCalculatorPage()));

    await tester.tap(find.text('Kamharakat: mashqsiz yoki juda kam'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('BMR — dam olish holati').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hisoblash'));
    await tester.pump();

    expect(find.byKey(const Key('bmr-only-value')), findsOneWidget);
    expect(find.byKey(const Key('calorie-goal-results')), findsNothing);
    expect(find.text('Vaznni saqlash'), findsNothing);
    expect(find.text('Vazn olish rejalarini ko‘rish'), findsNothing);
  });

  testWidgets('Tana yog‘i kalkulyatori faqat foiz natijasini chiqaradi', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: BodyFatCalculatorPage()));
    await tester.tap(find.text('Hisoblash'));
    await tester.pump();
    expect(find.byKey(const Key('body-fat-result')), findsOneWidget);
    expect(
      find.text('O‘lchov birligi: kilogramm va santimetr'),
      findsOneWidget,
    );
    expect(find.text('Yog‘ massasi'), findsNothing);
    expect(find.text('Yog‘siz massa'), findsNothing);
    expect(find.text('BMI usulidagi natija'), findsNothing);
    expect(find.text('Sportchi'), findsNothing);
    expect(find.text('U.S. Navy usuli'), findsNothing);
  });

  testWidgets('Suv kalkulyatori kunlik litrni chiqaradi', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: WaterCalculatorPage()));
    await tester.enterText(find.byType(TextField).at(1), '120');
    await tester.tap(find.text('Hisoblash'));
    await tester.pump();
    expect(find.text('2.8 litr'), findsOneWidget);
    expect(find.text('Asosiy ehtiyoj'), findsNothing);
    expect(find.text('Mashq qo‘shimchasi'), findsNothing);
    expect(find.text('Issiq ob-havo'), findsNothing);
  });
}

class _FakeFoodDataService extends FoodDataService {
  @override
  Future<List<FoodNutrition>> search(
    String query, {
    String languageCode = 'uz',
  }) async {
    return const [
      FoodNutrition(
        fdcId: 170457,
        name: 'Tomatoes, raw',
        localName: 'pomidor',
        calories: 18,
        protein: .88,
        fat: .2,
        carbohydrates: 3.89,
        water: 94.52,
        fiber: 1.2,
      ),
    ];
  }
}
