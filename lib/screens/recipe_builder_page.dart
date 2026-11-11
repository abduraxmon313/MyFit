import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../l10n/app_localizations.dart';
import '../models/food_nutrition.dart';
import '../services/custom_food_store.dart';
import '../services/food_data_service.dart';
import '../services/recipe_builder.dart';
import '../theme/app_theme.dart';
import '../widgets/app_ui.dart';
import '../widgets/food_thumbnail.dart';
import 'meals_page.dart';
import 'national_food_picker_page.dart';

/// Lets the user assemble their own dish (e.g. "Sho‘rva") from catalogue
/// ingredients and saves it as a reusable food.
class RecipeBuilderPage extends StatefulWidget {
  const RecipeBuilderPage({super.key, this.foodDataService, this.store});

  final FoodDataService? foodDataService;
  final CustomFoodStore? store;

  @override
  State<RecipeBuilderPage> createState() => _RecipeBuilderPageState();
}

class _RecipeBuilderPageState extends State<RecipeBuilderPage> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _cookedWeight = TextEditingController();
  final List<FoodNutrition> _ingredients = [];
  bool _saving = false;
  bool _showIngredientError = false;

  @override
  void initState() {
    super.initState();
    _name.addListener(() => setState(() {}));
    _cookedWeight.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    _cookedWeight.dispose();
    super.dispose();
  }

  double? get _cookedGrams {
    final text = _cookedWeight.text.trim().replaceAll(',', '.');
    if (text.isEmpty) return null;
    return double.tryParse(text);
  }

  bool get _dirty => _name.text.trim().isNotEmpty || _ingredients.isNotEmpty;

  Future<void> _addIngredients() async {
    final picked = await Navigator.push<List<FoodNutrition>>(
      context,
      MaterialPageRoute(
        builder: (_) => NationalFoodPickerPage(
          meal: MealType.lunch,
          title: context.tr('Masalliq qo‘shish'),
          foodDataService: widget.foodDataService,
        ),
      ),
    );
    if (picked == null || picked.isEmpty || !mounted) return;
    setState(() {
      _ingredients.addAll(picked);
      _showIngredientError = false;
    });
  }

  Future<void> _editGrams(int index) async {
    final food = _ingredients[index];
    final controller = TextEditingController(
      text: food.grams == food.grams.roundToDouble()
          ? food.grams.round().toString()
          : food.grams.toString(),
    );
    final grams = await showDialog<double>(
      context: context,
      builder: (context) {
        double? parse() =>
            double.tryParse(controller.text.trim().replaceAll(',', '.'));
        return AlertDialog(
          title: Text(food.displayNameFor(_languageCode)),
          content: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]')),
            ],
            decoration: InputDecoration(
              labelText: context.tr('Miqdori'),
              suffixText: context.tr(food.basisUnit),
            ),
            onSubmitted: (_) {
              final value = parse();
              if (value != null && value > 0 && value <= 5000) {
                Navigator.pop(context, value);
              }
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
            ),
            FilledButton(
              onPressed: () {
                final value = parse();
                if (value != null && value > 0 && value <= 5000) {
                  Navigator.pop(context, value);
                }
              },
              child: Text(context.tr('Saqlash')),
            ),
          ],
        );
      },
    );
    controller.dispose();
    if (grams == null || !mounted) return;
    setState(() => _ingredients[index] = food.forGrams(grams));
  }

  String get _languageCode => Localizations.localeOf(context).languageCode;

  Future<void> _create() async {
    final valid = _form.currentState!.validate();
    if (_ingredients.isEmpty) setState(() => _showIngredientError = true);
    if (!valid || _ingredients.isEmpty || _saving) return;
    setState(() => _saving = true);
    final recipe = buildRecipe(
      name: _name.text,
      ingredients: _ingredients,
      cookedWeight: _cookedGrams,
      languageCode: _languageCode,
    );
    try {
      await (widget.store ?? CustomFoodStore()).save(recipe);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr('“{name}” yaratildi. Uni qidiruvdan topasiz.', {
              'name': recipe.name,
            }),
          ),
        ),
      );
      Navigator.pop(context, recipe);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('Ovqatni saqlab bo‘lmadi.'))),
      );
    }
  }

  Future<void> _confirmLeave() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('Ovqat saqlanmadi')),
        content: Text(
          context.tr('Kiritilgan ma’lumotlar o‘chadi. Chiqasizmi?'),
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
    setState(() => _saving = true);
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final totals = RecipeTotals.of(_ingredients);
    final cooked = _cookedGrams;
    final weight = cooked != null && cooked > 0 ? cooked : totals.grams;
    final per100 = weight > 0 ? totals.calories * 100 / weight : 0.0;
    String g(double value) => value.toStringAsFixed(value < 10 ? 1 : 0);
    return PopScope(
      canPop: !_dirty || _saving,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmLeave();
      },
      child: Scaffold(
        appBar: AppBar(title: Text(context.tr('Ovqat yaratish'))),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: FilledButton.icon(
              key: const Key('recipe-create'),
              onPressed: _saving ? null : _create,
              icon: const Icon(LucideIcons.check, size: 18),
              label: Text(context.tr('Ovqat yaratish')),
            ),
          ),
        ),
        body: Form(
          key: _form,
          // Xato matni foydalanuvchi maydonni to'g'rilashi bilan yo'qoladi.
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              Text(
                context.tr(
                  'Ovqat nomini yozing va unga ketgan masalliqlarni miqdori bilan qo‘shing.',
                ),
                style: TextStyle(color: scheme.onSurfaceVariant, height: 1.45),
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const Key('recipe-name'),
                controller: _name,
                maxLength: 80,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: context.tr('Ovqat nomi'),
                  hintText: context.tr('Masalan: Sho‘rva'),
                  prefixIcon: const Icon(LucideIcons.chefHat, size: 18),
                ),
                validator: (value) => (value ?? '').trim().isEmpty
                    ? context.tr('Majburiy maydon')
                    : null,
              ),
              const SizedBox(height: 12),
              AppSectionHeader(
                title: context.tr('Masalliqlar'),
                trailing: Text(
                  '${_ingredients.length}',
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (var i = 0; i < _ingredients.length; i++) ...[
                      if (i > 0)
                        Divider(
                          height: 1,
                          indent: 70,
                          color: scheme.outlineVariant,
                        ),
                      _IngredientRow(
                        food: _ingredients[i],
                        languageCode: _languageCode,
                        onEdit: () => _editGrams(i),
                        onRemove: () =>
                            setState(() => _ingredients.removeAt(i)),
                      ),
                    ],
                    if (_ingredients.isNotEmpty)
                      Divider(height: 1, color: scheme.outlineVariant),
                    InkWell(
                      key: const Key('recipe-add-ingredient'),
                      onTap: _saving ? null : _addIngredients,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        child: Row(
                          children: [
                            AppIconTile.tinted(
                              icon: LucideIcons.plus,
                              size: 36,
                              accent: AppPalette.accentBlue,
                            ),
                            const SizedBox(width: 14),
                            Text(
                              context.tr('Masalliq qo‘shish'),
                              style: TextStyle(
                                color: scheme.primary,
                                fontSize: 14.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (_showIngredientError && _ingredients.isEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  context.tr('Kamida bitta masalliq qo‘shing.'),
                  style: TextStyle(color: scheme.error, fontSize: 12.5),
                ),
              ],
              const SizedBox(height: 16),
              TextFormField(
                key: const Key('recipe-cooked-weight'),
                controller: _cookedWeight,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]')),
                ],
                decoration: InputDecoration(
                  labelText: context.tr('Tayyor ovqat vazni (ixtiyoriy)'),
                  suffixText: context.tr('g'),
                  helperText: context.tr(
                    'Bo‘sh qolsa, masalliqlar yig‘indisi olinadi. Qaynatishda suv bug‘lansa, tortib kiriting.',
                  ),
                  helperMaxLines: 3,
                ),
                validator: (value) {
                  if ((value ?? '').trim().isEmpty) return null;
                  final parsed = _cookedGrams;
                  return parsed == null ||
                          !parsed.isFinite ||
                          parsed <= 0 ||
                          parsed > 20000
                      ? context.tr('1–20000 g oralig‘ida kiriting.')
                      : null;
                },
              ),
              const SizedBox(height: 20),
              AppCard(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppOverline(context.tr('Jami')),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          totals.calories.round().toString(),
                          key: const Key('recipe-total-kcal'),
                          style: TextStyle(
                            color: scheme.onSurface,
                            fontSize: 26,
                            height: 1,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -.8,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${context.tr('kcal')} · ${g(weight)} ${context.tr('g')}',
                          style: TextStyle(
                            color: scheme.onSurfaceVariant,
                            fontSize: 13,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${per100.round()} ${context.tr('kcal')} / 100 ${context.tr('g')}',
                          key: const Key('recipe-per-100'),
                          style: TextStyle(
                            color: scheme.onSurface,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Divider(height: 1, color: scheme.outlineVariant),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        _Macro(
                          'Oqsil',
                          '${g(totals.protein)} ${context.tr('g')}',
                          AppPalette.protein,
                        ),
                        _Macro(
                          'Uglevod',
                          '${g(totals.carbohydrates)} ${context.tr('g')}',
                          AppPalette.carbs,
                        ),
                        _Macro(
                          'Yog‘',
                          '${g(totals.fat)} ${context.tr('g')}',
                          AppPalette.fat,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IngredientRow extends StatelessWidget {
  const _IngredientRow({
    required this.food,
    required this.languageCode,
    required this.onEdit,
    required this.onRemove,
  });

  final FoodNutrition food;
  final String languageCode;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final whole = food.grams == food.grams.roundToDouble();
    return InkWell(
      onTap: onEdit,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 4, 10),
        child: Row(
          children: [
            FoodThumbnail.forFood(food, size: 40),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    food.displayNameFor(languageCode),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        '${food.grams.toStringAsFixed(whole ? 0 : 1)} ${context.tr(food.basisUnit)}',
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontSize: 12.5,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        LucideIcons.pencil,
                        size: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Text(
              '${food.calories.round()} ${context.tr('kcal')}',
              style: TextStyle(
                color: scheme.onSurface,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            IconButton(
              tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
              onPressed: onRemove,
              icon: Icon(LucideIcons.trash2, size: 19, color: scheme.error),
            ),
          ],
        ),
      ),
    );
  }
}

class _Macro extends StatelessWidget {
  const _Macro(this.label, this.value, this.color);

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                context.tr(label),
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: scheme.onSurface,
              fontSize: 15,
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
