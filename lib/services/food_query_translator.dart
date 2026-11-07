import 'dart:convert';

import 'package:http/http.dart' as http;

import '../data/uzbek_food_map.dart';

class FoodQueryTranslator {
  FoodQueryTranslator({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;
  final Map<String, String> _cache = {};

  Future<String> localizeEnglish(String raw, String languageCode) async {
    final original = raw.trim();
    if (original.isEmpty || languageCode == 'en') return original;
    final normalized = _normalize(original);

    if (languageCode == 'uz') {
      final exact = kUzbekFoodMap.entries
          .where((entry) => _normalize(entry.value) == normalized)
          .map((entry) => entry.key)
          .where(
            (value) => !RegExp(r'[а-яё]', caseSensitive: false).hasMatch(value),
          )
          .toList(growable: false);
      if (exact.isNotEmpty) {
        exact.sort((a, b) => a.length.compareTo(b.length));
        return exact.first;
      }
    }

    final cacheKey = '$languageCode:$normalized';
    final cached = _cache[cacheKey];
    if (cached != null) return cached;
    final translated = await _translateOnline(
      original,
      sourceLanguage: 'en',
      targetLanguage: languageCode,
    );
    final result = translated?.trim().isNotEmpty == true
        ? translated!.trim()
        : original;
    _cache[cacheKey] = result;
    return result;
  }

  /// Qidiruv uchun inglizcha so‘rov va (ixtiyoriy) o‘zbekcha ko‘rsatish nomi.
  Future<TranslatedQuery> translate(String raw) async {
    final original = raw.trim();
    if (original.isEmpty) {
      return const TranslatedQuery(english: '', localLabel: '');
    }

    final normalized = _normalize(original);
    final fromMap = _lookupMap(normalized);
    if (fromMap != null) {
      return TranslatedQuery(english: fromMap, localLabel: original);
    }

    if (_isMostlyLatin(normalized) && !_looksUzbekLatin(normalized)) {
      return TranslatedQuery(english: original, localLabel: original);
    }

    final cached = _cache[normalized];
    if (cached != null) {
      return TranslatedQuery(english: cached, localLabel: original);
    }

    final online = await _translateOnline(
      original,
      sourceLanguage: _looksRussian(normalized) ? 'ru' : 'uz',
    );
    if (online != null && online.trim().isNotEmpty) {
      _cache[normalized] = online.trim();
      return TranslatedQuery(english: online.trim(), localLabel: original);
    }

    // Fallback: lug‘atdan qisman moslik
    final partial = _partialLookup(normalized);
    if (partial != null) {
      return TranslatedQuery(english: partial, localLabel: original);
    }

    return TranslatedQuery(english: original, localLabel: original);
  }

  String? _lookupMap(String normalized) {
    final direct = kUzbekFoodMap[normalized];
    if (direct != null) return direct;

    // Apostrof variantlari
    final collapsed = normalized
        .replaceAll("'", '')
        .replaceAll('ʻ', '')
        .replaceAll('ʼ', '');
    for (final entry in kUzbekFoodMap.entries) {
      final key = entry.key
          .replaceAll("'", '')
          .replaceAll('ʻ', '')
          .replaceAll('ʼ', '')
          .replaceAll('ʻ', '');
      if (_normalize(key) == collapsed || _normalize(entry.key) == normalized) {
        return entry.value;
      }
    }
    return null;
  }

  String? _partialLookup(String normalized) {
    String? best;
    var bestLen = 0;
    for (final entry in kUzbekFoodMap.entries) {
      final key = _normalize(entry.key);
      if (normalized.contains(key) && key.length > bestLen) {
        best = entry.value;
        bestLen = key.length;
      }
    }
    return best;
  }

  Future<String?> _translateOnline(
    String text, {
    required String sourceLanguage,
    String targetLanguage = 'en',
  }) async {
    try {
      final uri = Uri.https('api.mymemory.translated.net', '/get', {
        'q': text,
        'langpair': '$sourceLanguage|$targetLanguage',
      });
      final response = await _client
          .get(uri)
          .timeout(const Duration(seconds: 6));
      if (response.statusCode != 200) return null;
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final translated =
          (body['responseData'] as Map<String, dynamic>?)?['translatedText']
              as String?;
      if (translated == null) return null;
      // MyMemory ba'zan bir xil matnni qaytaradi
      if (_normalize(translated) == _normalize(text)) return null;
      return translated;
    } catch (_) {
      return null;
    }
  }

  String _normalize(String input) {
    var s = input.toLowerCase().trim();
    s = s
        .replaceAll('ʻ', "'")
        .replaceAll('ʼ', "'")
        .replaceAll('`', "'")
        .replaceAll('‘', "'")
        .replaceAll('’', "'")
        .replaceAll('ў', "o'")
        .replaceAll('қ', 'q')
        .replaceAll('ғ', "g'")
        .replaceAll('ҳ', 'h')
        .replaceAll('ө', "o'")
        .replaceAll(RegExp(r'\s+'), ' ');
    return s;
  }

  bool _isMostlyLatin(String s) {
    final letters = s.replaceAll(RegExp(r'[^a-zA-Zа-яА-ЯёЁўқғҳЎҚҒҲ]'), '');
    if (letters.isEmpty) return true;
    final latin = letters.replaceAll(RegExp(r'[^a-zA-Z]'), '').length;
    return latin / letters.length > 0.7;
  }

  bool _looksUzbekLatin(String s) {
    const markers = [
      "o'",
      "g'",
      'sh',
      'ch',
      'ng',
      'qatiq',
      'non',
      'osh',
      'palov',
      'tovuq',
      'gosht',
      "go'sht",
      'sut',
      'olma',
      'banan',
      'guruch',
      'kartoshka',
      'pomidor',
      'bodring',
      'manti',
      'somsa',
      'shorva',
      "sho'rva",
      'lagmon',
      'choy',
      'tuxum',
      'pishloq',
      'sabzi',
      'piyoz',
    ];
    return markers.any(s.contains);
  }

  bool _looksRussian(String value) =>
      RegExp(r'[а-яё]', caseSensitive: false).hasMatch(value) &&
      !RegExp(r'[ўқғҳ]', caseSensitive: false).hasMatch(value);
}

class TranslatedQuery {
  const TranslatedQuery({required this.english, required this.localLabel});

  final String english;
  final String localLabel;
}
