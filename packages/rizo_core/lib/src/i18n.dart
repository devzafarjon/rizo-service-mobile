import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';

const supportedLocales = ['uz', 'ru', 'en'];
const defaultLocale = 'uz';

String parseLocale(Object? value, [String fallback = defaultLocale]) {
  if (value is! String || value.length < 2) return fallback;
  final short = value.substring(0, 2).toLowerCase();
  return supportedLocales.contains(short) ? short : fallback;
}

/// Reads the same translation files as the website (i18next format: nested keys, `{{name}}` placeholders,
/// `_one` / `_few` / `_many` / `_other` plurals) so wording stays identical across web and apps.
class Translator extends ChangeNotifier {
  Translator._();
  static final Translator I = Translator._();

  static const _prefsKey = 'rizo_locale';

  final Map<String, Map<String, dynamic>> _bundles = {};
  String _locale = defaultLocale;

  String get locale => _locale;

  /// For tests: use these bundles instead of the packaged assets.
  @visibleForTesting
  void loadForTest(Map<String, Map<String, dynamic>> bundles, {String locale = defaultLocale}) {
    _bundles
      ..clear()
      ..addAll(bundles);
    _locale = locale;
  }

  Future<void> load({String? initial}) async {
    for (final code in supportedLocales) {
      final raw = await rootBundle.loadString('packages/rizo_core/assets/locales/$code.json');
      final web = jsonDecode(raw) as Map<String, dynamic>;
      // Strings that only exist in the apps (sync status, scanner, server address ...).
      final extra = jsonDecode(await rootBundle.loadString('packages/rizo_core/assets/mobile/$code.json')) as Map<String, dynamic>;
      _bundles[code] = _merge(web, extra);
    }
    final prefs = await SharedPreferences.getInstance();
    _locale = parseLocale(prefs.getString(_prefsKey) ?? initial ?? WidgetsBinding.instance.platformDispatcher.locale.languageCode);
  }

  Future<void> setLocale(String code) async {
    final next = parseLocale(code);
    if (next == _locale) return;
    _locale = next;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, next);
    notifyListeners();
  }

  static Map<String, dynamic> _merge(Map<String, dynamic> base, Map<String, dynamic> extra) {
    final out = Map<String, dynamic>.from(base);
    extra.forEach((key, value) {
      final current = out[key];
      out[key] = current is Map<String, dynamic> && value is Map<String, dynamic> ? _merge(current, value) : value;
    });
    return out;
  }

  dynamic _find(dynamic node, List<String> parts) {
    if (parts.isEmpty) return node;
    if (node is! Map) return null;
    // i18next also resolves flat keys that contain dots (e.g. "request.status"), so try every prefix length.
    for (var n = 1; n <= parts.length; n++) {
      final key = parts.take(n).join('.');
      if (node.containsKey(key)) {
        final found = _find(node[key], parts.sublist(n));
        if (found != null) return found;
      }
    }
    return null;
  }

  dynamic _resolve(String key, String locale) => _find(_bundles[locale], key.split('.'));

  String _plural(int count, String locale) {
    if (locale == 'ru') {
      final mod10 = count % 10;
      final mod100 = count % 100;
      if (mod10 == 1 && mod100 != 11) return 'one';
      if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) return 'few';
      return 'many';
    }
    return count == 1 ? 'one' : 'other';
  }

  String t(String key, {Map<String, Object?>? params, int? count, String? defaultValue}) {
    String? text;
    for (final code in {_locale, defaultLocale}) {
      if (count != null) {
        final plural = _resolve('${key}_${_plural(count, code)}', code) ?? _resolve('${key}_other', code);
        if (plural is String) {
          text = plural;
          break;
        }
      }
      final value = _resolve(key, code);
      if (value is String) {
        text = value;
        break;
      }
    }
    text ??= defaultValue ?? key;
    final values = {...?params, 'count': ?count};
    if (values.isEmpty) return text;
    return text.replaceAllMapped(RegExp(r'\{\{\s*(\w+)\s*\}\}'), (match) {
      final v = values[match.group(1)];
      return v == null ? '' : v.toString();
    });
  }

  /// A list value such as `format.monthsShort`.
  List<String>? list(String key) {
    final value = _resolve(key, _locale) ?? _resolve(key, defaultLocale);
    return value is List ? value.map((e) => e.toString()).toList() : null;
  }

  /// A readable message for an API error, using the same `errors.<code>` keys as the website.
  String errorMessage(Object error) {
    if (error is! ApiException) return t('errors.generic');
    if (error.isNetwork) return t('mobile.offline', defaultValue: 'No connection. Check your internet and try again.');
    final details = <String, Object?>{...?error.details};
    for (final key in ['from', 'to']) {
      final value = details[key];
      if (value is String) details[key] = t('status.$value', defaultValue: value.replaceAll('_', ' '));
    }
    final gaps = details['gaps'];
    if (gaps is List) {
      details['list'] = gaps.map((g) => t('job.gap.$g', defaultValue: g.toString())).join(', ');
    }
    if (details['balance'] is num) {
      details['balance'] = '${details['balance']}';
    }
    return t('errors.${error.code}', params: details, defaultValue: error.message);
  }
}

String tr(String key, {Map<String, Object?>? params, int? count, String? def}) =>
    Translator.I.t(key, params: params, count: count, defaultValue: def);

extension TranslateContext on BuildContext {
  /// Translate and rebuild when the language changes.
  String tr(String key, {Map<String, Object?>? params, int? count, String? def}) =>
      watch<Translator>().t(key, params: params, count: count, defaultValue: def);

  String errorText(Object error) {
    watch<Translator>();
    return Translator.I.errorMessage(error);
  }
}
