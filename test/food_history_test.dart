import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myfit/models/food_nutrition.dart';
import 'package:myfit/screens/food_history_page.dart';
import 'package:myfit/screens/meals_page.dart';
import 'package:myfit/services/food_log_service.dart';

class HistoryLogs implements FoodLogService {
  final requests = <DateTime, Completer<List<FoodNutrition>>>{};
  @override
  Future<List<FoodNutrition>> loadDay(String uid, DateTime day) =>
      (requests[day] = Completer<List<FoodNutrition>>()).future;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const egg = FoodNutrition(
  fdcId: 1,
  name: 'Egg',
  calories: 65,
  protein: 5.54,
  fat: 4.37,
  carbohydrates: .34,
  water: 30,
  grams: 44,
  mealType: 'breakfast',
);

void main() {
  testWidgets('Weekly Monday circle opens the corresponding date', (
    tester,
  ) async {
    DateTime? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MealsPage(
            onMealSelected: (_) {},
            onDateSelected: (date) => selected = date,
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('week-day-0')));
    final now = DateTime.now();
    expect(selected, DateTime(now.year, now.month, now.day - now.weekday + 1));
    expect(find.byTooltip('Kalendar'), findsOneWidget);
  });

  testWidgets(
    'Selected date shows its foods and stale requests cannot replace it',
    (tester) async {
      final logs = HistoryLogs();
      final initial = DateTime(2025, 9, 25);
      await tester.pumpWidget(
        MaterialApp(
          home: FoodHistoryPage(
            uid: 'test-user',
            initialDate: initial,
            service: logs,
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('history-day-0')));
      final monday = DateTime(2025, 9, 22);
      logs.requests[monday]!.complete([egg]);
      await tester.pumpAndSettle();
      expect(find.text('Egg'), findsOneWidget);
      expect(find.text('65 kcal'), findsOneWidget);
      logs.requests[initial]!.complete([]);
      await tester.pumpAndSettle();
      expect(find.text('Egg'), findsOneWidget);
      await tester.tap(find.text('Egg'));
      await tester.pumpAndSettle();
      expect(find.text('5.54 g'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Calendar switches date, empty history differs from load failure',
    (tester) async {
      final logs = HistoryLogs();
      final initial = DateTime(2025, 9, 22);
      await tester.pumpWidget(
        MaterialApp(
          home: FoodHistoryPage(
            uid: 'test-user',
            initialDate: initial,
            service: logs,
          ),
        ),
      );
      logs.requests[initial]!.completeError(Exception('Offline'));
      await tester.pumpAndSettle();
      expect(find.text('Tarixni yuklab bo‘lmadi.'), findsOneWidget);
      await tester.tap(find.byTooltip('Kalendar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('25').last);
      await tester.tap(find.text('OK'));
      await tester.pump();
      logs.requests[DateTime(2025, 9, 25)]!.complete([]);
      await tester.pumpAndSettle();
      expect(find.text('Bu kunda ovqat saqlanmagan.'), findsOneWidget);
      expect(find.text('Tarixni yuklab bo‘lmadi.'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
