import '../theme/app_theme.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import '../widgets/food_portion_sheet.dart';

import '../data/uzbek_food_catalog.dart';
import '../l10n/app_localizations.dart';
import '../models/food_nutrition.dart';
import '../services/food_data_service.dart';
import '../services/search_history_store.dart';
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
  static const _green = Color(0xFF13B957);
  static const _navy = Color(0xFF10223C);
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
      final result = await _foodDataService.searchAdditionalPage(query, languageCode: Localizations.localeOf(context).languageCode, page: page);
      if (!mounted || query != _query.trim()) return;
      final ids = {..._globalFoods.map((f) => '${f.dataSource}:${f.fdcId}'), ..._dishes.map((d) => '${d.nutrition.dataSource}:${d.nutrition.fdcId}')};
      setState(() {
        _globalFoods = [..._globalFoods, ...result.foods.where((f) => ids.add('${f.dataSource}:${f.fdcId}'))];
        _nextPage = result.nextPage;
        _isSearching = false;
      });
    } catch (_) {
      if (!mounted || query != _query.trim()) return;
      setState(() { _isSearching = false; _searchError = context.tr('Mahsulotlarni yuklab bo‘lmadi. Qayta urinib ko‘ring.'); });
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
        _nextPage = foods.any((food) => food.dataSource == 'FatSecret') ? 1 : null;
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
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return const [];
    final candidates = uzbekDishesForMeal(widget.meal.name);
    return candidates
        .where((dish) {
          final text =
              '${dish.nameUz} ${dish.nameRu} ${dish.nameEn} ${dish.region}'
                  .toLowerCase();
          return query.split(RegExp(r'\s+')).every(text.contains);
        })
        .toList(growable: false);
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
      subtitle: context.tr('Oziq qiymati 100 {unit} uchun', {'unit': context.tr(food.basisUnit)}),
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

  @override
  Widget build(BuildContext context) {
    final dishes = _dishes;
    final languageCode = Localizations.localeOf(context).languageCode;
    final totalResults = dishes.length + _globalFoods.length;
    return Scaffold(
      backgroundColor: context.appColor(Color(0xFFF5FAF7), surface: true),
      appBar: AppBar(
        actions: [IconButton(tooltip: context.tr('Yorliqdan mahsulot qo‘shish'), icon: const Icon(Icons.add), onPressed: () async {
          final food = await Navigator.push<FoodNutrition>(context, MaterialPageRoute(builder: (_) => const CustomFoodPage()));
          if (food != null && mounted) { await _chooseGlobal(food); }
        })],
        backgroundColor: context.appColor(Color(0xFFF5FAF7), surface: true),
        title: Text(
          widget.meal.localizedTitle(context),
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 14),
            child: TextField(
              controller: _search,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: context.tr('Taom yoki mahsulotni qidiring'),
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          _search.clear();
                          _onSearchChanged('');
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
                filled: true,
                fillColor: context.appColor(Colors.white, surface: true),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          if (_query.trim().isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Text(
                    context.tr('Qidiruv natijalari'),
                    style: TextStyle(
                      color: context.appColor(_navy, surface: false),
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '$totalResults',
                    style: TextStyle(
                      color: _green,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
          Expanded(
            child: _query.trim().isEmpty
                ? SearchHistoryPanel(
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
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                    children: [
                      for (final dish in dishes) ...[
                        _FoodResultCard(
                          food: dish.nutrition,
                          title: dish.localizedName(languageCode),
                          subtitle:
                              '${dish.localizedRegion(languageCode)} · 100 ${context.tr(dish.nutrition.basisUnit)}',
                          icon: Icons.rice_bowl_rounded,
                          onTap: () => _choose(dish),
                        ),
                        const SizedBox(height: 9),
                      ],
                      for (final food in _globalFoods) ...[
                        _FoodResultCard(
                          food: food,
                          title: food.displayNameFor(languageCode),
                          subtitle: context.tr('Oziq qiymati 100 {unit} uchun', {'unit': context.tr(food.basisUnit)}),
                          icon: Icons.eco_rounded,
                          onTap: () => _chooseGlobal(food),
                        ),
                        const SizedBox(height: 9),
                      ],
                      if (_isSearching)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                            child: CircularProgressIndicator(color: _green),
                          ),
                        ),
                      if (!_isSearching && _nextPage != null)
                        TextButton(onPressed: _loadMore, child: Text(context.tr('Yana ko‘rsatish'))),
                      if (_searchError != null && totalResults > 0)
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(
                            _searchError!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: context.appColor(
                                Color(0xFFB54747),
                                surface: false,
                              ),
                            ),
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
    required this.icon,
    required this.onTap,
  });

  final FoodNutrition food;
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            children: [
              Container(
                width: 47,
                height: 47,
                decoration: BoxDecoration(
                  color: context.appColor(Color(0xFFE9F8EF), surface: true),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(icon, color: Theme.of(context).colorScheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: context.appColor(
                          _NationalFoodPickerPageState._navy,
                          surface: false,
                        ),
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      food.productType == null
                          ? subtitle
                          : '$subtitle · ${food.productType}',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 7),
                    if (showsDetailedCompositionInPicker(food) &&
                        food.ingredients != null) ...[
                      Text(
                        '${context.tr('Tarkibi')}: ${food.ingredients}',
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 11,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 7),
                    ],
                    if (showsDetailedCompositionInPicker(food) &&
                        food.labelDetails != null) ...[
                      Text(
                        food.labelDetails!,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 11,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 7),
                    ],
                    if (food.missingNutrients.isNotEmpty)
                      Text(
                        context.tr(
                          'Asosiy oziq qiymatlari to‘liq emas. Boshqa yozuvni tanlang.',
                        ),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          _Value(
                            '${food.calories.round()} ${context.tr('kcal')}',
                          ),
                          _Value(
                            '${context.tr('Oqsil')} ${food.protein.toStringAsFixed(1)} ${context.tr('g')}',
                          ),
                          _Value(
                            '${context.tr('Uglevod')} ${food.carbohydrates.toStringAsFixed(1)} ${context.tr('g')}',
                          ),
                          _Value(
                            '${context.tr('Yog‘')} ${food.fat.toStringAsFixed(1)} ${context.tr('g')}',
                          ),
                          _Value(
                            '${context.tr('Kletchatka')} ${food.fiber.toStringAsFixed(1)} ${context.tr('g')}',
                          ),
                          if (food.sodiumMg > 0)
                            _Value(
                              '${context.tr('Natriy')} ${food.sodiumMg.round()} mg',
                            ),
                          if (food.potassiumMg > 0)
                            _Value(
                              '${context.tr('Kaliy')} ${food.potassiumMg.round()} mg',
                            ),
                          if (food.ironMg > 0)
                            _Value(
                              '${context.tr('Temir')} ${food.ironMg.toStringAsFixed(1)} mg',
                            ),
                          if (food.calciumMg > 0)
                            _Value(
                              '${context.tr('Kalsiy')} ${food.calciumMg.round()} mg',
                            ),
                          if (food.cholesterolMg > 0)
                            _Value(
                              '${context.tr('Xolesterin')} ${food.cholesterolMg.round()} mg',
                            ),
                          if (food.phosphorusMg > 0)
                            _Value(
                              '${context.tr('Fosfor')} ${food.phosphorusMg.round()} mg',
                            ),
                          if (food.magnesiumMg > 0)
                            _Value(
                              '${context.tr('Magniy')} ${food.magnesiumMg.round()} mg',
                            ),
                          if (food.vitaminEMg > 0)
                            _Value(
                              '${context.tr('Vitamin E')} ${food.vitaminEMg.round()} mg',
                            ),
                          if (food.zincMg > 0)
                            _Value(
                              '${context.tr('Rux')} ${food.zincMg.round()} mg',
                            ),
                          if (food.vitaminDMcg > 0)
                            _Value(
                              '${context.tr('Vitamin D')} ${food.vitaminDMcg.round()} mcg',
                            ),
                          if (food.vitaminK2Mcg > 0)
                            _Value(
                              '${context.tr('Vitamin K2')} ${food.vitaminK2Mcg.round()} mcg',
                            ),
                        ],
                      ),
                  ],
                ),
              ),
              Icon(
                Icons.add_circle_rounded,
                color: Theme.of(context).colorScheme.primary,
                size: 29,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Value extends StatelessWidget {
  const _Value(this.value);

  final String value;

  @override
  Widget build(BuildContext context) {
    return Text(
      value,
      style: TextStyle(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        fontSize: 10,
        fontWeight: FontWeight.w700,
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
