# Native push architecture

The mobile app now has a Firebase Messaging lifecycle adapter in
`lib/core/push_notifications.dart`. It remains disabled by default and does
not register a token until platform providers and the server contract are
ready. Foreground messages are received by the adapter, background messages
use the annotated top-level handler, and notification taps are forwarded to
the app callback.

Required before implementation:

- Android: Firebase project, `google-services.json`, FCM sender configuration,
  notification permission handling, and a release signing setup.
- iOS: Apple Developer push capability, APNs key/certificate, entitlements,
  provisioning profiles, and notification permission handling.
- Laravel: a versioned authenticated device-token endpoint accepting provider,
  token, platform, app version, and installation identity, plus revoke/update
  semantics. The existing browser Web Push `/push-subscriptions` contract must
  not be reused for FCM/APNs tokens.

Enable only after setup with build defines similar to:

```sh
flutter run \
  --dart-define=LUMA_FIREBASE_ENABLED=true \
  --dart-define=LUMA_DEVICE_TOKEN_PATH=/mobile/device-tokens
```

The exact contract is recorded in `BACKEND_REQUIREMENTS.md`. The app uses the
FCM token for native delivery; do not treat the Firebase Installation ID as a
notification token unless the Laravel gateway is explicitly designed for it.

No credentials are included in this repository, and no native push delivery is
claimed until those requirements are supplied.
