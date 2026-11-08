import 'dart:async';

import 'package:flutter/material.dart';
import '../widgets/food_portion_sheet.dart';

import '../data/uzbek_food_catalog.dart';
import '../l10n/app_localizations.dart';
import '../models/food_nutrition.dart';
import '../services/food_data_service.dart';
import '../services/search_history_store.dart';
import '../widgets/food_thumbnail.dart';
import '../widgets/search_history_panel.dart';
import 'meals_page.dart';
import 'custom_food_page.dart';

bool showsDetailedCompositionInPicker(FoodNutrition food) {
  final type = food.productType?.toUpperCase() ?? '';
  return type.contains('VITAMIN') ||
      type.contains('MINERAL') ||
      type.contains('OMEGA');
}

class NationalFoodPickerPage extends StatefulWidget {
  const NationalFoodPickerPage({
    super.key,
    required this.meal,
    this.foodDataService,
  });

  final MealType meal;
  final FoodDataService? foodDataService;

  @override
  State<NationalFoodPickerPage> createState() => _NationalFoodPickerPageState();
}

class _NationalFoodPickerPageState extends State<NationalFoodPickerPage> {
  static const _border = Color(0xFFE4E9EE);
  String? _category;
  final _search = TextEditingController();
  late final FoodDataService _foodDataService;
  Timer? _debounce;
  String _query = '';
  List<FoodNutrition> _globalFoods = const [];
  bool _isSearching = false;
  String? _searchError;
  int? _nextPage;

