import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppLocalizations extends ChangeNotifier {
  AppLocalizations._();

  static final AppLocalizations instance = AppLocalizations._();

  static const supportedLanguages = <String>['tr', 'en'];
  static const _preferenceKey = 'languageCode';

  Map<String, Map<String, String>> _catalogs = const {};
  String _languageCode = 'en';

  String get languageCode => _languageCode;
  bool get isTurkish => _languageCode == 'tr';

  Future<void> loadInitial(SharedPreferences? prefs) async {
    await _ensureLoaded();
    SharedPreferences localPrefs = prefs ?? await SharedPreferences.getInstance();
    final saved = localPrefs.getString(_preferenceKey);
    _languageCode = supportedLanguages.contains(saved) ? saved! : 'en';
  }

  Future<void> setLanguage(
    String code, {
    SharedPreferences? prefs,
  }) async {
    if (!supportedLanguages.contains(code)) return;
    await _ensureLoaded();
    _languageCode = code;

    try {
      SharedPreferences localPrefs = prefs ?? await SharedPreferences.getInstance();
      await localPrefs.setString(_preferenceKey, code);
    } catch (_) {}

    notifyListeners();
  }

  Future<void> _ensureLoaded() async {
    if (_catalogs.isNotEmpty) return;
    try {
      final raw = await rootBundle.loadString('assets/i18n/translations.json');
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      _catalogs = decoded.map(
        (language, values) => MapEntry(
          language,
          (values as Map<String, dynamic>).map(
            (key, value) => MapEntry(key, value.toString()),
          ),
        ),
      );
    } catch (e) {
      debugPrint('Translations load error: $e');
    }
  }

  String text(String key, [Map<String, Object?> params = const {}]) {
    var value = _catalogs[_languageCode]?[key] ??
        _catalogs['tr']?[key] ??
        key;
    for (final entry in params.entries) {
      value = value.replaceAll('{${entry.key}}', '${entry.value}');
    }
    return value;
  }
}

String tr(String key, [Map<String, Object?> params = const {}]) =>
    AppLocalizations.instance.text(key, params);