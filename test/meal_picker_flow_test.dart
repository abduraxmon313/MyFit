import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myfit/l10n/app_localizations.dart';
import 'package:myfit/models/food_nutrition.dart';
import 'package:myfit/screens/meals_page.dart';
import 'package:myfit/screens/national_food_picker_page.dart';
import 'package:myfit/services/food_data_service.dart';
import 'package:myfit/services/search_history_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Offline extends FoodDataService {
  @override
  Future<List<FoodNutrition>> search(
    String query, {
    String languageCode = 'uz',
  }) async => [];
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'History keeps the chosen food, not the typed fragment; no categories',
    (tester) async {
      List<FoodNutrition>? result;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('uz'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                child: const Text('Open'),
                onPressed: () async {
                  result = await Navigator.push<List<FoodNutrition>>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => NationalFoodPickerPage(
                        meal: MealType.breakfast,
                        foodDataService: _Offline(),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('Kategoriyalar'), findsNothing);

      await tester.enterText(find.byType(TextField), 'tux');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Oddiy tuxum').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Saqlash'));
      await tester.pumpAndSettle();

      final history = SearchHistoryStore.shared.items;
      expect(history, contains('Oddiy tuxum'));
      expect(history, isNot(contains('tux')));
      expect(result, isNull);

      await tester.tap(find.byKey(const Key('basket-add')));
      await tester.pumpAndSettle();
      expect(result, hasLength(1));
      expect(tester.takeException(), isNull);
    },
  );
}
