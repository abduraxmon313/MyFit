import 'package:shared_preferences/shared_preferences.dart';

/// Language chosen on this device. Asked once on first launch, before login.
class LocaleStore {
  static const storageKey = 'myfit.locale.v1';
  static const supported = {'uz', 'ru', 'en'};

  Future<String?> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final code = prefs.getString(storageKey);
      return supported.contains(code) ? code : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> save(String code) async {
    if (!supported.contains(code)) throw ArgumentError.value(code, 'code');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(storageKey, code);
  }
}
