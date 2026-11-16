/// Platform boundary for native notifications.
///
/// Firebase Messaging/APNs should be added only after release credentials and a
/// Laravel device-token contract are approved. This layer deliberately does not
/// call the browser-oriented `/push-subscriptions` endpoint.
class PushRegistration {
  const PushRegistration({required this.provider, required this.token});
  final String provider;
  final String token;
}

abstract interface class PushNotificationGateway {
  Future<PushRegistration?> register();
  Future<void> unregister();
}

class PendingPushNotificationGateway implements PushNotificationGateway {
  const PendingPushNotificationGateway();
  @override Future<PushRegistration?> register() async => null;
  @override Future<void> unregister() async {}
}
