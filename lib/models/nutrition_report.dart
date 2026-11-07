import 'food_nutrition.dart';

enum ReportPeriod { day, week, month }

/// Calendar boundaries use local dates, including across DST and year changes.
class ReportRange {
  ReportRange(DateTime anchor, this.period) {
    final day = DateTime(anchor.year, anchor.month, anchor.day);
    start = switch (period) {
      ReportPeriod.day => day,
      ReportPeriod.week => DateTime(
        day.year,
        day.month,
        day.day - day.weekday + 1,
      ),
      ReportPeriod.month => DateTime(day.year, day.month),
    };
    end = switch (period) {
      ReportPeriod.day => DateTime(start.year, start.month, start.day + 1),
      ReportPeriod.week => DateTime(start.year, start.month, start.day + 7),
      ReportPeriod.month => DateTime(start.year, start.month + 1),
    };
  }
  final ReportPeriod period;
  late final DateTime start;
  late final DateTime end; // Exclusive.

  List<DateTime> get days {
    final result = <DateTime>[];
    for (
      var day = start;
      day.isBefore(end);
      day = DateTime(day.year, day.month, day.day + 1)
    ) {
      result.add(day);
    }
    return result;
  }

  DateTime adjacent(int direction) => switch (period) {
    ReportPeriod.day => DateTime(
      start.year,
      start.month,
      start.day + direction,
    ),
    ReportPeriod.week => DateTime(
      start.year,
      start.month,
      start.day + 7 * direction,
    ),
    ReportPeriod.month => DateTime(start.year, start.month + direction),
  };
}

class NutritionTotals {
  double calories = 0, protein = 0, carbs = 0, fat = 0;
  int entries = 0;
  final missing = <String>{};

  void add(FoodNutrition food) {
    entries++;
    double value(String key, double number) {
      if (food.missingNutrients.contains(key) ||
          !number.isFinite ||
          number < 0) {
        missing.add(key);
        return 0;
      }
      return number;
    }

    // Saved values already describe the selected portion, not 100 g.
    calories += value('calories', food.calories);
    protein += value('protein', food.protein);
    carbs += value('carbohydrates', food.carbohydrates);
    fat += value('fat', food.fat);
  }
}

class ReportFood {
  ReportFood(this.food);
  final FoodNutrition food;
  final totals = NutritionTotals();
  double amount = 0;
}

class NutritionReport {
  NutritionReport({
    required this.range,
    required Map<DateTime, List<FoodNutrition>> logs,
    required DateTime today,
  }) {
    final cutoff = DateTime(today.year, today.month, today.day);
    for (final day in range.days) {
      if (day.isAfter(cutoff)) continue;
      final foods = logs[day] ?? const <FoodNutrition>[];
      final daily = NutritionTotals();
      for (final food in foods) {
        totals.add(food);
        daily.add(food);
        final meal = mealKeys.contains(food.mealType)
            ? food.mealType!
            : 'snack';
        meals[meal]!.add(food);
        // Keep different products and mass/volume units separate.
        final key = (food.fdcId, food.name, food.basisUnit);
        final product = products.putIfAbsent(key, () => ReportFood(food));
        product.totals.add(food);
        if (food.grams.isFinite && food.grams >= 0) {
          product.amount += food.grams;
        }
      }
      dailyTotals[day] = daily;
      if (foods.isNotEmpty) loggedDays++;
    }
  }
  static const mealKeys = [
    'breakfast',
    'lunch',
    'dinner',
    'fifthSnack',
    'snack',
  ];
  final ReportRange range;
  final totals = NutritionTotals();
  final dailyTotals = <DateTime, NutritionTotals>{};
  final meals = {for (final key in mealKeys) key: NutritionTotals()};
  final products = <(int, String, String), ReportFood>{};
  int loggedDays = 0;
  int get elapsedDays => dailyTotals.length;
  double get dailyAverage =>
      elapsedDays == 0 ? 0 : totals.calories / elapsedDays;
  double get loggedAverage =>
      loggedDays == 0 ? 0 : totals.calories / loggedDays;
}
