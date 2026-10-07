import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';
import 'i18n.dart';
import 'models.dart';
import 'push.dart';

/// Keeps the signed-in user and token. The token lives in the platform's secure storage
/// (Keychain / Keystore); the last known user is cached so the app still opens without a connection.
abstract class AuthSession<U> extends ChangeNotifier {
  AuthSession({required this.scope, http.Client? httpClient}) {
    api = ApiClient(tokenProvider: () => token, onUnauthorized: _expired, client: httpClient);
  }

  /// "staff" or "customer".
  final String scope;
  late final ApiClient api;

  static const _storage = FlutterSecureStorage();

  String? token;
  U? user;
  bool restoring = true;

  /// Set when the last start could not reach the server and used the cached user.
  bool startedOffline = false;

  String get _tokenKey => 'rizo_${scope}_token';
  String get _userKey => 'rizo_${scope}_user';

  U parseUser(Object? json);
  Json userToJson(U user);
  String userLocale(U user);
  String get mePath;
  String get loginPath;
  String get localePath;
  String get devicesPath => '/api/$scope/devices';

  bool get isSignedIn => token != null && user != null;

  Future<void> restore() async {
    try {
      token = await _storage.read(key: _tokenKey);
    } catch (_) {
      token = null;
    }
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_userKey);
    if (token != null && cached != null) {
      try {
        user = parseUser(jsonDecode(cached));
      } catch (_) {
        user = null;
      }
    }
    if (token != null) {
      try {
        final data = await api.get(mePath);
        user = parseUser(asMap(data)['user']);
        await _cacheUser(user as U);
        startedOffline = false;
      } on ApiException catch (error) {
        if (error.isAuth || error.status == 401 || error.status == 403) {
          await _clear();
        } else if (user == null) {
          // Cannot reach the server and nothing is cached: ask the user to sign in again.
          token = null;
        } else {
          startedOffline = true;
        }
      }
    }
    restoring = false;
    notifyListeners();
    if (isSignedIn) unawaited(PushService.I.register(api, devicesPath));
  }

  Future<void> _cacheUser(U value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, jsonEncode(userToJson(value)));
  }

  Future<void> _clear() async {
    token = null;
    user = null;
    try {
      await _storage.delete(key: _tokenKey);
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userKey);
  }

  void _expired() {
    if (token == null) return;
    _clear().then((_) => notifyListeners());
  }

  Future<U> _finishLogin(dynamic data) async {
    final map = asMap(data);
    token = map['token']?.toString();
    final next = parseUser(map['user']);
    user = next;
    startedOffline = false;
    try {
      await _storage.write(key: _tokenKey, value: token);
    } catch (_) {}
    await _cacheUser(next);
    await Translator.I.setLocale(userLocale(next));
    notifyListeners();
    unawaited(PushService.I.register(api, devicesPath));
    return next;
  }

  /// [code] is the six-digit code of two-step sign-in (staff only); the server asks for it with `totpRequired`.
  Future<U> login(String phone, String password, {String? code}) async =>
      _finishLogin(await api.post(loginPath, body: {'phone': phone, 'password': password, if (code != null && code.isNotEmpty) 'code': code}));

  Future<void> logout() async {
    await PushService.I.unregister(api, devicesPath);
    await _clear();
    await onLogout();
    notifyListeners();
  }

  /// Subclasses clear their own caches.
  Future<void> onLogout() async {}

  /// Remember the chosen language on the account too (best effort).
  Future<void> saveLocale(String locale) async {
    await Translator.I.setLocale(locale);
    if (token == null) return;
    try {
      final data = await api.patch(localePath, body: {'locale': locale});
      user = parseUser(asMap(data)['user']);
      await _cacheUser(user as U);
      notifyListeners();
    } on ApiException {
      // Offline: the choice is already applied on this device.
    }
  }

  Future<void> refreshUser() async {
    try {
      final data = await api.get(mePath);
      user = parseUser(asMap(data)['user']);
      await _cacheUser(user as U);
      notifyListeners();
    } on ApiException {
      // keep what we have
    }
  }
}

class StaffSession extends AuthSession<StaffUser> {
  StaffSession({super.httpClient}) : super(scope: 'staff');

  @override
  StaffUser parseUser(Object? json) => StaffUser.fromJson(json);
  @override
  Json userToJson(StaffUser u) =>
      {'id': u.id, 'name': u.name, 'phone': u.phone, 'role': u.role, 'technicianType': u.technicianType, 'isAvailable': u.isAvailable, 'locale': u.locale};
  @override
  String userLocale(StaffUser u) => u.locale;
  @override
  String get mePath => '/api/staff/auth/me';
  @override
  String get loginPath => '/api/staff/auth/login';
  @override
  String get localePath => '/api/staff/auth/locale';

  Future<void> setAvailability(bool isAvailable) async {
    final data = await api.patch('/api/staff/auth/availability', body: {'isAvailable': isAvailable});
    user = parseUser(asMap(data)['user']);
    await _cacheUser(user!);
    notifyListeners();
  }
}

class CustomerSession extends AuthSession<CustomerUser> {
  CustomerSession({super.httpClient}) : super(scope: 'customer');

  @override
  CustomerUser parseUser(Object? json) => CustomerUser.fromJson(json);
  @override
  Json userToJson(CustomerUser u) => {
        'id': u.id,
        'name': u.name,
        'phone': u.phone,
        'address': u.address,
        'locale': u.locale,
        'preferredChannel': u.preferredChannel,
        'telegramLinked': u.telegramLinked,
        'deletionRequested': u.deletionRequested,
      };
  @override
  String userLocale(CustomerUser u) => u.locale;
  @override
  String get mePath => '/api/customer/auth/me';
  @override
  String get loginPath => '/api/customer/auth/login';
  @override
  String get localePath => '/api/customer/auth/locale';

  Future<CustomerUser> signup({required String name, required String phone, required String password, String? address}) async {
    return _finishLogin(await api.post('/api/customer/auth/register', body: {
      'name': name,
      'phone': phone,
      'password': password,
      if (address != null && address.trim().isNotEmpty) 'address': address.trim(),
      'locale': Translator.I.locale,
    }));
  }

  Future<void> forgotPassword(String phone) => api.post('/api/customer/auth/forgot', body: {'phone': phone});

  /// Where status messages go: sms, telegram or both.
  Future<void> setChannel(String channel) async {
    final data = await api.patch('/api/customer/auth/preferences', body: {'preferredChannel': channel});
    user = parseUser(asMap(data)['user']);
    await _cacheUser(user!);
    notifyListeners();
  }

  /// Asks the service to erase the personal data (or withdraws the request).
  Future<void> setDeletionRequested(bool requested) async {
    if (requested) {
      await api.post('/api/customer/auth/me/delete-request');
    } else {
      await api.delete('/api/customer/auth/me/delete-request');
    }
    await refreshUser();
  }
}
