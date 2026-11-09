import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../models/food_nutrition.dart';
import 'nutrition_facts.dart';

// Standard large-egg edible portions. Mixed dishes are deliberately excluded.
// Whole egg: https://foods.fatsecret.com/calories-nutrition/usda/egg-(whole)
// Fried: https://foods.fatsecret.com/calories-nutrition/usda/fried-egg
// White: https://foods.fatsecret.com/calories-nutrition/usda/egg-white
double? eggPieceGrams(FoodNutrition food) {
  const local = <int, double>{
    -1200: 50,
    -1201: 50,
    -1202: 50,
    -1203: 46,
    -1205: 50,
    -1206: 33,
  };
  if (local.containsKey(food.fdcId)) return local[food.fdcId];
  final name = food.name.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');
  const names = <String, double>{
    'egg, whole, raw, fresh': 50,
    'egg, whole, hard-boiled': 50,
    'egg, whole, cooked, hard-boiled': 50,
    'egg, whole, soft-boiled': 50,
    'egg, whole, fried': 46,
    'egg, whole, cooked, fried': 46,
    'egg, whole, poached': 50,
    'egg, whole, cooked, poached': 50,
    'egg white, cooked': 33,
    'egg, white, raw, fresh': 33,
    'egg (whole)': 50,
    'egg': 50,
    'boiled egg': 50,
    'fried egg': 46,
    'poached egg': 50,
    'egg white': 33,
    'cooked egg white': 33,
  };
  String normalize(String text) =>
      text.replaceAll(RegExp(r'[,-]'), ' ').replaceAll(RegExp(r'\s+'), ' ');
  for (final entry in names.entries) {
    if (normalize(entry.key) == normalize(name)) return entry.value;
  }
  return null;
}

/// Approximate edible weights: small, regular, large. Recipe weights vary.
List<double>? foodPieceSizes(FoodNutrition food) {
  final egg = eggPieceGrams(food);
  if (egg != null) return [egg * 38 / 50, egg * 44 / 50, egg];
  const dishes = <int, List<double>>{
    -1007: [40, 60, 80],
    -1009: [8, 12, 18],
    -1025: [20, 30, 45],
    -1026: [20, 35, 50],
    -1027: [60, 90, 120],
    -1028: [150, 200, 300],
    -1029: [60, 100, 140],
    -1030: [70, 120, 170],
    -1031: [150, 250, 350],
    -1032: [250, 400, 600],
    -1033: [150, 250, 350],
    -1035: [30, 50, 80],
    -1041: [10, 20, 30],
    -1044: [20, 35, 50],
  };
  if (dishes.containsKey(food.fdcId)) return dishes[food.fdcId];
  // Exact aliases exclude juices, purees, and mixed dishes.
  final name = food.name.toLowerCase().trim();
  final base = name.endsWith(', raw')
      ? name.substring(0, name.length - 5)
      : name;
  const produce = <String, List<double>>{
    'apple': [106, 138, 212],
    'apples': [106, 138, 212],
    'banana': [101, 118, 136],
    'bananas': [101, 118, 136],
    'pear': [148, 178, 230],
    'peach': [130, 150, 175],
    'nectarine': [129, 142, 156],
    'apricot': [25, 35, 45],
    'plum': [40, 66, 85],
    'orange': [96, 131, 184],
    'mandarin': [76, 88, 120],
    'kiwi': [50, 69, 90],
    'fig': [40, 50, 64],
    'persimmon': [100, 168, 230],
    'lemon': [58, 84, 108],
    'potato': [130, 170, 300],
    'carrot': [50, 61, 72],
    'onion': [70, 110, 150],
    'red onion': [70, 110, 150],
    'tomato': [91, 123, 182],
    'cucumber': [158, 201, 301],
    'bell pepper': [74, 119, 164],
  };
  return produce[base];
}

class FoodPortionSheet extends StatefulWidget {
  const FoodPortionSheet({
    super.key,
    required this.food,
    required this.title,
    required this.subtitle,
    this.actionLabel = 'Ovqatga qo\u2018shish',
    this.actionIcon = Icons.add_rounded,
  });

  final FoodNutrition food;
  final String title;
  final String subtitle;

  /// Asosiy tugma matni (tarjima kaliti) va ikonkasi.
  final String actionLabel;
  final IconData actionIcon;

  @override
  State<FoodPortionSheet> createState() => _FoodPortionSheetState();
}

class _FoodPortionSheetState extends State<FoodPortionSheet> {
  late final TextEditingController _amount;
  late final List<double>? _sizes;
  int _size = 1;
  double? get _pieceGrams => _sizes?[_size];
  late bool _pieces;
  bool _showError = false;
  FoodServing? _sourceServing;

