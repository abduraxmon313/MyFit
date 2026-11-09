import '../theme/app_theme.dart';
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/food_nutrition.dart';
import '../widgets/app_ui.dart';
import '../widgets/food_thumbnail.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

enum MealType { breakfast, lunch, dinner, fifthSnack, snack }

extension MealTypeDetails on MealType {
  String get title => switch (this) {
    MealType.breakfast => 'Nonushta',
    MealType.lunch => 'Tushlik (Abed)',
    MealType.dinner => 'Kechki ovqat',
    MealType.snack => 'Perekus',
    MealType.fifthSnack => 'Kechki tamaddi',
  };

  String localizedTitle(BuildContext context) => context.tr(title);
  String localizedDescription(BuildContext context) => context.tr(description);
  String localizedTime(BuildContext context) => context.tr(time);

  /// Each meal has its own muted accent, used only on its icon tile.
  Color accent(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return dark ? Color.lerp(color, Colors.white, .35)! : color;
  }

  String get time => switch (this) {
    MealType.breakfast => '07:00 – 10:00',
    MealType.lunch => '12:00 – 15:00',
    MealType.dinner => '18:00 – 21:00',
    MealType.snack => 'Kun davomida',
    MealType.fifthSnack => '21:00 – 22:30',
  };

  String get description => switch (this) {
    MealType.breakfast => 'Kunni foydali va quvvatli boshlang',
    MealType.lunch => 'To‘yimli va muvozanatli asosiy ovqat',
    MealType.dinner => 'Yengil va oqsilga boy kechki ratsion',
    MealType.snack => 'Ovqatlar orasidagi foydali tamaddi',
    MealType.fifthSnack => 'Uyqu oldidan yengil va foydali tamaddi',
  };

  IconData get icon => switch (this) {
    MealType.breakfast => LucideIcons.coffee,
    MealType.lunch => LucideIcons.utensils,
    MealType.dinner => LucideIcons.soup,
    MealType.snack => LucideIcons.apple,
    MealType.fifthSnack => LucideIcons.moon,
  };

  Color get color => switch (this) {
    MealType.breakfast => AppPalette.accentAmber,
    MealType.lunch => AppPalette.accentGreen,
    MealType.dinner => AppPalette.accentBlue,
    MealType.snack => AppPalette.accentRose,
    MealType.fifthSnack => AppPalette.accentViolet,
  };

  Color get background => const Color(0xFFF3F4F6);
}

class MealsPage extends StatelessWidget {
  const MealsPage({
    super.key,
    required this.onMealSelected,
    this.dailyTarget = 2100,
    this.weekCalories = const {},
    this.calories = 0,
    this.protein = 0,
    this.carbohydrates = 0,
    this.fat = 0,
    this.fiber = 0,
    this.foods = const [],
    this.onFoodRemoved,
    this.onDateSelected,
  });

