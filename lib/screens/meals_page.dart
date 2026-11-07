import '../theme/app_theme.dart';
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/food_nutrition.dart';

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
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 34,
            child: Column(
              children: [
                Container(
                  width: 13,
                  height: 13,
                  decoration: BoxDecoration(
                    color: meal.accent(context),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: context.appColor(Colors.white, surface: false),
                      width: 3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: meal.accent(context).withValues(alpha: .28),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 3),
                      color: meal.accent(context).withValues(alpha: .18),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 13),
              child: Material(
                color: Theme.of(context).colorScheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(16),
                clipBehavior: Clip.antiAlias,
                child: _MealPhotoSurface(
                  meal: meal,
                  child: Theme(
                    data: Theme.of(context).copyWith(
                      dividerColor: Colors.transparent,
                      splashColor: meal.accent(context).withValues(alpha: .06),
                    ),
                    child: ExpansionTile(
                      key: ValueKey('${meal.name}:${foods.length}'),
                      initiallyExpanded: foods.isNotEmpty,
                      onExpansionChanged: (expanded) {
                        if (expanded && foods.isEmpty) onAdd();
                      },
                      tilePadding: const EdgeInsets.fromLTRB(14, 18, 10, 18),
                      childrenPadding: EdgeInsets.zero,
                      backgroundColor: Colors.transparent,
                      collapsedBackgroundColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: meal.accent(context).withValues(alpha: .24),
                        ),
                      ),
                      collapsedShape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: meal.accent(context).withValues(alpha: .1),
                        ),
                      ),
                      leading: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: context.appColor(
                            meal.background,
                            surface: true,
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          meal.icon,
                          color: meal.accent(context),
                          size: 25,
                        ),
                      ),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              meal.localizedTitle(context),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: context.appColor(
                                  Color(0xFF10223C),
                                  surface: false,
                                ),
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (foods.isNotEmpty)
                            Text(
                              '${totalCalories.round()}',
                              style: TextStyle(
                                color: context.appColor(
                                  Color(0xFF10223C),
                                  surface: false,
                                ),
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                        ],
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          foods.isEmpty
                              ? meal.localizedTime(context)
                              : '${foods.length} ${context.tr('mahsulot')} · ${context.tr('kcal')}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: foods.isEmpty
                                ? context.appColor(
                                    Color(0xFF7A8392),
                                    surface: false,
                                  )
                                : meal.accent(context),
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      trailing: _MealAddButton(
                        color: meal.accent(context),
                        onTap: onAdd,
                      ),
                      children: [
                        if (foods.isEmpty)
                          _EmptyMealContent(meal: meal, onAdd: onAdd)
                        else
                          _MealExpandedContent(
                            meal: meal,
                            foods: foods,
                            onAdd: onAdd,
                            onRemove: onRemove,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MealPhotoSurface extends StatelessWidget {
  const _MealPhotoSurface({required this.meal, required this.child});

  final MealType meal;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surfaceContainerLowest;
    final index = switch (meal) {
      MealType.breakfast => 0,
      MealType.lunch => 1,
      MealType.dinner => 2,
      MealType.fifthSnack => 3,
      MealType.snack => 4,
    };
    return Stack(
      children: [
        Positioned(
          top: 0,
          right: 0,
          width: 144,
          height: 112,
          child: IgnorePointer(
            child: ExcludeSemantics(
              child: ShaderMask(
                blendMode: BlendMode.dstIn,
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [Colors.transparent, Colors.black],
                  stops: [0, .6],
                ).createShader(bounds),
                child: ClipRect(
                  child: OverflowBox(
                    minWidth: 720,
                    maxWidth: 720,
                    alignment: Alignment(-1 + index * .5, 0),
                    child: Image.asset(
                      'assets/images/meal_photography.png',
                      width: 720,
                      height: 112,
                      fit: BoxFit.cover,
                      cacheWidth: 1440,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    surface,
                    surface.withValues(alpha: .96),
                    surface.withValues(alpha: .38),
                  ],
                  stops: const [0, .45, 1],
                ),
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class _MealAddButton extends StatelessWidget {
  const _MealAddButton({required this.color, required this.onTap});

  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: .1),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 34,
          height: 34,
          child: Icon(Icons.add_rounded, color: color, size: 23),
        ),
      ),
    );
  }
}

class _EmptyMealContent extends StatelessWidget {
  const _EmptyMealContent({required this.meal, required this.onAdd});

  final MealType meal;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onAdd,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(15),
        color: context
            .appColor(meal.background, surface: true)
            .withValues(alpha: .5),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_circle_outline_rounded,
              color: meal.accent(context),
              size: 18,
            ),
            const SizedBox(width: 7),
            Text(
              context.tr('Ovqat qo‘shish'),
              style: TextStyle(
                color: meal.accent(context),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MealExpandedContent extends StatelessWidget {
  const _MealExpandedContent({
    required this.meal,
    required this.foods,
    required this.onAdd,
    required this.onRemove,
  });

  final MealType meal;
  final List<FoodNutrition> foods;
  final VoidCallback onAdd;
  final ValueChanged<FoodNutrition>? onRemove;

  @override
  Widget build(BuildContext context) {
    final languageCode = Localizations.localeOf(context).languageCode;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: context
            .appColor(meal.background, surface: true)
            .withValues(alpha: .52),
        border: Border(
          top: BorderSide(color: meal.accent(context).withValues(alpha: .12)),
        ),
      ),
      child: Column(
        children: [
          for (var index = 0; index < foods.length; index++) ...[
            _MealFoodRow(
              food: foods[index],
              languageCode: languageCode,
              color: meal.accent(context),
              onRemove: onRemove == null ? null : () => onRemove!(foods[index]),
            ),
            if (index != foods.length - 1)
              Divider(
                height: 1,
                indent: 54,
                endIndent: 14,
                color: meal.accent(context).withValues(alpha: .1),
              ),
          ],
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onAdd,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_circle_outline_rounded,
                      color: meal.accent(context),
                      size: 18,
                    ),
                    const SizedBox(width: 7),
                    Text(
                      context.tr('Ovqat qo‘shish'),
                      style: TextStyle(
                        color: meal.accent(context),
                        fontSize: 12,
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
    );
  }
}

class _MealFoodRow extends StatelessWidget {
  const _MealFoodRow({
    required this.food,
    required this.languageCode,
    required this.color,
    required this.onRemove,
  });

  final FoodNutrition food;
  final String languageCode;
  final Color color;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final wholeGrams = food.grams == food.grams.roundToDouble();
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 7, 12),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: context
                  .appColor(Colors.white, surface: true)
                  .withValues(alpha: .82),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(Icons.restaurant_rounded, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  food.displayNameFor(languageCode),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.appColor(Color(0xFF10223C), surface: false),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${food.grams.toStringAsFixed(wholeGrams ? 0 : 1)} ${context.tr(food.basisUnit)}',
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${food.calories.round()} ${context.tr('kcal')}',
            style: TextStyle(
              color: context.appColor(Color(0xFF10223C), surface: false),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (onRemove != null)
            IconButton(
              onPressed: onRemove,
              visualDensity: VisualDensity.compact,
              tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
              icon: const Icon(
                Icons.close_rounded,
                color: Color(0xFF9AA59F),
                size: 18,
              ),
            ),
        ],
      ),
    );
  }
}