  Future<void> _loadMore() async {
    final page = _nextPage;
    final query = _query.trim();
    if (page == null || _isSearching) return;
    setState(() => _isSearching = true);
    try {
      final result = await _foodDataService.searchAdditionalPage(
        query,
        languageCode: Localizations.localeOf(context).languageCode,
        page: page,
      );
      if (!mounted || query != _query.trim()) return;
      final ids = {
        ..._globalFoods.map((f) => '${f.dataSource}:${f.fdcId}'),
        ..._dishes.map((d) => '${d.nutrition.dataSource}:${d.nutrition.fdcId}'),
      };
      setState(() {
        _globalFoods = [
          ..._globalFoods,
          ...result.foods.where((f) => ids.add('${f.dataSource}:${f.fdcId}')),
        ];
        _nextPage = result.nextPage;
        _isSearching = false;
      });
    } catch (_) {
      if (!mounted || query != _query.trim()) return;
      setState(() {
        _isSearching = false;
        _searchError = context.tr(
          'Mahsulotlarni yuklab bo‘lmadi. Qayta urinib ko‘ring.',
        );
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _foodDataService = widget.foodDataService ?? FoodDataService();
    SearchHistoryStore.shared.load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    setState(() {
      _query = value;
      _nextPage = null;
      _searchError = null;
      if (value.trim().length < 2) {
        _globalFoods = const [];
        _isSearching = false;
      } else {
        _isSearching = true;
      }
    });
    if (value.trim().length < 2) return;
    _debounce = Timer(const Duration(milliseconds: 450), () {
      _searchGlobal(value.trim());
    });
  }

  Future<void> _searchGlobal(String query) async {
    final languageCode = Localizations.localeOf(context).languageCode;
    try {
      final foods = await _foodDataService.search(
        query,
        languageCode: languageCode,
      );
      if (!mounted || query != _query.trim()) return;
      SearchHistoryStore.shared.addSuccessful(query, [
        for (final dish in _dishes) ...[dish.nameUz, dish.nameRu, dish.nameEn],
        for (final food in foods) ...[
          food.name,
          if (food.localName != null) food.localName!,
        ],
      ]);
      final localIds = _dishes.map((dish) => dish.nutrition.fdcId).toSet();
      final uniqueNames = <String>{};
      setState(() {
        _nextPage = foods.any((food) => food.dataSource == 'FatSecret')
            ? 1
            : null;
        _globalFoods = foods
            .where((food) => !localIds.contains(food.fdcId))
            // USDA ayrim bir xil yozuvlarni turli datasetlardan qaytaradi.
            // Tavsifi bir xil bo‘lsa, foydalanuvchiga faqat bittasini ko‘rsatamiz.
            .where(
              (food) => uniqueNames.add(
                food.displayNameFor(languageCode).trim().toLowerCase(),
              ),
            )
            .toList(growable: false);
        _isSearching = false;
      });
    } on FoodDataException catch (error) {
      if (!mounted || query != _query.trim()) return;
      setState(() {
        _globalFoods = const [];
        _isSearching = false;
        _searchError = error.message;
      });
    } catch (_) {
      if (!mounted || query != _query.trim()) return;
      setState(() {
        _globalFoods = const [];
        _isSearching = false;
        _searchError = context.tr(
          'Mahsulotlarni yuklab bo‘lmadi. Qayta urinib ko‘ring.',
        );
      });
    }
  }

  List<UzbekDish> get _dishes {
    final query = normalizeFoodText(_query);
    if (query.isEmpty) return const [];
    final words = query.split(' ');
    final ranked = <(int, int, UzbekDish)>[];
    final candidates = uzbekDishesForMeal(widget.meal.name);
    for (var i = 0; i < candidates.length; i++) {
      final dish = candidates[i];
      final names = [
        dish.nameUz,
        dish.nameRu,
        dish.nameEn,
      ].map(normalizeFoodText).toList(growable: false);
      final text = '${names.join(' ')} ${normalizeFoodText(dish.region)}';
      if (!words.every(text.contains)) continue;
      // 0: aynan mos, 1: nom so'rov bilan boshlanadi, 2: so'z boshida,
      // 3: nom ichida, 4: faqat kategoriya/hudud bo'yicha.
      final score = names.any((name) => name == query)
          ? 0
          : names.any((name) => name.startsWith(query))
          ? 1
          : names.any(
              (name) => name.contains(' $query') || name.contains('($query'),
            )
          ? 2
          : names.any((name) => words.every(name.contains))
          ? 3
          : 4;
      ranked.add((score, i, dish));
    }
    ranked.sort((a, b) => a.$1 != b.$1 ? a.$1 - b.$1 : a.$2 - b.$2);
    return [for (final entry in ranked) entry.$3];
  }

  Future<void> _choose(UzbekDish dish) async {
    await _chooseFood(
      dish.nutrition,
      dish.localizedName(Localizations.localeOf(context).languageCode),
      storedName: dish.localizedName(
        Localizations.localeOf(context).languageCode,
      ),
      subtitle:
          '${context.tr('Hudud')}: ${dish.localizedRegion(Localizations.localeOf(context).languageCode)}',
    );
  }

  Future<void> _chooseGlobal(FoodNutrition food) async {
    final languageCode = Localizations.localeOf(context).languageCode;
    await _chooseFood(
      food,
      food.displayNameFor(languageCode),
      storedName: food.localName,
      subtitle: context.tr('Oziq qiymati 100 {unit} uchun', {
        'unit': context.tr(food.basisUnit),
      }),
    );
  }

  Future<void> _chooseFood(
    FoodNutrition food,
    String displayName, {
    String? storedName,
    required String subtitle,
  }) async {
    final grams = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) =>
          FoodPortionSheet(food: food, title: displayName, subtitle: subtitle),
    );
    if (grams == null || !mounted) return;
    // Modal route va uning InheritedWidget dependentlari to‘liq deactivation
    // bosqichidan o‘tgachgina ota sahifani yopamiz.
    await Future<void>.delayed(Duration.zero);
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    Navigator.pop(
      context,
      food.forGrams(grams, localName: storedName ?? displayName),
    );
  }

  void _openCategory(String region) {
    _debounce?.cancel();
    FocusScope.of(context).unfocus();
    _search.clear();
    setState(() {
      _category = region;
      _query = '';
      _globalFoods = const [];
      _nextPage = null;
      _searchError = null;
      _isSearching = false;
    });
  }

  void _closeCategory() => setState(() => _category = null);

  Widget _categories(BuildContext context, String languageCode) {
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.tr('Kategoriyalar'),
          style: TextStyle(
            color: colors.onSurface,
            fontSize: 17,
            fontWeight: FontWeight.w700,
            letterSpacing: -.2,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final category in kSearchCategories)
              Material(
                color: colors.surfaceContainerLowest,
                shape: StadiumBorder(
                  side: BorderSide(
                    color: dark ? colors.outlineVariant : _border,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  key: Key('category-${category.region}'),
                  onTap: () => _openCategory(category.region),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(5, 5, 14, 5),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ClipOval(
                          child: Image.asset(
                            category.asset,
                            width: 28,
                            height: 28,
                            fit: BoxFit.cover,
                            cacheWidth: 84,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          UzbekDish.localizeRegion(
                            category.region,
                            languageCode,
                          ),
                          style: TextStyle(
                            color: colors.onSurface,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final languageCode = Localizations.localeOf(context).languageCode;
    final category = _category;
    final dishes = category == null
        ? _dishes
        : kUzbekDishes
              .where((dish) => dish.region == category)
              .toList(growable: false);
    final globalFoods = category == null
        ? _globalFoods
        : const <FoodNutrition>[];
    final totalResults = dishes.length + globalFoods.length;
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final showResults = category != null || _query.trim().isNotEmpty;
    final fieldBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: dark ? colors.outlineVariant : _border),
    );
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 4,
        title: Text(
          widget.meal.localizedTitle(context),
          style: TextStyle(
            color: colors.onSurface,
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: -.3,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: IconButton.filledTonal(
              tooltip: context.tr('Yorliqdan mahsulot qo‘shish'),
              style: IconButton.styleFrom(
                backgroundColor: colors.primaryContainer,
                foregroundColor: colors.primary,
              ),
              icon: const Icon(Icons.add_rounded),
              onPressed: () async {
                final food = await Navigator.push<FoodNutrition>(
                  context,
                  MaterialPageRoute(builder: (_) => const CustomFoodPage()),
                );
                if (food != null && mounted) {
                  await _chooseGlobal(food);
                }
              },
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 6, 18, 14),
            child: TextField(
              controller: _search,
              onChanged: (value) {
                if (_category != null) _category = null;
                _onSearchChanged(value);
              },
              textInputAction: TextInputAction.search,
              style: TextStyle(color: colors.onSurface, fontSize: 16),
              decoration: InputDecoration(
                hintText: context.tr('Taom yoki mahsulotni qidiring'),
                hintStyle: TextStyle(
                  color: colors.onSurfaceVariant.withValues(alpha: .8),
                  fontSize: 15.5,
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: colors.onSurfaceVariant,
                ),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: MaterialLocalizations.of(
                          context,
                        ).deleteButtonTooltip,
                        onPressed: () {
                          _search.clear();
                          _onSearchChanged('');
                        },
                        icon: Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: colors.onSurfaceVariant.withValues(
                              alpha: .18,
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.close_rounded,
                            size: 14,
                            color: colors.onSurface,
                          ),
                        ),
                      ),
                filled: true,
                fillColor: colors.surfaceContainerLowest,
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
                border: fieldBorder,
                enabledBorder: fieldBorder,
                focusedBorder: fieldBorder.copyWith(
                  borderSide: BorderSide(color: colors.primary, width: 1.6),
                ),
              ),
            ),
          ),
          if (showResults) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 12, 0),
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      category == null
                          ? context.tr('Qidiruv natijalari')
                          : UzbekDish.localizeRegion(category, languageCode),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.onSurface,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -.2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: colors.primaryContainer,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$totalResults',
                      style: TextStyle(
                        color: colors.primary,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (category != null)
                    IconButton(
                      tooltip: context.tr('Toifani yopish'),
                      onPressed: _closeCategory,
                      visualDensity: VisualDensity.compact,
                      icon: Icon(
                        Icons.close_rounded,
                        size: 20,
                        color: colors.onSurfaceVariant,
                      ),
                    )
                  else if (_isSearching)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colors.primary,
                        ),
                      ),
                    )
                  else
                    const SizedBox(height: 40),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
          Expanded(
            child: !showResults
                ? SearchHistoryPanel(
                    header: _categories(context, languageCode),
                    onSelected: (query) {
                      _search.text = query;
                      _search.selection = TextSelection.collapsed(
                        offset: query.length,
                      );
                      _onSearchChanged(query);
                    },
                  )
                : totalResults == 0 && !_isSearching
                ? _SearchEmptyState(
                    title: context.tr('Mahsulot topilmadi'),
                    subtitle:
                        _searchError ??
                        context.tr('Boshqa nom bilan qayta qidiring'),
                  )
                : ListView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                    children: [
                      for (final dish in dishes) ...[
                        _FoodResultCard(
                          food: dish.nutrition,
                          title: dish.localizedName(languageCode),
                          subtitle: dish.region == 'Umumiy'
                              ? '100 ${context.tr(dish.nutrition.basisUnit)}'
                              : '${dish.localizedRegion(languageCode)} · 100 ${context.tr(dish.nutrition.basisUnit)}',
                          asset: foodThumbnailAsset(
                            dish.nutrition,
                            region: dish.region,
                          ),
                          onTap: () => _choose(dish),
                        ),
                        const SizedBox(height: 10),
                      ],
                      for (final food in globalFoods) ...[
                        _FoodResultCard(
                          food: food,
                          title: food.displayNameFor(languageCode),
                          subtitle:
                              '${context.tr('Internet bazasi')} · 100 ${context.tr(food.basisUnit)}',
                          asset: foodThumbnailAsset(food),
                          fallbackIcon: Icons.public_rounded,
                          onTap: () => _chooseGlobal(food),
                        ),
                        const SizedBox(height: 10),
                      ],
                      if (_isSearching && totalResults == 0)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 32),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: colors.primary,
                            ),
                          ),
                        ),
                      if (!_isSearching && _nextPage != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: OutlinedButton.icon(
                            onPressed: _loadMore,
                            icon: const Icon(Icons.expand_more_rounded),
                            label: Text(context.tr('Yana ko‘rsatish')),
                          ),
                        ),
                      if (_searchError != null && totalResults > 0)
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(
                            _searchError!,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: colors.error),
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _FoodResultCard extends StatelessWidget {
  const _FoodResultCard({
    required this.food,
    required this.title,
    required this.subtitle,
    required this.asset,
    required this.onTap,
    this.fallbackIcon = Icons.restaurant_rounded,
  });

  final FoodNutrition food;
  final String title;
  final String subtitle;
  final String? asset;
  final IconData fallbackIcon;
  final VoidCallback onTap;

  static const _protein = Color(0xFF4F5FD8);
  static const _carbs = Color(0xFFE08A1E);
  static const _fat = Color(0xFFE5536B);

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final radius = BorderRadius.circular(18);
    String g(double value) => '${value.toStringAsFixed(1)} ${context.tr('g')}';
    Widget stat(String value, String label, Color color) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.fade,
            softWrap: false,
            style: TextStyle(
              color: colors.onSurface,
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  context.tr(label),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    return Material(
      color: colors.surfaceContainerLowest,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(
              color: dark ? colors.outlineVariant : const Color(0xFFE4E9EE),
            ),
          ),
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              FoodThumbnail(asset: asset, fallbackIcon: fallbackIcon),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.onSurface,
                        fontSize: 15,
                        height: 1.2,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -.1,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (food.missingNutrients.isNotEmpty)
                      Text(
                        context.tr(
                          'Asosiy oziq qiymatlari to‘liq emas. Boshqa yozuvni tanlang.',
                        ),
                        style: TextStyle(
                          color: colors.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      )
                    else
                      Row(
                        children: [
                          stat(
                            '${food.calories.round()}',
                            'kcal',
                            colors.primary,
                          ),
                          stat(g(food.protein), 'Oqsil', _protein),
                          stat(g(food.carbohydrates), 'Uglevod', _carbs),
                          stat(g(food.fat), 'Yog‘', _fat),
                        ],
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: colors.primary,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.add_rounded,
                  color: colors.onPrimary,
                  size: 21,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchEmptyState extends StatelessWidget {
  const _SearchEmptyState({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 34),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.manage_search_rounded,
                color: Theme.of(context).colorScheme.primary,
                size: 38,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
