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
import 'services/locale_store.dart';
import 'services/onboarding_store.dart';
import 'screens/language_picker_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final appearanceStore = AppearanceStore();
  final initialAppearance = await appearanceStore.load();
  final localeStore = LocaleStore();
  final initialLocale = await localeStore.load();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  SystemChrome.setSystemUIOverlayStyle(
    AppTheme.systemOverlay(
      initialAppearance == 'dark' ? AppTheme.dark : AppTheme.light,
    ),
  );
  final authService = AuthService();
  // Ro'yxatdan o'tish oxiriga yetmay ilova yopilgan bo'lsa, qaytadan
  // til tanlashdan boshlanadi.
  final onboarding = OnboardingStore();
  if (await onboarding.isInProgress()) {
    if (authService.currentUser != null) {
      try {
        await authService.signOut();
      } catch (_) {}
    }
    await onboarding.setInProgress(false);
  }
  runApp(
    MyFitApp(
      authService: authService,
      profileService: ProfileService(),
      initialAppearance: initialAppearance,
      appearanceStore: appearanceStore,
      initialLocale: initialLocale,
      localeStore: localeStore,
      // Kirilmagan bo'lsa, ilova til tanlashdan boshlanadi.
      askLanguage: authService.currentUser == null,
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
    this.initialLocale,
    this.localeStore,
    this.askLanguage = false,
  });

  final AuthService authService;
  final ProfileService profileService;
  final String? initialAppearance;
  final AppearanceStore? appearanceStore;
  final String? initialLocale;
  final LocaleStore? localeStore;
  final bool askLanguage;

  @override
  State<MyFitApp> createState() => _MyFitAppState();
}

class _MyFitAppState extends State<MyFitApp> {
  Locale? _locale;
  late ThemeMode _themeMode;
  late bool _hasLocalPreference;
  late bool _askLanguage;

  @override
  void initState() {
    super.initState();
    _hasLocalPreference = widget.initialAppearance != null;
    // Birinchi ochilishda yorug' rejim; foydalanuvchi keyin o'zgartiradi.
    _themeMode = widget.initialAppearance == 'dark'
        ? ThemeMode.dark
        : ThemeMode.light;
    final initial = widget.initialLocale;
    if (initial != null) _locale = Locale(initial);
    _askLanguage = widget.askLanguage;
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
    if (_locale == next && !_askLanguage) return;
    unawaited(
      (widget.localeStore ?? LocaleStore())
          .save(languageCode)
          .catchError((Object _) {}),
    );
    setState(() {
      _locale = next;
      _askLanguage = false;
    });
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
      home: _askLanguage
          ? LanguagePickerPage(
              initialCode: _locale?.languageCode,
              onSelected: _setLocale,
            )
          : AuthGate(
              authService: widget.authService,
              profileService: widget.profileService,
              onLocaleChanged: _setLocale,
              onThemeChanged: _setTheme,
              onProfileThemeChanged: _restoreProfileTheme,
            ),
    );
  }
}
