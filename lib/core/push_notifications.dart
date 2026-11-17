import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'api_client.dart';
import 'config.dart';

class PushRegistration {
  const PushRegistration({
    required this.provider,
    required this.token,
    required this.platform,
    this.appVersion,
  });
  final String provider;
  final String token;
  final String platform;
  final String? appVersion;

  Map<String, dynamic> toJson() => {
        'provider': provider,
        'token': token,
        'platform': platform,
        if (appVersion != null) 'app_version': appVersion,
      };
}

abstract interface class PushNotificationGateway {
  Future<PushRegistration?> register();
  Future<void> unregister();
  Future<void> dispose();
}

/// FCM lifecycle adapter. It remains inert until LUMA_FIREBASE_ENABLED is
/// true and a server token path is supplied at build time.
class FirebasePushNotificationGateway implements PushNotificationGateway {
  FirebasePushNotificationGateway({required this.api, this.onMessageTap});
  final ApiClient api;
  final void Function(RemoteMessage message)? onMessageTap;
  StreamSubscription<String>? _tokenSubscription;
  StreamSubscription<RemoteMessage>? _messageSubscription;
  StreamSubscription<RemoteMessage>? _openedSubscription;
  String? _token;

  @override
  Future<PushRegistration?> register() async {
    if (!AppConfig.firebaseEnabled) return null;
    await Firebase.initializeApp();
    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(alert: true, badge: true, sound: true);
    // FCM 17 exposes register/onRegistered for the web installation flow;
    // native delivery still uses the provider token returned by getToken.
    // ignore: deprecated_member_use
    final token = await messaging.getToken();
    _token = token;
    _messageSubscription ??= FirebaseMessaging.onMessage.listen((message) {});
    _openedSubscription ??=
        FirebaseMessaging.onMessageOpenedApp.listen((message) {
      onMessageTap?.call(message);
    });
    final initial = await messaging.getInitialMessage();
    if (initial != null) onMessageTap?.call(initial);
    // ignore: deprecated_member_use
    _tokenSubscription ??= messaging.onTokenRefresh.listen((next) {
      _token = next;
      unawaited(_sendToken(next));
    });
    if (token == null) return null;
    await _sendToken(token);
    return PushRegistration(
      provider: 'fcm',
      token: token,
      platform: Platform.isIOS ? 'ios' : 'android',
    );
  }

  Future<void> _sendToken(String token) async {
    if (AppConfig.deviceTokenPath.isEmpty) return;
    await api.request(
      AppConfig.deviceTokenPath,
      method: 'POST',
      auth: true,
      body: PushRegistration(
        provider: 'fcm',
        token: token,
        platform: Platform.isIOS ? 'ios' : 'android',
      ).toJson(),
    );
  }

  @override
  Future<void> unregister() async {
    final token = _token;
    if (token == null || AppConfig.deviceTokenPath.isEmpty) return;
    await api.request(
      AppConfig.deviceTokenPath,
      method: 'DELETE',
      auth: true,
      body: {'provider': 'fcm', 'token': token},
    );
    _token = null;
  }

  @override
  Future<void> dispose() async {
    await _tokenSubscription?.cancel();
    await _messageSubscription?.cancel();
    await _openedSubscription?.cancel();
  }
}

/// Safe default used by builds that do not include Firebase credentials.
class PendingPushNotificationGateway implements PushNotificationGateway {
  const PendingPushNotificationGateway();
  @override
  Future<PushRegistration?> register() async => null;
  @override
  Future<void> unregister() async {}
  @override
  Future<void> dispose() async {}
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (!AppConfig.firebaseEnabled) return;
  await Firebase.initializeApp();
}

void configureFirebaseBackgroundHandler() {
  if (AppConfig.firebaseEnabled) {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }
}
