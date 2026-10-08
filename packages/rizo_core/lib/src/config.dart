import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Where the apps talk to. Release builds are given the address at build time:
///   flutter build apk --dart-define=API_URL=https://your-api.onrender.com
/// Debug builds (and builds with ALLOW_SERVER_CHANGE=true) also let the user type another address, which is
/// handy for testing against a local server.
class AppConfig {
  static const String _buildTimeUrl = String.fromEnvironment('API_URL', defaultValue: '');
  static const bool _allowChangeFlag = bool.fromEnvironment('ALLOW_SERVER_CHANGE', defaultValue: false);
  static const String _prefsKey = 'rizo_api_url';

  static String _baseUrl = _buildTimeUrl.isNotEmpty ? _buildTimeUrl : _debugDefault();

  static const String _productionApi = 'https://rizo-service-api.onrender.com';
  static const String _productionWeb = 'https://rizo-service-full.netlify.app';

  static String _debugDefault() {
    // A release build made without --dart-define=API_URL must never point at localhost: use the production server.
    if (kReleaseMode) return _productionApi;
    // The Android emulator reaches the host machine through 10.0.2.2.
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) return 'http://10.0.2.2:4000';
    return 'http://localhost:4000';
  }

  /// The public website (Netlify), used only to build the customer's tracking link: --dart-define=WEB_URL=https://...
  static const String _webUrl = String.fromEnvironment('WEB_URL', defaultValue: '');
  static String get webUrl {
    final value = _webUrl.isNotEmpty ? _webUrl : (kReleaseMode ? _productionWeb : 'http://localhost:5173');
    return value.replaceAll(RegExp(r'/+$'), '');
  }

  static bool get canChangeServer => kDebugMode || _allowChangeFlag;
  static String get baseUrl => _baseUrl.replaceAll(RegExp(r'/+$'), '');

  static Future<void> load() async {
    if (!canChangeServer) return;
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefsKey);
    if (saved != null && saved.isNotEmpty) _baseUrl = saved;
  }

  static Future<void> setBaseUrl(String value) async {
    final prefs = await SharedPreferences.getInstance();
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      await prefs.remove(_prefsKey);
      _baseUrl = _buildTimeUrl.isNotEmpty ? _buildTimeUrl : _debugDefault();
    } else {
      await prefs.setString(_prefsKey, trimmed);
      _baseUrl = trimmed;
    }
  }

  /// Absolute address for an API path or an uploaded file ("/uploads/...").
  static String url(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    return '$baseUrl${path.startsWith('/') ? '' : '/'}$path';
  }
}
