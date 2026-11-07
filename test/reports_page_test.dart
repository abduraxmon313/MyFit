import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myfit/l10n/app_localizations.dart';
import 'package:myfit/models/food_nutrition.dart';
import 'package:myfit/screens/reports_page.dart';
import 'package:myfit/services/food_log_service.dart';
import 'package:myfit/theme/app_theme.dart';

class ReportLogs implements FoodLogService {
  final requests = <Completer<Map<DateTime, List<FoodNutrition>>>>[];
  @override
  Future<Map<DateTime, List<FoodNutrition>>> loadRange(
    String uid,
    DateTime start,
    DateTime end,
  ) {
    final request = Completer<Map<DateTime, List<FoodNutrition>>>();
    requests.add(request);
    return request.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const food = FoodNutrition(
  fdcId: 1,
  name: 'Egg',
  calories: 123.4,
  protein: 10,
  fat: 5,
  carbohydrates: 1,
  water: 0,
  grams: 80,
);

void main() {
  for (final dark in [false, true]) {
    testWidgets('reports render at 320px in ${dark ? 'dark' : 'light'} theme', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 850);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final logs = ReportLogs();
      await tester.pumpWidget(
        MaterialApp(
          theme: dark ? AppTheme.dark : AppTheme.light,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('uz'),
          home: Scaffold(
            body: ReportsPage(
              uid: 'u',
              service: logs,
              dailyTarget: 2000,
              initialDate: DateTime(2025, 9, 25),
            ),
          ),
        ),
      );
      logs.requests.single.complete({
        DateTime(2025, 9, 25): [food],
      });
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('report-total')), findsOneWidget);
      expect(find.text('123'), findsOneWidget);
      await tester.drag(find.byType(ListView).first, const Offset(0, -550));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.drag(find.byType(ListView).first, const Offset(0, 1200));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Oylik'));
      await tester.pump();
      logs.requests.last.complete({});
      await tester.pumpAndSettle();
      expect(find.text('Bu davrda ovqat yozuvlari yo‘q.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('stale responses cannot replace a new period; failures retry', (
    tester,
  ) async {
    final logs = ReportLogs();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReportsPage(
            uid: 'u',
            service: logs,
            dailyTarget: 2000,
            initialDate: DateTime(2025, 9, 25),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Oylik'));
    await tester.pump();
    logs.requests.last.completeError(StateError('offline'));
    await tester.pumpAndSettle();
    expect(find.text('Hisobotni yuklab bo‘lmadi.'), findsOneWidget);
    logs.requests.first.complete({
      DateTime(2025, 9, 25): [food],
    });
    await tester.pumpAndSettle();
    expect(find.text('Hisobotni yuklab bo‘lmadi.'), findsOneWidget);
    await tester.tap(find.text('Qayta urinish'));
    await tester.pump();
    logs.requests.last.complete({});
    await tester.pumpAndSettle();
    expect(find.text('Bu davrda ovqat yozuvlari yo‘q.'), findsOneWidget);
  });
}
