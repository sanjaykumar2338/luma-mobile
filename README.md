# LUMA mobile

Flutter foundation for the LUMA Android and iOS apps.

## Local setup

Install Flutter 3.50+ and run:

```sh
flutter pub get
flutter analyze
flutter test
flutter run --dart-define=LUMA_API_ORIGIN=https://lumaword.app/
```

The production API origin is `https://lumaword.app/`; the versioned API base
used by the app is `https://lumaword.app/api/v1`. The origin is configurable at
build time with `LUMA_API_ORIGIN`, or the complete API base can be overridden
with `LUMA_API_BASE_URL` for development or staging environments.
Tokens are stored with
`flutter_secure_storage`; no Stripe or OpenAI credentials are shipped in the
client. The current app intentionally shows membership status without starting
a native purchase flow.

## Current implementation status

The app includes authenticated navigation, dashboard data, sermon library
submission/list/detail/Ask LUMA flows, Bible reading/search, AI Bible study,
devotionals, reading-plan catalog, profile updates, feedback, loading states,
empty states, and API error handling. See `docs/MOBILE_INTEGRATION_PLAN.md` for
the exact backend/platform gaps.

Native FCM and Apple/Google billing adapters are present but disabled by
default. Configure them only after adding platform credentials, product IDs,
and the Laravel contracts documented in `BACKEND_REQUIREMENTS.md`.

The local machine used for this repository currently has no Flutter, Dart,
Java, Android SDK, or `adb` executable. Dependency installation, analyzer,
tests, platform generation, and APK builds must be run after Flutter tooling is
installed.

## Repository layout

This is the standalone Flutter repository at
`C:\\xampp\\htdocs\\luma mobile app`. The Laravel backend remains in the
separate `lumaword` repository and is not part of this project.

## Development identifiers

The proposed final Android application ID and iOS bundle identifier are
`app.lumaword.mobile`. They are not applied yet; the platform shells retain
temporary Flutter-generated identifiers until the owner approves the change.
