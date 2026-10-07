import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'api.dart';
import 'i18n.dart';

/// Push notifications through Firebase Cloud Messaging.
///
/// Firebase is configured by `google-services.json` (Android) / `GoogleService-Info.plist` (iOS), which are not part of the
/// repository. When they are missing the app still works; it just has no push (see PUSH_NOTIFICATIONS.md).
class PushService {
  PushService._();
  static final PushService I = PushService._();

  bool _ready = false;
  String? _token;
  StreamSubscription<String>? _refresh;
  final List<StreamSubscription<RemoteMessage>> _listeners = [];

  /// The request a tapped notification points to. Home screens watch this and open it, then clear it.
  final ValueNotifier<String?> openRequest = ValueNotifier<String?>(null);

  /// Bumped when a push arrives while the app is open, so lists and the unread badge can refresh.
  final ValueNotifier<int> arrived = ValueNotifier<int>(0);

  bool get isReady => _ready;

  /// Call once at start-up. Never throws.
  Future<void> init() async {
    if (_ready) return;
    try {
      await Firebase.initializeApp();
      _ready = true;
      _listeners.add(FirebaseMessaging.onMessage.listen((_) => arrived.value++));
      _listeners.add(FirebaseMessaging.onMessageOpenedApp.listen(_opened));
      final first = await FirebaseMessaging.instance.getInitialMessage();
      if (first != null) _opened(first);
    } catch (error) {
      debugPrint('Push is off: $error');
    }
  }

  void _opened(RemoteMessage message) {
    final id = message.data['serviceRequestId']?.toString() ?? '';
    arrived.value++;
    if (id.isNotEmpty) openRequest.value = id;
  }

  /// After sign-in (or when the app starts signed in): ask permission, then tell the server which device to notify.
  Future<void> register(ApiClient api, String devicesPath) async {
    if (!_ready) return;
    try {
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;
      final token = await messaging.getToken();
      if (token == null) return;
      _token = token;
      await _send(api, devicesPath, token);
      await _refresh?.cancel();
      _refresh = messaging.onTokenRefresh.listen((next) {
        _token = next;
        _send(api, devicesPath, next);
      });
    } catch (error) {
      debugPrint('Push registration failed: $error');
    }
  }

  Future<void> _send(ApiClient api, String devicesPath, String token) async {
    try {
      await api.post(devicesPath, body: {'token': token, 'platform': defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android', 'locale': Translator.I.locale});
    } on ApiException catch (error) {
      debugPrint('Could not register the device: $error');
    }
  }

  /// On sign-out: stop notifying this device for the account that is leaving (best effort).
  Future<void> unregister(ApiClient api, String devicesPath) async {
    final token = _token;
    await _refresh?.cancel();
    _refresh = null;
    _token = null;
    if (!_ready || token == null) return;
    try {
      await api.post('$devicesPath/remove', body: {'token': token});
    } catch (_) {}
  }
}
