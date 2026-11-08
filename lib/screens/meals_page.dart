import '../theme/app_theme.dart';
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/food_nutrition.dart';
import '../widgets/food_thumbnail.dart';

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

  Color accent(BuildContext context) {
    if (Theme.of(context).brightness == Brightness.dark) return color;
    return switch (this) {
      MealType.breakfast => const Color(0xFF8A5B14),
      MealType.lunch => const Color(0xFF13765E),
      MealType.dinner => const Color(0xFF2E6893),
      MealType.snack => const Color(0xFF9B4146),
      MealType.fifthSnack => const Color(0xFF6A548D),
    };
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
    MealType.breakfast => Icons.coffee_outlined,
    MealType.lunch => Icons.restaurant_outlined,
    MealType.dinner => Icons.dinner_dining_outlined,
    MealType.snack => Icons.apple_outlined,
    MealType.fifthSnack => Icons.nightlight_outlined,
  };

  Color get color => switch (this) {
    MealType.breakfast => const Color(0xFFD4AF72),
    MealType.lunch => const Color(0xFF43CBA8),
    MealType.dinner => const Color(0xFF7CA9D2),
    MealType.snack => const Color(0xFFCF8C8C),
    MealType.fifthSnack => const Color(0xFFA69AC7),
  };

  Color get background => switch (this) {
    MealType.breakfast => const Color(0xFFFFF6E7),
    MealType.lunch => const Color(0xFFEAF9F0),
    MealType.dinner => const Color(0xFFEEF0FF),
    MealType.snack => const Color(0xFFFFEEF0),
    MealType.fifthSnack => const Color(0xFFF4EDFC),
  };
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

  static const _navy = Color(0xFF10223C);

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 34),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Expanded(child: _PageHeader()),
                    if (onDateSelected != null)
                      IconButton.filledTonal(
                        tooltip: context.tr('Kalendar'),
                        icon: const Icon(Icons.calendar_month_rounded),
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
                      ),
                  ],
                ),
                const SizedBox(height: 22),
                _WeeklyCalorieProgress(
                  dailyTarget: dailyTarget,
                  weekCalories: weekCalories,
                  onDateSelected: onDateSelected,
                ),
                const SizedBox(height: 16),
                _DailyNutritionSummary(
                  fat: fat,
                  carbohydrates: carbohydrates,
                  protein: protein,
                  fiber: fiber,
                  calories: calories,
                ),
                const SizedBox(height: 26),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        context.tr('Bugungi menyu'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: context.appColor(_navy, surface: false),
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      context.tr('5 mahal'),
                      style: TextStyle(
                        color: context.appColor(
                          Color(0xFF718079),
                          surface: false,
                        ),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                ...MealType.values.indexed.map((entry) {
                  final mealFoods = foods
                      .where(
                        (food) =>
                            (food.mealType ?? MealType.snack.name) ==
                            entry.$2.name,
                      )
                      .toList(growable: false);
                  return _ExpandableMealTimelineItem(
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
    return Row(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: context.appPanelColors),
            borderRadius: BorderRadius.circular(18),
            boxShadow: Theme.of(context).brightness == Brightness.dark
                ? const []
                : const [
                    BoxShadow(
                      color: Color(0x3513B957),
                      blurRadius: 18,
                      offset: Offset(0, 8),
                    ),
                  ],
          ),
          child: Icon(
            Icons.restaurant_menu_rounded,
            color: context.appColor(Colors.white, surface: false),
            size: 27,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr('Ovqatlanish'),
                style: TextStyle(
                  color: context.appColor(Color(0xFF10223C), surface: false),
                  fontSize: 27,
                  height: 1.05,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                context.tr('Sog‘lom kuningiz shu yerdan boshlanadi'),
                style: TextStyle(
                  color: context.appColor(Color(0xFF718079), surface: false),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
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
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final monday = today.subtract(Duration(days: today.weekday - 1));
    final days = List.generate(7, (index) => monday.add(Duration(days: index)));
    final todayCalories = weekCalories[today] ?? 0;
    final safeTarget = dailyTarget <= 0 ? 1.0 : dailyTarget;

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: context.appPanelColors,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: Theme.of(context).brightness == Brightness.dark
            ? const []
            : const [
                BoxShadow(
                  color: Color(0x30114335),
                  blurRadius: 28,
                  offset: Offset(0, 13),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('HAFTALIK MAQSAD'),
                      style: TextStyle(
                        color: context.appColor(Colors.white60, surface: false),
                        fontSize: 10,
                        letterSpacing: 1.3,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      context.tr('Bugun {calories} kcal', {
                        'calories': todayCalories.round(),
                      }),
                      style: TextStyle(
                        color: context.appColor(Colors.white, surface: false),
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: context
                      .appColor(Colors.white, surface: true)
                      .withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: context.appColor(Colors.white12, surface: true),
                  ),
                ),
                child: Text(
                  '${todayCalories.round()} / ${dailyTarget.round()}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 19),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                    borderRadius: BorderRadius.circular(16),
                    onTap: onDateSelected == null || day.isAfter(today)
                        ? null
                        : () => onDateSelected!(day),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
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
    return Column(
      children: [
        SizedBox.square(
          dimension: 36,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox.square(
                dimension: 36,
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: isToday ? 4 : 3,
                  strokeCap: StrokeCap.round,
                  backgroundColor: Theme.of(context).colorScheme.outlineVariant,
                  valueColor: AlwaysStoppedAnimation(
                    Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              if (isComplete)
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: Color(0xFF0B3B2D),
                    size: 20,
                  ),
                )
              else
                Text(
                  '$date',
                  style: TextStyle(
                    color: isToday
                        ? Theme.of(context).colorScheme.primary
                        : context.appColor(Colors.white70, surface: false),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            color: isToday
                ? Theme.of(context).colorScheme.primary
                : context.appColor(Colors.white60, surface: false),
            fontSize: 11,
            fontWeight: isToday ? FontWeight.w600 : FontWeight.w600,
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
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: context.appColor(Color(0xFFC8DED1), surface: true),
        ),
        boxShadow: Theme.of(context).brightness == Brightness.dark
            ? const []
            : const [
                BoxShadow(
                  color: Color(0x1A0C603F),
                  blurRadius: 20,
                  offset: Offset(0, 8),
                ),
              ],
      ),
      child: Row(
        children: [
          _NutritionValue(
            label: context.tr('Kaloriya'),
            value: '${calories.round()}',
            color: context.appColor(Color(0xFF10A96A), surface: true),
            emphasized: true,
          ),
          _NutritionValue(
            label: context.tr('Oqsil'),
            value: _grams(protein),
            color: context.appColor(Color(0xFF5368D9), surface: true),
          ),
          _NutritionValue(
            label: context.tr('Uglevod'),
            value: _grams(carbohydrates),
            color: context.appColor(Color(0xFFF0A128), surface: true),
          ),
          _NutritionValue(
            label: context.tr('Yog‘'),
            value: _grams(fat),
            color: context.appColor(Color(0xFFE06475), surface: true),
          ),
          _NutritionValue(
            label: context.tr('Kletchatka'),
            value: _grams(fiber),
            color: context.appColor(Color(0xFF10A96A), surface: true),
          ),
        ],
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
    return Expanded(
      child: Container(
        height: 67 + MediaQuery.textScalerOf(context).scale(28) - 28,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 9),
        decoration: BoxDecoration(
          gradient: emphasized
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: context.appPanelColors,
                )
              : null,
          color: emphasized
              ? null
              : Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(15),
          border: emphasized
              ? null
              : Border.all(color: color.withValues(alpha: .16)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                style: TextStyle(
                  color: emphasized
                      ? context.appColor(Colors.white70, surface: false)
                      : context.appColor(Color(0xFF7A8392), surface: false),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 5),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                maxLines: 1,
                style: TextStyle(
                  color: emphasized
                      ? context.appColor(Colors.white, surface: false)
                      : Theme.of(context).colorScheme.onSurface,
                  fontSize: emphasized ? 17 : 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExpandableMealTimelineItem extends StatelessWidget {
  const _ExpandableMealTimelineItem({
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

  double get totalCalories =>
      foods.fold(0, (total, food) => total + food.calories);

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final accent = meal.accent(context);
    final border = dark ? colors.outlineVariant : const Color(0xFFE4E9EE);
    final radius = BorderRadius.circular(20);
    final languageCode = Localizations.localeOf(context).languageCode;
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: colors.surfaceContainerLowest,
          borderRadius: radius,
          border: Border.all(color: border),
          boxShadow: dark
              ? const []
              : const [
                  BoxShadow(
                    color: Color(0x0A0F1B2D),
                    blurRadius: 18,
                    offset: Offset(0, 6),
                  ),
                ],
        ),
        child: Material(
          color: Colors.transparent,
          child: Column(
            children: [
              InkWell(
                onTap: onAdd,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
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
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  foods.isEmpty
                                      ? Icons.schedule_rounded
                                      : Icons.check_circle_rounded,
                                  size: 13,
                                  color: foods.isEmpty
                                      ? colors.onSurfaceVariant
                                      : accent,
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    foods.isEmpty
                                        ? meal.localizedTime(context)
                                        : '${foods.length} ${context.tr('mahsulot')} · ${totalCalories.round()} ${context.tr('kcal')}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: colors.onSurfaceVariant,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Semantics(
                        button: true,
                        label: context.tr('Ovqat qo‘shish'),
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: accent,
                            shape: BoxShape.circle,
                            boxShadow: dark
                                ? null
                                : [
                                    BoxShadow(
                                      color: accent.withValues(alpha: .3),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                          ),
                          child: Icon(
                            Icons.add_rounded,
                            color: dark ? colors.surface : Colors.white,
                            size: 22,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (foods.isNotEmpty) ...[
                Divider(height: 1, thickness: 1, color: border),
                for (var index = 0; index < foods.length; index++) ...[
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
                    onRemove: onRemove == null
                        ? null
                        : () => onRemove!(foods[index]),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// `meal_photography.png` beshta vertikal suratdan iborat; har bir mahal o'z
/// suratining markaziy kvadrat qismini ko'rsatadi.
class _MealPhoto extends StatelessWidget {
  const _MealPhoto({required this.meal});

  final MealType meal;
  static const _size = 56.0;

  @override
  Widget build(BuildContext context) {
    final index = switch (meal) {
      MealType.breakfast => 0,
      MealType.lunch => 1,
      MealType.dinner => 2,
      MealType.fifthSnack => 3,
      MealType.snack => 4,
    };
    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SizedBox.square(
          dimension: _size,
          child: OverflowBox(
            minWidth: _size * 5,
            maxWidth: _size * 5,
            minHeight: _size * 5 * 724 / 2172,
            maxHeight: _size * 5 * 724 / 2172,
            alignment: Alignment(-1 + index * .5, .1),
            child: Image.asset(
              'assets/images/meal_photography.png',
              fit: BoxFit.cover,
              cacheWidth: 900,
              filterQuality: FilterQuality.medium,
            ),
          ),
        ),
      ),
    );
  }
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
          FoodThumbnail(asset: foodThumbnailAsset(food), size: 40),
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
              icon: Icon(
                Icons.close_rounded,
                color: colors.onSurfaceVariant,
                size: 18,
              ),
            ),
        ],
      ),
    );
  }
}
