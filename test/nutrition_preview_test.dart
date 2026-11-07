import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myfit/data/uzbek_food_catalog.dart';
import 'package:myfit/l10n/app_localizations.dart';
import 'package:myfit/theme/app_theme.dart';
import 'package:myfit/widgets/nutrition_facts.dart';

void main() {
  testWidgets('Export nutrition design preview', (tester) async {
    final directory = Platform.environment['MYFIT_PREVIEW_DIR'];
    if (directory == null) return;
    final font = FontLoader('Roboto');
    for (final path in [
      'C:/Windows/Fonts/arial.ttf',
      'C:/Windows/Fonts/arialbd.ttf',
    ]) {
      font.addFont(
        Future.value(ByteData.sublistView(File(path).readAsBytesSync())),
      );
    }
    await font.load();
    final icons = FontLoader('MaterialIcons');
    icons.addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(430, 1200);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final boundary = GlobalKey();
    final food = kUzbekDishes
        .firstWhere((d) => d.nutrition.name == 'Leccino Olive Oil')
        .nutrition;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light.copyWith(
          textTheme: AppTheme.light.textTheme.apply(fontFamily: 'Roboto'),
        ),
        locale: const Locale('uz'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: RepaintBoundary(
          key: boundary,
          child: Scaffold(
            body: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              child: NutritionFacts(food: food, portion: '100 g'),
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
        '$directory/nutrition-redesign.png',
      ).writeAsBytesSync(data!.buffer.asUint8List());
      image.dispose();
    });
  });
}
