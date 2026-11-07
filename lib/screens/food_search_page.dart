import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/food_nutrition.dart';
import '../widgets/food_portion_sheet.dart';
import '../services/food_data_service.dart';
import '../services/search_history_store.dart';
import '../widgets/search_history_panel.dart';
import '../data/uzbek_food_catalog.dart';
import 'custom_food_page.dart';

class FoodSearchPage extends StatefulWidget {
  const FoodSearchPage({super.key, required this.service});

  final FoodDataService service;

  @override
  State<FoodSearchPage> createState() => _FoodSearchPageState();
}

class _FoodSearchPageState extends State<FoodSearchPage> {
  final _query = TextEditingController();
  List<FoodNutrition> _results = const [];
  bool _loading = false;
  int _searchId = 0;
  String? _error;
  String? _hint;
  String? _completedQuery;
  int? _nextPage;
  bool _loadingMore = false;

  Future<void> _loadMore() async {
    final query = _completedQuery;
    final page = _nextPage;
    if (query == null || page == null || _loadingMore) return;
    final requestId = _searchId;
    setState(() => _loadingMore = true);
    try {
      final result = await widget.service.searchAdditionalPage(query, languageCode: Localizations.localeOf(context).languageCode, page: page);
      if (!mounted || requestId != _searchId) return;
      final seen = _results.map((food) => '${food.dataSource}:${food.fdcId}').toSet();
      setState(() {
        _results = [..._results, ...result.foods.where((food) => seen.add('${food.dataSource}:${food.fdcId}'))];
        _nextPage = result.nextPage;
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted || requestId != _searchId) return;
      setState(() => _loadingMore = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('Mahsulotlarni yuklab bo‘lmadi. Qayta urinib ko‘ring.'))));
    }
  }

  @override
  void initState() {
    super.initState();
    SearchHistoryStore.shared.load();
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    FocusScope.of(context).unfocus();
    final text = _query.text.trim();
    final searchId = ++_searchId;
    if (text.length < 2) {
      setState(() {
        _loading = false;
        _results = const [];
        _hint = null;
        _error = context.tr('Kamida 2 ta belgi yozing.');
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _hint = null;
      _results = searchUzbekFoods(text, languageCode: Localizations.localeOf(context).languageCode);
      _nextPage = null;
      _loadingMore = false;
    });

    try {
      final results = await widget.service.search(
        text,
        languageCode: Localizations.localeOf(context).languageCode,
      );
      if (!mounted || searchId != _searchId) return;
      SearchHistoryStore.shared.addSuccessful(
        text,
        results.expand(
          (food) => [food.name, if (food.localName != null) food.localName!],
        ),
      );
      setState(() {
        _results = results;
        _completedQuery = text;
        _nextPage = results.any((food) => food.dataSource == 'FatSecret') ? 1 : null;
        _loading = false;
        if (results.isEmpty) {
          _error = context.tr(
            'Ovqat topilmadi. Boshqa nom bilan yozing (masalan: tovuq, olma, guruch, non).',
          );
        } else {
          _hint = context.tr(
            'Qiymatlar mahsulotda ko‘rsatilgan 100 g yoki 100 ml uchun.',
          );
        }
      });
    } catch (error) {
      if (!mounted || searchId != _searchId) return;
      setState(() {
        _loading = false;
        _error = context.tr(error.toString());
      });
    }
  }

  Future<void> _select(FoodNutrition food) async {
    final grams = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => FoodPortionSheet(
        food: food,
        title: food.displayNameFor(
          Localizations.localeOf(context).languageCode,
        ),
        subtitle: context.tr('Oziq qiymati 100 {unit} uchun', {'unit': context.tr(food.basisUnit)}),
      ),
    );
    if (grams == null || !mounted) return;
    await Future<void>.delayed(Duration.zero);
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    Navigator.pop(context, food.forGrams(grams, localName: food.localName));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('Ovqat qidirish')), actions: [
        IconButton(tooltip: context.tr('Yorliqdan mahsulot qo‘shish'), icon: const Icon(Icons.add), onPressed: () async {
          final food = await Navigator.push<FoodNutrition>(context, MaterialPageRoute(builder: (_) => const CustomFoodPage()));
          if (food != null && mounted) { await _select(food); }
        }),
      ]),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: SearchBar(
              controller: _query,
              onChanged: (_) {
                if (_query.text.trim().isEmpty) {
                  ++_searchId;
                  setState(() {
                    _loading = false;
                    _error = null;
                    _hint = null;
                    _results = const [];
                  });
                } else {
                  setState(() {});
                }
              },
              hintText: context.tr('Masalan: osh, somsa, tovuq, olma...'),
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _search(),
              trailing: [
                if (_query.text.isNotEmpty)
                  IconButton(
                    tooltip: context.tr('Tozalash'),
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () {
                      _query.clear();
                      ++_searchId;
                      setState(() {
                        _loading = false;
                        _error = null;
                        _hint = null;
                        _results = const [];
                      });
                    },
                  ),
                IconButton(
                  onPressed: _loading ? null : _search,
                  icon: const Icon(Icons.search),
                ),
              ],
            ),
          ),
          if (_loading) const LinearProgressIndicator(),
          if (_hint != null && _error == null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                _hint!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 13,
                ),
              ),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(_error!, textAlign: TextAlign.center),
            ),
          Expanded(
            child: _query.text.trim().isEmpty
                ? SearchHistoryPanel(
                    onSelected: (query) {
                      _query.text = query;
                      _query.selection = TextSelection.collapsed(
                        offset: query.length,
                      );
                      _search();
                    },
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: _results.length + (_nextPage == null ? 0 : 1),
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      if (index == _results.length) {
                        return TextButton(onPressed: _loadingMore ? null : _loadMore, child: Text(context.tr(_loadingMore ? 'Yuklanmoqda...' : 'Yana ko‘rsatish')));
                      }
                      final food = _results[index];
                      return Card(
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          title: Text(
                            food.displayNameFor(
                              Localizations.localeOf(context).languageCode,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            food.hasMissingCoreNutrients
                                ? context.tr(
                                    'Asosiy oziq qiymatlari to‘liq emas. Boshqa yozuvni tanlang.',
                                  )
                                : '100 ${context.tr(food.basisUnit)}: ${food.calories.round()} ${context.tr('kcal')} · '
                                      '${context.tr('Oqsil')} ${food.protein.toStringAsFixed(1)} ${context.tr('g')} · '
                                      '${context.tr('Uglevod')} ${food.carbohydrates.toStringAsFixed(1)} ${context.tr('g')} · '
                                      '${context.tr('Yog‘')} ${food.fat.toStringAsFixed(1)} ${context.tr('g')} · '
                                      '${context.tr('Suv')} ${food.hasWaterData ? food.water.toStringAsFixed(1) : '—'} ${context.tr('g')}',
                          ),
                          isThreeLine: true,
                          trailing: const Icon(Icons.add_circle_outline),
                          onTap: () => _select(food),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
