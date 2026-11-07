import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myfit/l10n/app_localizations.dart';
import 'package:myfit/models/user_profile.dart';
import 'package:myfit/screens/profile_page.dart';
import 'package:myfit/theme/app_theme.dart';

void main() {
  testWidgets('export redesigned profile previews', (tester) async {
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
    tester.view.physicalSize = const Size(430, 1500);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    const profile = UserProfile(
      firstName: 'Aziz',
      lastName: 'Karimov',
      gender: 'male',
      age: 28,
      heightCm: 178,
      weightKg: 75,
      activityLevel: 'medium',
      goal: 'maintain',
    );
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
              body: ProfilePage(
                profile: profile,
                phoneNumber: '+998 90 123 45 67',
                onSave: (_) async {},
                onSignOut: () async {},
                onPhotoUpload: (_) async => 'unused',
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
          '$directory/profile-${dark ? 'midnight' : 'light'}.png',
        ).writeAsBytesSync(data!.buffer.asUint8List());
        image.dispose();
      });
    }
  });
}
