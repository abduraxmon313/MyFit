import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../services/profile_service.dart';
import 'home_page.dart';
import 'profile_setup_page.dart';
import 'phone_login_page.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({
    super.key,
    required this.authService,
    required this.profileService,
    required this.onLocaleChanged,
    this.onThemeChanged,
    this.onProfileThemeChanged,
  });

  final AuthService authService;
  final ProfileService profileService;
  final ValueChanged<String> onLocaleChanged;
  final ValueChanged<String>? onThemeChanged;
  final ValueChanged<String>? onProfileThemeChanged;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late Stream<User?> _authStream;
  Stream<UserProfile?>? _profileStream;
  String? _profileUid;
  String? _appliedTheme;

  @override
  void initState() {
    super.initState();
    _authStream = widget.authService.authStateChanges();
  }

  @override
  void didUpdateWidget(covariant AuthGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.authService != widget.authService) {
      _authStream = widget.authService.authStateChanges();
      _profileUid = null;
      _profileStream = null;
    }
    if (oldWidget.profileService != widget.profileService) {
      _profileUid = null;
      _profileStream = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _authStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data;
        if (user == null) {
          _profileUid = null;
          _appliedTheme = null;
          _profileStream = null;
          return PhoneLoginPage(authService: widget.authService);
        }
        if (_profileUid != user.uid || _profileStream == null) {
          _profileUid = user.uid;
          _appliedTheme = null;
          _profileStream = widget.profileService.watchProfile(user.uid);
        }
        return StreamBuilder<UserProfile?>(
          key: ValueKey(user.uid),
          stream: _profileStream,
          builder: (context, profileSnapshot) {
            if (profileSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            if (profileSnapshot.hasError) {
              return Scaffold(
                body: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      context.tr('Profilni yuklashda xatolik:\n{error}', {
                        'error': profileSnapshot.error ?? '',
                      }),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              );
            }

            final profile = profileSnapshot.data;
            if (profile == null) {
              return ProfileSetupPage(
                uid: user.uid,
                profileService: widget.profileService,
              );
            }
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              widget.onLocaleChanged(profile.languageCode);
              if (_appliedTheme != profile.themeMode) {
                _appliedTheme = profile.themeMode;
                (widget.onProfileThemeChanged ?? widget.onThemeChanged)?.call(
                  profile.themeMode,
                );
              }
            });
            return HomePage(
              authService: widget.authService,
              profile: profile,
              onLocaleChanged: widget.onLocaleChanged,
              onThemeChanged: widget.onThemeChanged,
            );
          },
        );
      },
    );
  }
}