  @override
  void initState() {
    super.initState();
    _sizes = widget.food.basisUnit == 'g' && widget.food.servings.isEmpty
        ? foodPieceSizes(widget.food)
        : null;
    _pieces = _pieceGrams != null;
    _amount = TextEditingController(text: _pieces ? '1' : '100');
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  double? get _grams {
    final value = double.tryParse(_amount.text.replaceAll(',', '.'));
    if (value == null || !value.isFinite || value <= 0) return null;
    final grams =
        value * (_sourceServing?.amount ?? (_pieces ? _pieceGrams! : 1));
    return grams.isFinite && grams >= 1 && grams <= 5000 ? grams : null;
  }

  String _format(double value) =>
      value.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');

  void _changeUnit(bool pieces) {
    if (_pieces == pieces) return;
    final grams = _grams;
    setState(() {
      _pieces = pieces;
      _showError = false;
      _amount.text = grams == null
          ? (pieces ? '1' : '100')
          : _format(pieces ? grams / _pieceGrams! : grams);
    });
  }

  void _submit() {
    if (widget.food.hasMissingCoreNutrients) return;
    final grams = _grams;
    if (grams == null) {
      setState(() => _showError = true);
      return;
    }
    Navigator.pop(context, grams);
  }

  @override
  Widget build(BuildContext context) {
    final grams = _grams;
    final nutrition = grams == null ? null : widget.food.forGrams(grams);
    final colors = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          4,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                // Adashib ochilganda ovqat qo'shmasdan orqaga qaytish.
                IconButton(
                  key: const Key('portion-back'),
                  tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                  onPressed: () => Navigator.maybePop(context),
                  style: IconButton.styleFrom(
                    backgroundColor: colors.surfaceContainerHigh,
                    foregroundColor: colors.onSurface,
                    fixedSize: const Size(44, 44),
                  ),
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.title,
                    style: TextStyle(
                      color: colors.onSurface,
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              widget.subtitle,
              style: TextStyle(color: colors.onSurfaceVariant, height: 1.4),
            ),
            if (widget.food.servings.isNotEmpty) ...[
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                key: const Key('source-portion-unit'),
                initialValue: -1,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: context.tr('O‘lchov birligi'),
                ),
                items: [
                  DropdownMenuItem(
                    value: -1,
                    child: Text(context.tr(widget.food.basisUnit)),
                  ),
                  for (var i = 0; i < widget.food.servings.length; i++)
                    DropdownMenuItem(
                      value: i,
                      child: Text(
                        '${widget.food.servings[i].description} (${_format(widget.food.servings[i].amount)} ${context.tr(widget.food.basisUnit)})',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (index) {
                  if (index == null) return;
                  final previousAmount = _grams;
                  setState(() {
                    _sourceServing = index < 0
                        ? null
                        : widget.food.servings[index];
                    _amount.text = _format(
                      (previousAmount ?? 100) / (_sourceServing?.amount ?? 1),
                    );
                    _showError = false;
                  });
                },
              ),
            ],
            if (_pieceGrams != null) ...[
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                key: const Key('portion-unit'),
                initialValue: 1,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: context.tr('O‘lchov birligi'),
                ),
                items: [1, 2, 0, 3].map((unit) {
                  final label = context.tr(
                    ['Kichik dona', 'Dona', 'Katta dona', 'Gramm'][unit],
                  );
                  return DropdownMenuItem(
                    value: unit,
                    child: Text(
                      unit == 3
                          ? label
                          : '$label (≈ ${_format(_sizes![unit])} ${context.tr('g')})',
                    ),
                  );
                }).toList(),
                onChanged: (unit) {
                  if (unit == null) return;
                  final pieces = unit != 3;
                  if (pieces == _pieces) {
                    setState(() {
                      if (pieces) _size = unit;
                      _showError = false;
                    });
                  } else {
                    if (pieces) _size = unit;
                    _changeUnit(pieces);
                  }
                },
              ),
              const SizedBox(height: 8),
              Text(
                context.tr('Dona vazni taxminiy, yeyiladigan qism uchun.'),
                style: TextStyle(color: colors.onSurfaceVariant, height: 1.4),
              ),
            ],
            const SizedBox(height: 16),
            TextField(
              key: const Key('portion-amount'),
              controller: _amount,
              autofocus: false,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              onChanged: (_) => setState(() => _showError = false),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]')),
              ],
              decoration: InputDecoration(
                labelText: context.tr('Miqdori'),
                suffixText: _sourceServing != null
                    ? '×'
                    : context.tr(_pieces ? 'dona' : widget.food.basisUnit),
                errorText: _showError
                    ? context.tr('1–5000 {unit} oralig‘ida miqdor kiriting.', {
                        'unit': context.tr(widget.food.basisUnit),
                      })
                    : null,
              ),
            ),
            if (_pieceGrams != null &&
                nutrition != null &&
                !nutrition.missingNutrients.contains('calories')) ...[
              const SizedBox(height: 12),
              Text(
                '${_format(grams!)} ${context.tr('g')} · '
                '${nutrition.calories.toStringAsFixed(1)} ${context.tr('kcal')}',
                key: const Key('portion-preview'),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
            const SizedBox(height: 16),
            if (widget.food.hasMissingCoreNutrients) ...[
              Text(
                context.tr(
                  'Asosiy oziq qiymatlari to‘liq emas. Boshqa yozuvni tanlang.',
                ),
                style: TextStyle(color: colors.error),
              ),
              const SizedBox(height: 12),
            ],
            FilledButton.icon(
              onPressed: !widget.food.hasMissingCoreNutrients ? _submit : null,
              icon: Icon(widget.actionIcon),
              label: Text(context.tr(widget.actionLabel)),
              style: FilledButton.styleFrom(
                backgroundColor: colors.primary,
                foregroundColor: colors.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
            ),
            if (nutrition != null) ...[
              const SizedBox(height: 24),
              NutritionFacts(
                food: nutrition,
                portion: _pieces
                    ? '${_amount.text} ${context.tr(['Kichik dona', 'O‘rtacha dona', 'Katta dona'][_size])} (${_format(grams!)} ${context.tr('g')})'
                    : '${_format(grams!)} ${context.tr(widget.food.basisUnit)}',
              ),
            ],
          ],
        ),
      ),
    );
  }
}
