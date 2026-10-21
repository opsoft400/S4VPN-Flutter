import 'maps.g.dart';

/// The six languages the preview ships, in the order they appear in the
/// language picker.
const List<String> kSupportedLanguages = <String>['fa', 'en', 'zh', 'ja', 'de', 'ru'];

/// Languages written right to left.
const Set<String> kRtlLanguages = <String>{'fa'};

/// Reproduces the preview's translation algorithm exactly.
///
/// Every string in the settings model is authored in Persian. [faToEn] turns a
/// Persian phrase into English -- whole-string first, then longest-phrase-first
/// replacement so a short word nested inside a longer label can never cut the
/// sentence apart. [enToLang] then carries that English string into the target
/// language, again longest-first, and anything it does not know simply stays
/// English rather than falling back to Persian.
class Translator {
  Translator(this.language) : assert(kSupportedLanguages.contains(language));

  final String language;

  static final Map<String, List<String>> _englishKeys = <String, List<String>>{};
  static final Map<String, List<String>> _langKeys = <String, List<String>>{};
  static final Map<String, String> _cache = <String, String>{};

  static List<String> _sortedLongestFirst(Iterable<String> keys) {
    final List<String> list = keys.toList()
      ..sort((String a, String b) => b.length.compareTo(a.length));
    return list;
  }

  /// Warm the lookup tables once, before the first frame builds a label.
  static void prime() {
    if (_englishKeys.isNotEmpty) return;
    _englishKeys['fa'] = _sortedLongestFirst(faToEn.keys);
    for (final MapEntry<String, Map<String, String>> entry in enToLang.entries) {
      _langKeys[entry.key] = _sortedLongestFirst(entry.value.keys);
    }
  }

  static String _replaceAll(String source, Map<String, String> map, List<String> keys) {
    String out = source;
    for (final String key in keys) {
      out = out.replaceAll(key, map[key]!);
    }
    return out;
  }

  /// Persian -> English, the neutral form every other language is keyed from.
  static String toEnglish(String source) {
    prime();
    if (faToEn.containsKey(source)) return faToEn[source]!;
    return _replaceAll(source, faToEn, _englishKeys['fa']!);
  }

  /// A chrome label (nav item, status word) authored straight per language.
  /// Labels the preview did not have, added by this app.
  static const Map<String, Map<String, String>> extraChrome =
      <String, Map<String, String>>{
    'fa': <String, String>{'rewards': 'جایزه'},
    'en': <String, String>{'rewards': 'Rewards'},
    'zh': <String, String>{'rewards': '奖励'},
    'ja': <String, String>{'rewards': 'リワード'},
    'de': <String, String>{'rewards': 'Belohnungen'},
    'ru': <String, String>{'rewards': 'Награды'},
  };

  static String chrome(String key, String lang) {
    final Map<String, String>? forLang = langChrome[lang];
    final Map<String, String>? extra = extraChrome[lang];
    if (forLang != null && forLang.containsKey(key)) return forLang[key]!;
    if (extra != null && extra.containsKey(key)) return extra[key]!;
    final Map<String, String>? en = langChrome['en'];
    if (en != null && en.containsKey(key)) return en[key]!;
    return key;
  }

  /// Translate one Persian source string into [language].
  String call(String source) => tr(source, language);

  /// Translate one Persian source string into [lang].
  static String tr(String source, String lang) {
    if (lang == 'fa') return source;
    prime();
    final String cacheKey = '$lang|$source';
    final String? hit = _cache[cacheKey];
    if (hit != null) return hit;

    final String english = toEnglish(source);
    final Map<String, String>? table = enToLang[lang];
    String out = english;
    if (table != null) {
      if (table.containsKey(english)) {
        out = table[english]!;
      } else {
        out = _replaceAll(english, table, _langKeys[lang] ?? const <String>[]);
        if (out == english && langChrome[lang]?.containsKey(english) == true) {
          out = langChrome[lang]![english]!;
        }
      }
    }
    _cache[cacheKey] = out;
    return out;
  }

  /// An English string -- an option name, a help line -- into [lang].
  static String fromEnglish(String english, String lang) {
    if (lang == 'en') return english;
    prime();
    final String cacheKey = '$lang|en|$english';
    final String? hit = _cache[cacheKey];
    if (hit != null) return hit;
    final Map<String, String>? table = enToLang[lang];
    String out = english;
    if (table != null) {
      if (table.containsKey(english)) {
        out = table[english]!;
      } else {
        out = _replaceAll(english, table, _langKeys[lang] ?? const <String>[]);
        if (out == english && langChrome[lang]?.containsKey(english) == true) {
          out = langChrome[lang]![english]!;
        }
      }
    }
    _cache[cacheKey] = out;
    return out;
  }

  bool get isRtl => kRtlLanguages.contains(language);

  /// Persian digits, the way the preview renders numbers on the home screen.
  static String faDigits(Object? value) {
    const String digits = '۰۱۲۳۴۵۶۷۸۹';
    return value.toString().replaceAllMapped(
          RegExp(r'[0-9]'),
          (Match m) => digits[int.parse(m.group(0)!)],
        );
  }
}
