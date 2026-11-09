import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/food_nutrition.dart';
import '../services/food_log_service.dart';
import '../widgets/nutrition_facts.dart';
import 'meals_page.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class FoodHistoryPage extends StatefulWidget {
  const FoodHistoryPage({
    super.key,
    required this.uid,
    required this.initialDate,
    required this.service,
  });
  final String uid;
  final DateTime initialDate;
  final FoodLogService service;

  @override
  State<FoodHistoryPage> createState() => _FoodHistoryPageState();
}

class _FoodHistoryPageState extends State<FoodHistoryPage> {
  late DateTime _day;
  List<FoodNutrition> _foods = const [];
  bool _loading = true;
  bool _failed = false;
  int _request = 0;
  DateTime get _today => DateUtils.dateOnly(DateTime.now());

  @override
  void initState() {
    super.initState();
    _day = DateUtils.dateOnly(widget.initialDate);
    _load(_day);
  }

  Future<void> _load(DateTime day) async {
    final date = DateUtils.dateOnly(day);
    if (date.isAfter(_today)) return;
    final request = ++_request;
    setState(() {
      _day = date;
      _loading = true;
      _failed = false;
      _foods = const [];
    });
    try {
      final foods = await widget.service.loadDay(widget.uid, date);
      if (!mounted || request != _request) return;
      setState(() {
        _foods = foods;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || request != _request) return;
      setState(() {
        _failed = true;
        _loading = false;
      });
    }
  }

  Future<void> _calendar() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: DateTime(2000),
      lastDate: _today,
    );
    if (date != null && mounted) _load(date);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dates = MaterialLocalizations.of(context);
    final monday = DateTime(_day.year, _day.month, _day.day - _day.weekday + 1);
    const weekdays = {
      'uz': ['Du', 'Se', 'Ch', 'Pa', 'Ju', 'Sh', 'Ya'],
      'ru': ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'],
      'en': ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
    };
    final names =
        weekdays[Localizations.localeOf(context).languageCode] ??
        weekdays['uz']!;
    final total = _foods.fold<double>(0, (sum, food) => sum + food.calories);
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('Ovqatlanish tarixi')),
        actions: [
          IconButton(
            tooltip: context.tr('Kalendar'),
            onPressed: _calendar,
            icon: const Icon(LucideIcons.calendarDays),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                IconButton(
                  tooltip: context.tr('Oldingi kun'),
                  onPressed: _day.isAfter(DateTime(2000))
                      ? () =>
                            _load(DateTime(_day.year, _day.month, _day.day - 1))
                      : null,
                  icon: const Icon(LucideIcons.chevronLeft),
                ),
                Expanded(
                  child: TextButton(
                    onPressed: _calendar,
                    child: Text(
                      dates.formatMediumDate(_day),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: context.tr('Keyingi kun'),
                  onPressed: _day.isBefore(_today)
                      ? () =>
                            _load(DateTime(_day.year, _day.month, _day.day + 1))
                      : null,
                  icon: const Icon(LucideIcons.chevronRight),
                ),
                TextButton(
                  onPressed: () => _load(_today),
                  child: Text(context.tr('Bugun')),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
            child: Row(
              children: List.generate(7, (index) {
                final date = DateTime(
                  monday.year,
                  monday.month,
                  monday.day + index,
                );
                final selected = date == _day;
                return Expanded(
                  child: Semantics(
                    label: dates.formatFullDate(date),
                    selected: selected,
                    child: InkWell(
                      key: ValueKey('history-day-$index'),
                      onTap: date.isAfter(_today) ? null : () => _load(date),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: selected ? colors.primaryContainer : null,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Text(
                              '${date.day}',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: selected
                                    ? colors.onPrimaryContainer
                                    : date.isAfter(_today)
                                    ? colors.outline
                                    : colors.onSurface,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              names[index],
                              style: TextStyle(
                                fontSize: 11,
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _failed
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(context.tr('Tarixni yuklab bo‘lmadi.')),
                        TextButton(
                          onPressed: () => _load(_day),
                          child: Text(context.tr('Qayta urinish')),
                        ),
                      ],
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                dates.formatFullDate(_day),
                                style: TextStyle(
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${total.round()} ${context.tr('kcal')}',
                                key: const Key('history-calories'),
                                style: TextStyle(
                                  color: colors.primary,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (_foods.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            context.tr('Bu kunda ovqat saqlanmagan.'),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      for (final meal in MealType.values)
                        if (_foods.any(
                          (food) =>
                              (food.mealType ?? MealType.snack.name) ==
                              meal.name,
                        )) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Text(
                              meal.localizedTitle(context),
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          for (final food in _foods.where(
                            (food) =>
                                (food.mealType ?? MealType.snack.name) ==
                                meal.name,
                          ))
                            Card(
                              child: ListTile(
                                title: Text(
                                  food.displayNameFor(
                                    Localizations.localeOf(
                                      context,
                                    ).languageCode,
                                  ),
                                ),
                                subtitle: Text(
                                  '${food.grams.toStringAsFixed(1)} ${context.tr(food.basisUnit)} · ${food.calories.round()} ${context.tr('kcal')}',
                                ),
                                trailing: const Icon(LucideIcons.chevronRight),
                                onTap: () => showModalBottomSheet<void>(
                                  context: context,
                                  isScrollControlled: true,
                                  showDragHandle: true,
                                  builder: (_) => SafeArea(
                                    child: SingleChildScrollView(
                                      padding: const EdgeInsets.all(20),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          Text(
                                            food.displayNameFor(
                                              Localizations.localeOf(
                                                context,
                                              ).languageCode,
                                            ),
                                            style: Theme.of(
                                              context,
                                            ).textTheme.titleLarge,
                                          ),
                                          const SizedBox(height: 16),
                                          NutritionFacts(
                                            food: food,
                                            portion:
                                                '${food.grams.toStringAsFixed(1)} ${context.tr(food.basisUnit)}',
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
