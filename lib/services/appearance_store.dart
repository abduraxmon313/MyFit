import 'package:shared_preferences/shared_preferences.dart';

/// Device preference is authoritative; cloud profile is a first-run fallback.
class AppearanceStore {
  static const storageKey = 'myfit.appearance.mode.v1';

  Future<String?> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final mode = prefs.getString(storageKey);
      return mode == 'light' || mode == 'dark' ? mode : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> save(String mode) async {
    if (mode != 'light' && mode != 'dark') {
      throw ArgumentError.value(mode, 'mode');
    }
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(storageKey, mode)) {
      throw StateError('Appearance preference could not be saved');
    }
  }
}
