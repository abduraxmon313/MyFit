import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'firebase_options.dart';
import 'theme/app_theme.dart';
import 'l10n/app_localizations.dart';
import 'screens/auth_gate.dart';
import 'services/auth_service.dart';
import 'services/profile_service.dart';
import 'services/appearance_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final appearanceStore = AppearanceStore();
  final initialAppearance = await appearanceStore.load();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  SystemChrome.setSystemUIOverlayStyle(
    AppTheme.systemOverlay(
      initialAppearance == 'light' ? AppTheme.light : AppTheme.dark,
    ),
  );
  runApp(
    MyFitApp(
      authService: AuthService(),
      profileService: ProfileService(),
      initialAppearance: initialAppearance,
      appearanceStore: appearanceStore,
    ),
  );
}

class MyFitApp extends StatefulWidget {
  const MyFitApp({
    super.key,
    required this.authService,
    required this.profileService,
    this.initialAppearance,
    this.appearanceStore,
  });

  final AuthService authService;
  final ProfileService profileService;
  final String? initialAppearance;
  final AppearanceStore? appearanceStore;

  @override
  State<MyFitApp> createState() => _MyFitAppState();
}

class _MyFitAppState extends State<MyFitApp> {
  Locale? _locale;
  late ThemeMode _themeMode;
  late bool _hasLocalPreference;

  @override
  void initState() {
    super.initState();
    _hasLocalPreference = widget.initialAppearance != null;
    _themeMode = widget.initialAppearance == 'light'
        ? ThemeMode.light
        : ThemeMode.dark;
  }

  void _setTheme(String mode) {
    _hasLocalPreference = true;
    final next = mode == 'dark' ? ThemeMode.dark : ThemeMode.light;
    if (_themeMode == next) return;
    setState(() => _themeMode = next);
  }

  void _restoreProfileTheme(String mode) {
    if (_hasLocalPreference) return;
    _setTheme(mode);
    unawaited(
      (widget.appearanceStore ?? AppearanceStore())
          .save(mode)
          .catchError((Object _) {}),
    );
  }

  void _setLocale(String languageCode) {
    final next = Locale(languageCode);
    if (_locale == next) return;
    setState(() => _locale = next);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MyFit',
      debugShowCheckedModeBanner: false,
      locale: _locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: _themeMode,
      themeAnimationDuration: const Duration(milliseconds: 220),
      builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: AppTheme.systemOverlay(Theme.of(context)),
        child: child!,
      ),
      home: AuthGate(
        authService: widget.authService,
        profileService: widget.profileService,
        onLocaleChanged: _setLocale,
        onThemeChanged: _setTheme,
        onProfileThemeChanged: _restoreProfileTheme,
      ),
    );
  }
}
