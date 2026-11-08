import 'package:flutter/material.dart';

import '../models/food_nutrition.dart';

/// Qidiruvda ko'rsatiladigan tezkor kategoriya.
class FoodCategory {
  const FoodCategory(this.region, this.asset);

  /// Katalogdagi `UzbekDish.region` qiymati bilan aynan bir xil.
  final String region;
  final String asset;
}

const _produce = 'assets/food_categories/produce.png';
const _dairy = 'assets/food_categories/dairy.png';
const _fish = 'assets/food_categories/fish.png';
const _meat = 'assets/food_categories/meat.png';
const _bread = 'assets/food_categories/bread.png';
const _beverage = 'assets/food_categories/beverage.png';
const _egg = 'assets/food_categories/egg.png';
const _mainDish = 'assets/food_categories/main_dish.png';

const kSearchCategories = <FoodCategory>[
  FoodCategory('Mevalar', _produce),
  FoodCategory('O‘rmon mevalari', _produce),
  FoodCategory('Quruq mevalar', _produce),
  FoodCategory('Sabzavotlar', _produce),
  FoodCategory('Sut mahsulotlari', _dairy),
  FoodCategory('Pishloqlar', _dairy),
  FoodCategory('Baliqlar', _fish),
  FoodCategory('Mol qismlari', _meat),
  FoodCategory('Nonlar', _bread),
  FoodCategory('Garnirlar', _mainDish),
  FoodCategory('Ichimliklar', _beverage),
  FoodCategory('Yong‘oq va urug‘lar', _produce),
];

bool _isSupplement(FoodNutrition food) {
  final type = food.productType?.toUpperCase() ?? '';
  return const [
    'SUPPLEMENT',
    'VITAMIN',
    'MINERAL',
    'OMEGA',
    'ISOLATE',
    'GAINER',
    'PROTEIN',
  ].any(type.contains);
}

/// Mahsulot uchun mos rasm. `null` bo'lsa ikonka ko'rsatiladi.
String? foodThumbnailAsset(FoodNutrition food, {String? region}) {
  if (_isSupplement(food)) return null;
  final name = '${food.name} ${food.localName ?? ''}'.toLowerCase();
  bool has(List<String> words) => words.any(name.contains);
  if (has(['egg', 'tuxum', 'яйц', 'omlet'])) return _egg;
  switch (region) {
    case 'Mevalar' ||
        'O‘rmon mevalari' ||
        'Sabzavotlar' ||
        'Yong‘oq va urug‘lar':
      return _produce;
    case 'Sut mahsulotlari' || 'Pishloqlar':
      return _dairy;
    case 'Baliqlar':
      return _fish;
    case 'Mol qismlari':
      return _meat;
    case 'Nonlar' || 'Shirinliklar':
      return _bread;
    case 'Ichimliklar':
      return _beverage;
  }
  if (has(['fish', 'baliq', 'рыб', 'salmon', 'tuna'])) return _fish;
  if (has(['milk', 'sut', 'молок', 'yogurt', 'kefir', 'cheese', 'pishloq'])) {
    return _dairy;
  }
  if (has(['beef', 'chicken', 'mol go', 'tovuq', 'meat', 'go‘sht', 'мяс'])) {
    return _meat;
  }
  if (has(['bread', 'non', 'хлеб', 'cookie', 'cake'])) return _bread;
  if (has(['juice', 'tea', 'coffee', 'choy', 'qahva', 'sharbat', 'water'])) {
    return _beverage;
  }
  if (has([
    'raw',
    'xom',
    'apple',
    'olma',
    'tomato',
    'pomidor',
    'berr',
    'fruit',
    'vegetable',
  ])) {
    return _produce;
  }
  if (region != null) return _mainDish;
  return null;
}

/// Yumaloq burchakli mahsulot rasmi yoki zaxira ikonka.
class FoodThumbnail extends StatelessWidget {
  const FoodThumbnail({
    super.key,
    required this.asset,
    this.size = 52,
    this.fallbackIcon = Icons.restaurant_rounded,
  });

  final String? asset;
  final double size;
  final IconData fallbackIcon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(size * .3);
    if (asset == null) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: scheme.primaryContainer,
          borderRadius: radius,
        ),
        child: Icon(fallbackIcon, color: scheme.primary, size: size * .46),
      );
    }
    return ClipRRect(
      borderRadius: radius,
      child: Image.asset(
        asset!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        cacheWidth: (size * 3).round(),
        filterQuality: FilterQuality.medium,
      ),
    );
  }
}
