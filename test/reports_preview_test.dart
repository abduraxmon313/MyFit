import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myfit/l10n/app_localizations.dart';
import 'package:myfit/models/food_nutrition.dart';
import 'package:myfit/screens/reports_page.dart';
import 'package:myfit/services/food_log_service.dart';
import 'package:myfit/theme/app_theme.dart';

class PreviewReportLogs implements FoodLogService {
  @override
  Future<Map<DateTime, List<FoodNutrition>>> loadRange(
    String uid,
    DateTime start,
    DateTime end,
  ) async => {
    for (var i = 0; i < 4; i++)
      DateTime(2025, 9, 22 + i): [
        for (final meal in ['breakfast', 'lunch', 'dinner', 'snack'])
          FoodNutrition(
            fdcId: meal.hashCode,
            name: 'Ovqat',
            calories: (350 + i * 55).toDouble(),
            protein: 24,
            carbohydrates: 36,
            fat: 12,
            water: 0,
            mealType: meal,
          ),
      ],
  };
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('export reports design previews', (tester) async {
    final directory = Platform.environment['MYFIT_PREVIEW_DIR'];
    if (directory == null) return;
    final font = FontLoader('PreviewFont')
      ..addFont(
        Future.value(
          ByteData.sublistView(
            File('C:/Windows/Fonts/arial.ttf').readAsBytesSync(),
          ),
        ),
      );
    await font.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(430, 1250);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    for (final dark in [true, false]) {
      final theme = dark ? AppTheme.dark : AppTheme.light;
      final boundary = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          theme: theme.copyWith(
            textTheme: theme.textTheme.apply(fontFamily: 'PreviewFont'),
          ),
          locale: const Locale('uz'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: RepaintBoundary(
            key: boundary,
            child: Scaffold(
              body: ReportsPage(
                uid: 'preview',
                service: PreviewReportLogs(),
                dailyTarget: 2200,
                initialDate: DateTime(2025, 9, 25),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        final image =
            await (boundary.currentContext!.findRenderObject()
                    as RenderRepaintBoundary)
                .toImage(pixelRatio: 2);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        Directory(directory).createSync(recursive: true);
        File(
          '$directory/reports-${dark ? 'midnight' : 'light'}.png',
        ).writeAsBytesSync(data!.buffer.asUint8List());
        image.dispose();
      });
    }
  });
}
