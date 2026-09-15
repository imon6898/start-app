import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../services/local_data/cache_manager.dart';
import 'locales/bn_bd.dart';
import 'locales/en_us.dart';

/// Keys are the English source strings, so `.tr` still renders correctly for a
/// locale that has no entry here. Add a language by adding one line to
/// [_locales]; [supported] and [keys] both follow from it.
class AppTranslations extends Translations {
  static const Locale fallbackLocale = Locale('en', 'US');

  static const Map<String, Map<String, String>> _locales = {
    'en_US': enUs,
    'bn_BD': bnBd,
  };

  /// Locales with a map in [_locales]; anything else falls back to the key.
  static final List<Locale> supported = _locales.keys
      .map(_toLocale)
      .toList(growable: false);

  /// Saved choice wins, then device locale, then [fallbackLocale].
  static Locale get initialLocale =>
      _parse(CacheManager.getLocale) ??
      _match(Get.deviceLocale?.languageCode) ??
      fallbackLocale;

  /// Switches locale and persists it so the next launch keeps the choice.
  static Future<void> setLocale(Locale locale) async {
    await CacheManager.setLocale(tagOf(locale));
    await Get.updateLocale(locale);
  }

  /// "en_US" for [Locale]; the key format used by [keys] and the cache.
  static String tagOf(Locale locale) => locale.countryCode == null
      ? locale.languageCode
      : '${locale.languageCode}_${locale.countryCode}';

  /// Parses a cached "bn_BD" back to a supported [Locale], or null if unknown.
  static Locale? _parse(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    return _locales.containsKey(raw)
        ? _toLocale(raw)
        : _match(raw.split('_').first);
  }

  /// First supported locale for a bare language code, e.g. "bn" -> bn_BD.
  static Locale? _match(String? languageCode) {
    if (languageCode == null) return null;
    final hit = supported.where((l) => l.languageCode == languageCode);
    return hit.isEmpty ? null : hit.first;
  }

  static Locale _toLocale(String tag) {
    final parts = tag.split('_');
    return parts.length == 1
        ? Locale(parts.first)
        : Locale(parts.first, parts[1]);
  }

  @override
  Map<String, Map<String, String>> get keys => _locales;
}
