# LUMA mobile

Flutter foundation for the LUMA Android and iOS apps.

## Local setup

Install Flutter 3.50+ and run:

```sh
flutter pub get
flutter analyze
flutter test
flutter run --dart-define=LUMA_API_BASE_URL=https://lumaword.app/api/v1
```

The production API base URL is `https://lumaword.app/api/v1`. It is configurable
at build time with `LUMA_API_BASE_URL` for development or staging environments.
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

The local machine used for this repository currently has no Flutter, Dart,
Java, Android SDK, or `adb` executable. Dependency installation, analyzer,
tests, platform generation, and APK builds must be run after Flutter tooling is
installed.

## Repository layout

This is the standalone Flutter repository at
`C:\\xampp\\htdocs\\luma mobile app`. The Laravel backend remains in the
separate `lumaword` repository and is not part of this project.

## Development identifiers

The platform shells should use a temporary development identifier such as
`com.example.lumaMobile` until the owner supplies the final Android application
ID and iOS bundle identifier. Do not ship that placeholder to either store.
