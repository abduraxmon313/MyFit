import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Device-local history shared by the two food search screens.
class SearchHistoryStore extends ChangeNotifier {
  static final shared = SearchHistoryStore();
  // Older history included every intermediate and unsuccessful query.
  static const storageKey = 'myfit.food_search_history.v2';
  static const limit = 30;
  List<String> _items = const [];
  List<String> get items => List.unmodifiable(_items);
  bool failed = false;
  Future<void> _pending = Future.value();

  Future<void> _run(List<String> Function(List<String>)? change) {
    // Serialize reads and writes so rapid search/delete actions cannot resurrect
    // deleted entries or overwrite a newer query.
    _pending = _pending.then((_) async {
      try {
        final prefs = await SharedPreferences.getInstance();
        final stored = prefs.getStringList(storageKey) ?? <String>[];
        final next = change == null ? stored : change(List.of(stored));
        if (change != null && !await prefs.setStringList(storageKey, next)) {
          throw StateError('History write failed');
        }
        _items = next;
        failed = false;
      } catch (_) {
        failed = true;
      }
      notifyListeners();
    });
    return _pending;
  }

  Future<void> load() => _run(null);

  /// Save only queries whose complete words occur in a returned food name.
  /// Substring results (for example `gur` matching `guruch`) are not history.
  Future<void> addSuccessful(String text, Iterable<String> foodNames) {
    List<String> words(String value) => value
        .toLowerCase()
        .split(RegExp(r'[^\p{L}\p{N}]+', unicode: true))
        .where((word) => word.isNotEmpty)
        .toList();

    final queryWords = words(text);
    if (queryWords.isEmpty) return Future.value();
    final matches = foodNames.any((name) {
      final nameWords = words(name).toSet();
      return queryWords.every(nameWords.contains);
    });
    return matches ? add(text) : Future.value();
  }

  Future<void> add(String text) {
    final query = text.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (query.length < 2) return Future.value();
    return _run(
      (items) => [
        query,
        ...items.where((item) => item.toLowerCase() != query.toLowerCase()),
      ].take(limit).toList(),
    );
  }

  Future<void> remove(String query) =>
      _run((items) => items.where((item) => item != query).toList());
  Future<void> clear() => _run((_) => []);
}
