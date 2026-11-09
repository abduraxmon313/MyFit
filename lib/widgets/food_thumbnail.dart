import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../models/food_nutrition.dart';
import '../theme/app_theme.dart';
import 'app_ui.dart';

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

/// Category icon for a food. Illustrations are intentionally not used; a
/// single line-icon family keeps lists calm and scannable.
IconData foodCategoryIcon(FoodNutrition food, {String? region}) {
  if (_isSupplement(food)) return LucideIcons.pill;
  final name = '${food.name} ${food.localName ?? ''}'.toLowerCase();
  bool has(List<String> words) => words.any(name.contains);
  if (has(['egg', 'tuxum', 'яйц', 'omlet'])) return LucideIcons.egg;
  switch (region) {
    case 'Mevalar' || 'O‘rmon mevalari' || 'Quruq mevalar':
      return LucideIcons.apple;
    case 'Sabzavotlar':
      return LucideIcons.carrot;
    case 'Yong‘oq va urug‘lar':
      return LucideIcons.nut;
    case 'Sut mahsulotlari' || 'Pishloqlar':
      return LucideIcons.milk;
    case 'Baliqlar':
      return LucideIcons.fish;
    case 'Mol qismlari':
      return LucideIcons.beef;
    case 'Nonlar':
      return LucideIcons.wheat;
    case 'Shirinliklar':
      return LucideIcons.cookie;
    case 'Ichimliklar':
      return LucideIcons.cupSoda;
    case 'Guruchlar' || 'Garnirlar' || 'Gerkules va suli':
      return LucideIcons.wheat;
  }
  if (has(['fish', 'baliq', 'рыб', 'salmon', 'tuna'])) return LucideIcons.fish;
  if (has(['milk', 'sut', 'молок', 'yogurt', 'kefir', 'cheese', 'pishloq'])) {
    return LucideIcons.milk;
  }
  if (has(['beef', 'chicken', 'mol go', 'tovuq', 'meat', 'go‘sht', 'мяс'])) {
    return LucideIcons.drumstick;
  }
  if (has(['bread', 'non', 'хлеб'])) return LucideIcons.wheat;
  if (has(['cookie', 'cake', 'chocolate', 'shokolad'])) {
    return LucideIcons.cookie;
  }
  if (has(['juice', 'tea', 'coffee', 'choy', 'qahva', 'sharbat', 'water'])) {
    return LucideIcons.cupSoda;
  }
  // Sabzavotlar umumiy "xom"/"raw" qoidasidan oldin tekshiriladi.
  if (has([
    'tomato',
    'pomidor',
    'vegetable',
    'potato',
    'kartoshka',
    'onion',
    'piyoz',
    'carrot',
    'sabzi',
    'cabbage',
    'karam',
    'cucumber',
    'bodring',
    'pepper',
    'qalampir',
    'garlic',
    'sarimsoq',
  ])) {
    return LucideIcons.carrot;
  }
  if (has(['raw', 'xom', 'apple', 'olma', 'berr', 'fruit', 'dried'])) {
    return LucideIcons.apple;
  }
  return LucideIcons.utensils;
}

/// Muted accent for each food category icon.
Color foodCategoryColor(IconData icon) {
  if (icon == LucideIcons.apple) return AppPalette.accentRose;
  if (icon == LucideIcons.carrot) return AppPalette.accentGreen;
  if (icon == LucideIcons.milk) return AppPalette.accentBlue;
  if (icon == LucideIcons.fish) return AppPalette.accentTeal;
  if (icon == LucideIcons.beef || icon == LucideIcons.drumstick) {
    return AppPalette.accentRose;
  }
  if (icon == LucideIcons.wheat || icon == LucideIcons.nut) {
    return AppPalette.accentAmber;
  }
  if (icon == LucideIcons.egg) return AppPalette.accentAmber;
  if (icon == LucideIcons.cupSoda) return AppPalette.accentIndigo;
  if (icon == LucideIcons.cookie || icon == LucideIcons.pill) {
    return AppPalette.accentViolet;
  }
  return AppPalette.accentSlate;
}

/// Softly tinted icon tile representing a food item.
class FoodThumbnail extends StatelessWidget {
  const FoodThumbnail({super.key, required this.icon, this.size = 44});

  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) => AppIconTile.tinted(
    icon: icon,
    size: size,
    accent: foodCategoryColor(icon),
  );
}
