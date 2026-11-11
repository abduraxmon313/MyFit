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
  if (has([
    'rice',
    'guruch',
    'рис',
    'oats',
    'oatmeal',
    'suli',
    'gerkules',
    'pasta',
  ])) {
    return LucideIcons.wheat;
  }
  // "raw"/"xom" alone says nothing about the food (raw rice, raw chicken).
  if (has(['apple', 'olma', 'berr', 'fruit', 'dried', 'meva'])) {
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

/// Exact picture for a known food: (emoji, word stems in uz/ru/en).
/// Order matters: specific foods come before broader ones
/// (sweet potato before potato, eggplant before egg, juice before fruit).
const _foodEmoji = <(String, List<String>)>[
  ('🥤', ['cola', 'pepsi', 'fanta', 'sprite', 'soda', 'gazli']),
  ('🧃', ['juice', 'sharbat', 'сок', 'nectar']),
  ('☕', ['coffee', 'qahva', 'кофе', 'espresso', 'latte', 'cappuccino']),
  ('🍵', ['tea', 'choy', 'чай']),
  ('🍲', ['soup', "sho'rva", 'shurva', 'суп', 'борщ', 'mastava']),
  ('🍠', ['sweet potato', 'batat', 'батат']),
  ('🍆', ['eggplant', 'aubergine', 'baqlajon', 'баклажан']),
  ('🍅', ['tomato', 'pomidor', 'помидор', 'томат']),
  ('🥕', ['carrot', 'sabzi', 'морков']),
  ('🥔', ['potato', 'kartoshka', 'картоф', 'картош']),
  ('🧅', ['onion', 'piyoz', 'лук']),
  ('🧄', ['garlic', 'sarimsoq', 'чеснок']),
  ('🥒', ['cucumber', 'bodring', 'огур']),
  ('🫑', ['bell pepper', 'bulgar qalampir', 'болгарск']),
  ('🌶️', ['chili', 'qalampir', 'перец']),
  (
    '🥬',
    ['cabbage', 'karam', 'капуст', 'lettuce', 'spinach', 'ismaloq', 'шпинат'],
  ),
  ('🥦', ['broccoli', 'брокколи']),
  ('🌽', ['corn', "makkajo'xori", 'кукуруз']),
  ('🎃', ['pumpkin', 'qovoq', 'тыкв']),
  ('🍄', ['mushroom', "qo'ziqorin", 'гриб']),
  ('🥑', ['avocado', 'avokado', 'авокадо']),
  (
    '🫘',
    [
      'bean',
      'loviya',
      'фасол',
      'mosh',
      'lentil',
      'yasmiq',
      'чечевиц',
      'chickpea',
      "no'xat",
      'нут',
    ],
  ),
  ('🍚', ['rice', 'guruch', 'рис']),
  ('🍛', ['plov', 'palov', 'плов', 'curry']),
  (
    '🍝',
    [
      'pasta',
      'spaghetti',
      'makaron',
      'макарон',
      "lag'mon",
      'lagman',
      'noodle',
      'лапш',
    ],
  ),
  (
    '🥟',
    ['manti', 'dumpling', 'chuchvara', 'barak', 'pelmeni', 'пельмен', 'манты'],
  ),
  ('🍢', ['shashlik', 'kebab', 'kabob', 'шашлык']),
  ('🥐', ['croissant', 'kruassan', 'круассан', 'somsa', 'samsa', 'самса']),
  ('🍞', ['bread', 'non', 'хлеб', 'toast', 'baton', 'lavash']),
  (
    '🥣',
    [
      'oat',
      'oats',
      'suli',
      'gerkules',
      'овсян',
      'porridge',
      "bo'tqa",
      'каша',
      'cereal',
      'granola',
      'muesli',
    ],
  ),
  ('🍕', ['pizza', 'пицц']),
  ('🍔', ['burger', 'hamburger']),
  ('🥪', ['sandwich', 'sendvich', 'бутерброд']),
  ('🍳', ['omelet', 'omlet', 'омлет', 'fried egg', 'quymoq']),
  ('🥚', ['egg', 'tuxum', 'яйц', 'яйко']),
  ('🍗', ['chicken', 'tovuq', 'куриц', 'курин', 'turkey', 'kurka', 'индейк']),
  (
    '🥩',
    [
      'beef',
      'mol',
      'говяд',
      'lamb',
      "qo'y",
      'баран',
      'steak',
      "go'sht",
      'мяс',
      'meat',
      'veal',
      'buzoq',
    ],
  ),
  ('🥓', ['bacon', 'бекон', 'pork', 'свин']),
  ('🌭', ['sausage', 'kolbasa', 'колбас', 'sosiska', 'сосис', 'hot dog']),
  ('🦐', ['shrimp', 'krevetka', 'кревет', 'prawn']),
  (
    '🐟',
    [
      'fish',
      'baliq',
      'рыб',
      'salmon',
      'losos',
      'лосос',
      'tuna',
      'тунец',
      'cod',
      'треск',
      'trout',
      'форел',
    ],
  ),
  ('🧀', ['cheese', 'pishloq', 'сыр', 'brynza', 'pishloqli']),
  ('🧈', ['butter', "sariyog'", 'масло сливоч']),
  (
    '🥛',
    [
      'milk',
      'sut',
      'молок',
      'kefir',
      'кефир',
      'yogurt',
      'yoghurt',
      'qatiq',
      'йогурт',
      'ayran',
      'tvorog',
      'творог',
      'сметан',
      'qaymoq',
    ],
  ),
  ('🍯', ['honey', 'asal', 'мёд', 'мед']),
  ('🍫', ['chocolate', 'shokolad', 'шоколад', 'cocoa', 'kakao']),
  ('🍪', ['cookie', 'pechenye', 'печень', 'biscuit']),
  ('🍰', ['cake', 'tort', 'торт', 'pirojniy', 'пирожн']),
  ('🍩', ['donut', 'doughnut', 'пончик']),
  ('🍦', ['ice cream', 'muzqaymoq', 'мороженое']),
  ('🥜', ['peanut', "yeryong'oq", 'арахис']),
  (
    '🌰',
    [
      'walnut',
      'almond',
      'hazelnut',
      'cashew',
      'pistachio',
      "yong'oq",
      'bodom',
      'pista',
      'фундук',
      'орех',
      'миндал',
      'фисташ',
      'кешью',
    ],
  ),
  ('🫒', ['olive', 'zaytun', 'олив', 'маслин']),
  ('🍉', ['watermelon', 'tarvuz', 'арбуз']),
  ('🍈', ['melon', 'qovun', 'дын']),
  ('🍌', ['banana', 'banan', 'банан']),
  ('🍍', ['pineapple', 'ananas', 'ананас']),
  ('🥭', ['mango', 'манго']),
  (
    '🍊',
    ['orange', 'apelsin', 'апельсин', 'mandarin', 'мандарин', 'tangerine'],
  ),
  ('🍋', ['lemon', 'limon', 'лимон', 'lime']),
  ('🍇', ['grape', 'uzum', 'виноград', 'raisin', 'mayiz', 'изюм']),
  ('🍓', ['strawberr', 'qulupnay', 'клубник', 'земляник']),
  ('🫐', ['blueberr', 'черник', 'голубик', 'smorodina', 'смородин', 'currant']),
  ('🍒', ['cherry', 'cherries', 'olcha', 'gilos', 'вишн', 'черешн']),
  (
    '🍑',
    [
      'peach',
      'shaftoli',
      'персик',
      'apricot',
      "o'rik",
      'урюк',
      'абрикос',
      'kuraga',
      'курага',
    ],
  ),
  ('🍐', ['pear', 'nok', 'груш']),
  ('🥝', ['kiwi', 'киви']),
  ('🥥', ['coconut', 'kokos', 'кокос']),
  ('🍎', ['apple', 'olma', 'яблок', 'pomegranate', 'anor', 'гранат']),
  ('💧', ['water', 'suv', 'вода']),
];

String _normalized(String text) => text
    .toLowerCase()
    .replaceAll(RegExp('[‘’ʻʼ`´]'), "'")
    .replaceAll(RegExp(r"[^\p{L}\p{N}' ]+", unicode: true), ' ');

final _stemPatterns = <(String, List<RegExp>)>[
  for (final (emoji, stems) in _foodEmoji)
    (
      emoji,
      [
        for (final stem in stems)
          // Short stems ("non", "mol", "sut") must be the whole word (with an
          // optional Uzbek suffix), so "nonfat" or "molasses" do not match.
          stem.length <= 3
              ? RegExp(' ${RegExp.escape(stem)}(i|li|lar|s)?[ \']')
              : RegExp(' ${RegExp.escape(stem)}'),
      ],
    ),
];

/// Emoji for a known food, or `null` (then the category icon is used).
/// Matches word beginnings, so "tomatoes" -> 🍅 but "salmon" never
/// matches "non".
String? foodEmoji(FoodNutrition food) {
  final text = ' ${_normalized('${food.localName ?? ''} ${food.name}')} ';
  for (final (emoji, patterns) in _stemPatterns) {
    if (patterns.any((pattern) => pattern.hasMatch(text))) return emoji;
  }
  return null;
}

/// Softly tinted tile representing a food: an exact emoji when the food is
/// recognised, otherwise its category line icon.
class FoodThumbnail extends StatelessWidget {
  const FoodThumbnail({
    super.key,
    required this.icon,
    this.size = 44,
    this.emoji,
  });

  /// Picks the emoji and icon for [food].
  FoodThumbnail.forFood(
    FoodNutrition food, {
    super.key,
    String? region,
    this.size = 44,
  }) : icon = foodCategoryIcon(food, region: region),
       emoji = foodEmoji(food);

  final IconData icon;
  final double size;
  final String? emoji;

  @override
  Widget build(BuildContext context) {
    final emoji = this.emoji;
    if (emoji == null) {
      return AppIconTile.tinted(
        icon: icon,
        size: size,
        accent: foodCategoryColor(icon),
      );
    }
    final accent = foodCategoryColor(icon);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      key: const Key('food-emoji'),
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: dark ? .16 : .09),
        borderRadius: BorderRadius.circular(
          size >= 44 ? AppRadius.md : AppRadius.sm,
        ),
        border: Border.all(color: accent.withValues(alpha: dark ? .22 : .14)),
      ),
      child: Text(
        emoji,
        style: TextStyle(fontSize: size * .5, height: 1.1),
        textScaler: TextScaler.noScaling,
      ),
    );
  }
}
