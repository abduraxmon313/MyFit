import 'package:shared_preferences/shared_preferences.dart';

/// Remembers that sign-up was started but the profile was not finished.
///
/// If the app is fully closed in that state, the next cold start begins
/// again from the language screen instead of resuming half-way.
class OnboardingStore {
  static const storageKey = 'myfit.onboarding.inProgress.v1';

  Future<bool> isInProgress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(storageKey) ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> setInProgress(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (value) {
        await prefs.setBool(storageKey, true);
      } else {
        await prefs.remove(storageKey);
      }
    } catch (_) {
      // Best effort: a failed write only affects the next cold start.
    }
  }
}
