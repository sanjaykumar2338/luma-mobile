# Native push architecture

The mobile app now has a `PushNotificationGateway` boundary in
`lib/core/push_notifications.dart`. It intentionally returns no registration
until the platform providers and server contract are ready.

Required before implementation:

- Android: Firebase project, `google-services.json`, FCM sender configuration,
  notification permission handling, and a release signing setup.
- iOS: Apple Developer push capability, APNs key/certificate, entitlements,
  provisioning profiles, and notification permission handling.
- Laravel: a versioned authenticated device-token endpoint accepting provider,
  token, platform, app version, and installation identity, plus revoke/update
  semantics. The existing browser Web Push `/push-subscriptions` contract must
  not be reused for FCM/APNs tokens.

No credentials are included in this repository, and no native push delivery is
claimed until those requirements are supplied.
