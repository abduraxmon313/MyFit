import 'package:flutter_test/flutter_test.dart';
import 'package:myfit/models/food_nutrition.dart';
import 'package:myfit/models/nutrition_report.dart';

FoodNutrition food({
  double calories = 123.45,
  String? meal,
  String unit = 'g',
  Set<String> missing = const {},
}) => FoodNutrition(
  fdcId: 1,
  name: 'Food',
  calories: calories,
  protein: 12.3,
  fat: 4.5,
  carbohydrates: 6.7,
  water: 0,
  grams: 250,
  mealType: meal,
  basisUnit: unit,
  missingNutrients: missing,
);

void main() {
  test('calendar periods cross years and leap months without date drift', () {
    final week = ReportRange(DateTime(2026, 1, 1), ReportPeriod.week);
    expect(week.start, DateTime(2025, 12, 29));
    expect(week.end, DateTime(2026, 1, 5));
    expect(week.days.length, 7);
    final month = ReportRange(DateTime(2024, 2, 29), ReportPeriod.month);
    expect(month.days.length, 29);
    expect(month.adjacent(1), DateTime(2024, 3, 1));
    expect(
      ReportRange(DateTime(2026, 1, 31), ReportPeriod.month).adjacent(1),
      DateTime(2026, 2, 1),
    );
  });

  test(
    'portions sum once; empty elapsed days count and future days do not',
    () {
      final report = NutritionReport(
        range: ReportRange(DateTime(2026, 10, 29), ReportPeriod.week),
        today: DateTime(2026, 10, 29),
        logs: {
          DateTime(2026, 10, 26): [
            food(meal: 'breakfast'),
            food(meal: 'unknown'),
          ],
          DateTime(2026, 10, 29): [food(calories: 10)],
          DateTime(2026, 10, 30): [food(calories: 9999)],
        },
      );
      expect(report.totals.calories, closeTo(256.9, .000001));
      expect(report.dailyAverage, closeTo(64.225, .000001));
      expect(report.loggedAverage, closeTo(128.45, .000001));
      expect(report.elapsedDays, 4);
      expect(report.loggedDays, 2);
      expect(report.meals['snack']!.entries, 2);
      expect(report.products.values.single.amount, 750);
      expect(report.products.values.single.totals.entries, 3);
    },
  );

  test(
    'mass and volume stay separate; incomplete and invalid values are flagged',
    () {
      final day = DateTime(2026, 10, 29);
      final report = NutritionReport(
        range: ReportRange(day, ReportPeriod.day),
        today: day,
        logs: {
          day: [
            food(missing: {'calories'}),
            food(unit: 'ml'),
            food(calories: double.nan),
          ],
        },
      );
      expect(report.products.length, 2);
      expect(report.totals.calories, 123.45);
      expect(report.totals.missing, contains('calories'));
      expect(report.totals.protein, closeTo(36.9, .000001));
    },
  );

  test('empty report has finite zero averages', () {
    final report = NutritionReport(
      range: ReportRange(DateTime(2026, 1), ReportPeriod.month),
      logs: {},
      today: DateTime(2026, 2),
    );
    expect(report.dailyAverage, 0);
    expect(report.loggedAverage, 0);
    expect(report.elapsedDays, 31);
  });
}
