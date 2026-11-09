import 'dart:async';

import 'package:flutter/material.dart';
import '../widgets/food_portion_sheet.dart';

import '../data/uzbek_food_catalog.dart';
import '../l10n/app_localizations.dart';
import '../models/food_nutrition.dart';
import '../services/food_data_service.dart';
import '../services/search_history_store.dart';
import '../theme/app_theme.dart';
import '../widgets/app_ui.dart';
import '../widgets/food_thumbnail.dart';
import '../widgets/search_history_panel.dart';
import 'meals_page.dart';
import 'custom_food_page.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

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
    this.title,
  });

  final MealType meal;
  final FoodDataService? foodDataService;

  /// Overrides the meal name in the app bar (e.g. when picking ingredients).
  final String? title;

  @override
  State<NationalFoodPickerPage> createState() => _NationalFoodPickerPageState();
}

class _NationalFoodPickerPageState extends State<NationalFoodPickerPage> {
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
      builder: (_) => FoodPortionSheet(
        food: food,
        title: displayName,
        subtitle: subtitle,
        actionLabel: 'Saqlash',
        actionIcon: LucideIcons.bookmarkPlus,
      ),
    );
    if (grams == null || !mounted) return;
    // Qidiruv tarixiga yozilgan so'rov emas, tanlangan mahsulot nomi tushadi.
    SearchHistoryStore.shared.add(displayName);
    final key = _foodKey(food);
    final portion = food.forGrams(grams, localName: storedName ?? displayName);
    setState(() {
      _basket.add(portion);
      _basketKeys.add(key);
      _basketCounts[key] = (_basketCounts[key] ?? 0) + 1;
    });
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        content: Text(
          context.tr('{name} saqlandi', {'name': displayName}),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  /// Saqlangan, lekin hali menyuga qo'shilmagan mahsulotlar.
  final List<FoodNutrition> _basket = [];
  final List<String> _basketKeys = [];
  final Map<String, int> _basketCounts = {};
  bool _finishing = false;

  String _foodKey(FoodNutrition food) => '${food.dataSource}:${food.fdcId}';

  double get _basketCalories =>
      _basket.fold(0, (total, food) => total + food.calories);

  void _removeFromBasket(int index) {
    setState(() {
      _basket.removeAt(index);
      final key = _basketKeys.removeAt(index);
      final left = (_basketCounts[key] ?? 1) - 1;
      if (left <= 0) {
        _basketCounts.remove(key);
      } else {
        _basketCounts[key] = left;
      }
    });
  }

  Future<void> _finish() async {
    if (_basket.isEmpty) return;
    setState(() => _finishing = true);
    // Modal route va uning InheritedWidget dependentlari to‘liq deactivation
    // bosqichidan o‘tgachgina ota sahifani yopamiz.
    await Future<void>.delayed(Duration.zero);
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    Navigator.pop(context, List<FoodNutrition>.unmodifiable(_basket));
  }

  Future<void> _confirmLeave() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('Tanlanganlar qo‘shilmadi')),
        content: Text(
          context.tr(
            'Saqlangan {count} ta mahsulot menyuga qo‘shilmaydi. Chiqasizmi?',
            {'count': _basket.length},
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.tr('Qolish')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(context.tr('Chiqib ketish')),
          ),
        ],
      ),
    );
    if (leave != true || !mounted) return;
    setState(() => _finishing = true);
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) Navigator.pop(context);
  }

  Future<void> _showBasket() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, refresh) {
          final colors = Theme.of(sheetContext).colorScheme;
          final languageCode = Localizations.localeOf(
            sheetContext,
          ).languageCode;
          return SafeArea(
            top: false,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(sheetContext).height * .7,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                    child: Text(
                      context.tr('Saqlanganlar'),
                      style: TextStyle(
                        color: colors.onSurface,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                      itemCount: _basket.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (_, index) {
                        final food = _basket[index];
                        return ListTile(
                          leading: FoodThumbnail(
                            icon: foodCategoryIcon(food),
                            size: 40,
                          ),
                          title: Text(
                            food.displayNameFor(languageCode),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            '${food.grams.round()} ${context.tr(food.basisUnit)} · ${food.calories.round()} ${context.tr('kcal')}',
                          ),
                          trailing: IconButton(
                            tooltip: MaterialLocalizations.of(
                              context,
                            ).deleteButtonTooltip,
                            icon: Icon(LucideIcons.trash2, color: colors.error),
                            onPressed: () {
                              _removeFromBasket(index);
                              if (_basket.isEmpty) {
                                Navigator.pop(sheetContext);
                              } else {
                                refresh(() {});
                              }
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _basketBar(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceContainerLowest,
        border: Border(top: BorderSide(color: colors.outlineVariant)),
        boxShadow: dark
            ? null
            : const [
                BoxShadow(
                  color: Color(0x140F1B2D),
                  blurRadius: 20,
                  offset: Offset(0, -6),
                ),
              ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 16, 10),
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  key: const Key('basket-open'),
                  onTap: _showBasket,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 4,
                    ),
                    child: Row(
                      children: [
                        Badge.count(
                          count: _basket.length,
                          backgroundColor: colors.primary,
                          textColor: colors.onPrimary,
                          child: Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: colors.primaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              LucideIcons.shoppingBasket,
                              color: colors.primary,
                              size: 22,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                context.tr('{count} ta mahsulot', {
                                  'count': _basket.length,
                                }),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: colors.onSurface,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${_basketCalories.round()} ${context.tr('kcal')}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: colors.onSurfaceVariant,
                                  fontSize: 12.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton.icon(
                key: const Key('basket-add'),
                onPressed: _finish,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 48),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                ),
                icon: const Icon(LucideIcons.check, size: 20),
                label: Text(context.tr('Qo‘shish')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final languageCode = Localizations.localeOf(context).languageCode;
    final dishes = _dishes;
    final globalFoods = _globalFoods;
    final totalResults = dishes.length + globalFoods.length;
    final colors = Theme.of(context).colorScheme;
    final showResults = _query.trim().isNotEmpty;
    return PopScope(
      canPop: _basket.isEmpty || _finishing,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmLeave();
      },
      child: Scaffold(
        bottomNavigationBar: _basket.isEmpty ? null : _basketBar(context),
        appBar: AppBar(
          titleSpacing: 4,
          title: Text(
            widget.title ?? widget.meal.localizedTitle(context),
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
                icon: const Icon(LucideIcons.plus),
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
                onChanged: _onSearchChanged,
                textInputAction: TextInputAction.search,
                style: TextStyle(color: colors.onSurface, fontSize: 16),
                decoration: InputDecoration(
                  hintText: context.tr('Taom yoki mahsulotni qidiring'),
                  prefixIcon: const Icon(LucideIcons.search, size: 18),
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
                          icon: const Icon(LucideIcons.x, size: 18),
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
                        context.tr('Qidiruv natijalari'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.onSurface,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
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
                        color: colors.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(AppRadius.xs),
                      ),
                      child: Text(
                        '$totalResults',
                        style: TextStyle(
                          color: colors.onSurfaceVariant,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (_isSearching)
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
                            icon: foodCategoryIcon(
                              dish.nutrition,
                              region: dish.region,
                            ),
                            selected:
                                _basketCounts[_foodKey(dish.nutrition)] ?? 0,
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
                            icon: foodCategoryIcon(food),
                            selected: _basketCounts[_foodKey(food)] ?? 0,
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
                              icon: const Icon(LucideIcons.chevronDown),
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
    this.selected = 0,
  });

  /// Shu mahsulotdan nechta porsiya saqlangan.
  final int selected;

  final FoodNutrition food;
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
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
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 3),
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  context.tr(label),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    final isSelected = selected > 0;
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
      child: Row(
        children: [
          FoodThumbnail(icon: icon),
          const SizedBox(width: 14),
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
                    height: 1.25,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -.15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontSize: 12.5,
                  ),
                ),
                const SizedBox(height: 10),
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
                        colors.onSurface,
                      ),
                      stat(g(food.protein), 'Oqsil', AppPalette.protein),
                      stat(g(food.carbohydrates), 'Uglevod', AppPalette.carbs),
                      stat(g(food.fat), 'Yog‘', AppPalette.fat),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Badge(
            isLabelVisible: selected > 1,
            label: Text('$selected'),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: isSelected
                    ? colors.primary
                    : colors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(
                  color: isSelected ? colors.primary : colors.outline,
                ),
              ),
              child: Icon(
                isSelected ? LucideIcons.check : LucideIcons.plus,
                color: isSelected ? colors.onPrimary : colors.onSurface,
                size: 18,
              ),
            ),
          ),
        ],
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
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 34),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppIconTile(icon: LucideIcons.searchX, size: 52),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.onSurfaceVariant,
                fontSize: 13.5,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