  final ValueChanged<MealType> onMealSelected;
  final double dailyTarget;
  final Map<DateTime, double> weekCalories;
  final double calories;
  final double protein;
  final double carbohydrates;
  final double fat;
  final double fiber;
  final List<FoodNutrition> foods;
  final ValueChanged<FoodNutrition>? onFoodRemoved;
  final ValueChanged<DateTime>? onDateSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Expanded(child: _PageHeader()),
                    if (onDateSelected != null)
                      OutlinedButton.icon(
                        onPressed: () async {
                          final now = DateTime.now();
                          final day = await showDatePicker(
                            context: context,
                            initialDate: now,
                            firstDate: DateTime(2000),
                            lastDate: now,
                          );
                          if (day != null && context.mounted) {
                            onDateSelected!(day);
                          }
                        },
                        icon: Tooltip(
                          message: context.tr('Kalendar'),
                          child: const Icon(LucideIcons.calendarDays, size: 16),
                        ),
                        label: Text(context.tr('Kalendar')),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                _WeeklyCalorieProgress(
                  dailyTarget: dailyTarget,
                  weekCalories: weekCalories,
                  onDateSelected: onDateSelected,
                ),
                const SizedBox(height: 12),
                _DailyNutritionSummary(
                  fat: fat,
                  carbohydrates: carbohydrates,
                  protein: protein,
                  fiber: fiber,
                  calories: calories,
                ),
                const SizedBox(height: 28),
                AppSectionHeader(
                  title: context.tr('Bugungi menyu'),
                  trailing: Text(
                    context.tr('5 mahal'),
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ...MealType.values.indexed.map((entry) {
                  final mealFoods = foods
                      .where(
                        (food) =>
                            (food.mealType ?? MealType.snack.name) ==
                            entry.$2.name,
                      )
                      .toList(growable: false);
                  return _ExpandableMealTimelineItem(
                    key: ValueKey('meal-${entry.$2.name}'),
                    meal: entry.$2,
                    foods: mealFoods,
                    isLast: entry.$1 == MealType.values.length - 1,
                    onAdd: () => onMealSelected(entry.$2),
                    onRemove: onFoodRemoved,
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PageHeader extends StatelessWidget {
  const _PageHeader();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr('Ovqatlanish'),
          style: TextStyle(
            color: scheme.onSurface,
            fontSize: 24,
            height: 1.15,
            fontWeight: FontWeight.w600,
            letterSpacing: -.6,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          context.tr('Sog‘lom kuningiz shu yerdan boshlanadi'),
          style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13.5),
        ),
      ],
    );
  }
}

class _WeeklyCalorieProgress extends StatelessWidget {
  const _WeeklyCalorieProgress({
    required this.dailyTarget,
    required this.weekCalories,
    this.onDateSelected,
  });

  final double dailyTarget;
  final Map<DateTime, double> weekCalories;
  final ValueChanged<DateTime>? onDateSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final monday = today.subtract(Duration(days: today.weekday - 1));
    final days = List.generate(7, (index) => monday.add(Duration(days: index)));
    final todayCalories = weekCalories[today] ?? 0;
    final safeTarget = dailyTarget <= 0 ? 1.0 : dailyTarget;

    return AppCard(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppOverline(context.tr('HAFTALIK MAQSAD')),
                    const SizedBox(height: 6),
                    Text(
                      context.tr('Bugun {calories} kcal', {
                        'calories': todayCalories.round(),
                      }),
                      style: TextStyle(
                        color: scheme.onSurface,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -.3,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                  border: Border.all(color: scheme.outlineVariant),
                ),
                child: Text(
                  '${todayCalories.round()} / ${dailyTarget.round()}',
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: List.generate(7, (index) {
              final day = days[index];
              final calories = weekCalories[day] ?? 0;
              final progress = (calories / safeTarget).clamp(0.0, 1.0);
              return Expanded(
                child: Semantics(
                  button: onDateSelected != null,
                  label: MaterialLocalizations.of(context).formatFullDate(day),
                  child: InkWell(
                    key: ValueKey('week-day-$index'),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    onTap: onDateSelected == null || day.isAfter(today)
                        ? null
                        : () => onDateSelected!(day),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: _DayProgress(
                        label: _localizedWeekday(context, index),
                        date: day.day,
                        progress: progress,
                        isToday: day == today,
                        isComplete: calories >= dailyTarget && dailyTarget > 0,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  String _localizedWeekday(BuildContext context, int index) {
    const names = {
      'uz': ['Du', 'Se', 'Ch', 'Pa', 'Ju', 'Sh', 'Ya'],
      'ru': ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'],
      'en': ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
    };
    return names[Localizations.localeOf(context).languageCode]![index];
  }
}

/// One weekday column: label, date and a vertical fill bar.
class _DayProgress extends StatelessWidget {
  const _DayProgress({
    required this.label,
    required this.date,
    required this.progress,
    required this.isToday,
    required this.isComplete,
  });

  final String label;
  final int date;
  final double progress;
  final bool isToday;
  final bool isComplete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final barColor = isComplete ? AppPalette.success : scheme.primary;
    return Column(
      children: [
        Text(
          label,
          maxLines: 1,
          style: TextStyle(
            color: isToday ? scheme.onSurface : scheme.onSurfaceVariant,
            fontSize: 11.5,
            fontWeight: isToday ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: 22,
          height: 44,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(AppRadius.xs),
            ),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: progress),
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeOutCubic,
                builder: (_, value, _) => FractionallySizedBox(
                  heightFactor: value,
                  widthFactor: 1,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: barColor,
                      borderRadius: BorderRadius.circular(AppRadius.xs),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: 26,
          height: 22,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isToday ? scheme.onSurface : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.xs),
          ),
          child: isComplete
              ? Icon(
                  LucideIcons.check,
                  size: 13,
                  color: isToday ? scheme.surface : AppPalette.success,
                )
              : Text(
                  '$date',
                  style: TextStyle(
                    color: isToday ? scheme.surface : scheme.onSurfaceVariant,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
        ),
      ],
    );
  }
}

class _DailyNutritionSummary extends StatelessWidget {
  const _DailyNutritionSummary({
    required this.fat,
    required this.carbohydrates,
    required this.protein,
    required this.fiber,
    required this.calories,
  });

  final double fat;
  final double carbohydrates;
  final double protein;
  final double fiber;
  final double calories;

  String _grams(double value) =>
      '${value.toStringAsFixed(value < 10 ? 1 : 0)} g';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final items = [
      (context.tr('Kaloriya'), '${calories.round()}', scheme.onSurface),
      (context.tr('Oqsil'), _grams(protein), AppPalette.protein),
      (context.tr('Uglevod'), _grams(carbohydrates), AppPalette.carbs),
      (context.tr('Yog‘'), _grams(fat), AppPalette.fat),
      (context.tr('Kletchatka'), _grams(fiber), AppPalette.fiber),
    ];
    return AppCard(
      padding: EdgeInsets.zero,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0)
                VerticalDivider(width: 1, color: scheme.outlineVariant),
              _NutritionValue(
                label: items[i].$1,
                value: items[i].$2,
                color: items[i].$3,
                emphasized: i == 0,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _NutritionValue extends StatelessWidget {
  const _NutritionValue({
    required this.label,
    required this.value,
    required this.color,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final Color color;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 14),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (!emphasized) ...[
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label,
                      maxLines: 1,
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                maxLines: 1,
                style: TextStyle(
                  color: scheme.onSurface,
                  fontSize: emphasized ? 17 : 14,
                  fontWeight: FontWeight.w600,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExpandableMealTimelineItem extends StatefulWidget {
  const _ExpandableMealTimelineItem({
    super.key,
    required this.meal,
    required this.foods,
    required this.isLast,
    required this.onAdd,
    required this.onRemove,
  });

  final MealType meal;
  final List<FoodNutrition> foods;
  final bool isLast;
  final VoidCallback onAdd;
  final ValueChanged<FoodNutrition>? onRemove;

  @override
  State<_ExpandableMealTimelineItem> createState() =>
      _ExpandableMealTimelineItemState();
}

class _ExpandableMealTimelineItemState
    extends State<_ExpandableMealTimelineItem> {
  // Ro'yxat boshida yopiq turadi; foydalanuvchi o'zi ochadi.
  bool _expanded = false;

  double get _totalCalories =>
      widget.foods.fold(0, (total, food) => total + food.calories);

  void _toggle() => setState(() => _expanded = !_expanded);

  @override
  Widget build(BuildContext context) {
    final meal = widget.meal;
    final foods = widget.foods;
    final hasFoods = foods.isNotEmpty;
    final expanded = _expanded && hasFoods;
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final border = colors.outlineVariant;
    final radius = BorderRadius.circular(AppRadius.lg);
    final languageCode = Localizations.localeOf(context).languageCode;
    return Padding(
      padding: EdgeInsets.only(bottom: widget.isLast ? 0 : 12),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: colors.surfaceContainerLowest,
          borderRadius: radius,
          border: Border.all(color: border),
          boxShadow: dark ? null : AppShadows.card,
        ),
        child: Material(
          color: Colors.transparent,
          child: Column(
            children: [
              InkWell(
                // Bo'sh mahal bosilsa darhol qo'shish ochiladi, aks holda
                // ro'yxat ochiladi/yopiladi.
                onTap: hasFoods ? _toggle : widget.onAdd,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      _MealPhoto(meal: meal),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              meal.localizedTitle(context),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: colors.onSurface,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -.2,
                              ),
                            ),
                            if (hasFoods) ...[
                              const SizedBox(height: 4),
                              Text(
                                '${foods.length} ${context.tr('mahsulot')} · ${_totalCalories.round()} ${context.tr('kcal')}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: colors.onSurfaceVariant,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (hasFoods)
                        IconButton(
                          key: ValueKey('meal-toggle-${meal.name}'),
                          tooltip: context.tr(
                            expanded ? 'Ro‘yxatni yopish' : 'Ro‘yxatni ochish',
                          ),
                          onPressed: _toggle,
                          icon: AnimatedRotation(
                            turns: expanded ? .5 : 0,
                            duration: const Duration(milliseconds: 200),
                            child: Icon(
                              LucideIcons.chevronDown,
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ),
                      const SizedBox(width: 4),
                      Tooltip(
                        message: context.tr('Ovqat qo‘shish'),
                        child: Semantics(
                          button: true,
                          label: context.tr('Ovqat qo‘shish'),
                          child: Material(
                            color: colors.surfaceContainerLowest,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                              side: BorderSide(color: colors.outline),
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                              onTap: widget.onAdd,
                              child: SizedBox.square(
                                dimension: 34,
                                child: Icon(
                                  LucideIcons.plus,
                                  color: colors.onSurface,
                                  size: 18,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: !expanded
                    ? const SizedBox(width: double.infinity)
                    : Column(
                        children: [
                          Divider(height: 1, thickness: 1, color: border),
                          for (
                            var index = 0;
                            index < foods.length;
                            index++
                          ) ...[
                            if (index > 0)
                              Divider(
                                height: 1,
                                thickness: 1,
                                indent: 66,
                                color: border.withValues(alpha: .7),
                              ),
                            _MealFoodRow(
                              food: foods[index],
                              languageCode: languageCode,
                              onRemove: widget.onRemove == null
                                  ? null
                                  : () => widget.onRemove!(foods[index]),
                            ),
                          ],
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

/// Neutral icon representing each meal of the day.
class _MealPhoto extends StatelessWidget {
  const _MealPhoto({required this.meal});

  final MealType meal;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: AppIconTile.tinted(icon: meal.icon, size: 44, accent: meal.color),
  );
}

class _MealFoodRow extends StatelessWidget {
  const _MealFoodRow({
    required this.food,
    required this.languageCode,
    required this.onRemove,
  });

  final FoodNutrition food;
  final String languageCode;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final wholeGrams = food.grams == food.grams.roundToDouble();
    return Padding(
      padding: EdgeInsets.fromLTRB(14, 10, onRemove == null ? 16 : 4, 10),
      child: Row(
        children: [
          FoodThumbnail(icon: foodCategoryIcon(food), size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  food.displayNameFor(languageCode),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.onSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${food.grams.toStringAsFixed(wholeGrams ? 0 : 1)} ${context.tr(food.basisUnit)}',
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${food.calories.round()} ${context.tr('kcal')}',
            style: TextStyle(
              color: colors.onSurface,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          if (onRemove != null)
            IconButton(
              onPressed: onRemove,
              visualDensity: VisualDensity.compact,
              tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
              icon: Icon(LucideIcons.trash2, color: colors.error, size: 21),
            ),
        ],
      ),
    );
  }
}
