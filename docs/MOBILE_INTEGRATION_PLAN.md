# LUMA mobile integration plan

This document is maintained with the standalone Flutter project in
`C:\\xampp\\htdocs\\luma mobile app`. The Laravel backend and web frontend
remain in the separate `lumaword` repository. The production API host is
`https://lumaword.app` and the versioned API base is
`https://lumaword.app/api/v1`.

## Foundation delivered

- Flutter app shell with LUMA colors and the supplied `assets/logo-mark.png`.
- Splash, welcome/onboarding, login, registration, forgot-password request,
  persistent bearer-token login, logout, dashboard, bottom navigation, profile,
  loading, and basic empty/feature-preview states.
- Secure token storage and one centralized API client/error type.
- Mobile-only Sanctum token endpoints; existing web session auth is unchanged.

## Mobile implementation status

The first feature batch now uses the existing API for:

- Dashboard entitlements, today's devotional, and recent sermons.
- Sermon pagination, URL/transcript submission, processing refresh, notes, and
  transcript-grounded Ask LUMA messages, plus validated audio/video file upload.
- Bible translations, books, chapters, passage display, and search.
- AI Bible study generation/history, devotional history, reading-plan catalog,
  enrollment/day completion, profile updates, password changes, beta feedback,
  and account settings.

The app does not invent response data: list/resource parsing follows the Laravel
JSON resources and pagination envelopes. Loading, empty, API-error, and retry
states are included in the screens.

## Reused API surface

The existing `/api/v1` API already covers user/profile/password, entitlements
and usage, billing status, promotional banners, sermons (including transcript,
media, processing, notes, and Ask LUMA), devotionals, reading plans and
enrollments, Bible translations/books/search/passages, Bible studies, daily
activity, beta feedback, and push-subscription persistence.

The native client should call these endpoints with the stored bearer token.
Laravel remains the authority for ownership, quotas, AI usage, and premium
entitlements.

## Missing or mobile-specific work

- Added `POST /api/v1/mobile/auth/login` and `POST /api/v1/mobile/auth/register`
  returning a personal-access token plus the user resource.
- Added `POST /api/v1/mobile/auth/logout` to revoke the current token.
- Native push lifecycle and token-refresh code is present but disabled by
  default. Credentials and the separate device-token contract are still needed
  before enabling it.
- Native subscription lifecycle code is present but disabled by default. Store
  products and server-side receipt validation are still needed before enabling
  it.

## Backend/platform gaps

- File submission uses the existing `POST /api/v1/sermons` `media` field; no
  new backend endpoint is required for that path.
- Native push requires APNs/FCM credentials and a versioned device-token
  contract; the current `/push-subscriptions` endpoint accepts browser Web Push
  keys and is intentionally not called by the mobile app.
- Native subscription purchases require an approved Apple/Google billing flow
  and server-side receipt validation. The mobile app does not expose Stripe or
  OpenAI credentials.
- The existing billing checkout/portal endpoints are web-oriented; they should
  only be opened through a compliant platform flow after product/legal review.
- Multipart upload uses the Laravel limits: FLAC, MP3, MP4, MPEG, MPGA, M4A,
  OGG, WAV, or WEBM, with a 25 MB client-side limit matching the current
  backend configuration.
- Native notification provider wiring is intentionally pending credentials and
  a dedicated FCM/APNs device-token endpoint; see `PUSH_NOTIFICATIONS.md`.
- Exact proposed mobile-only contracts and unresolved backend questions are in
  `BACKEND_REQUIREMENTS.md`.

## Next development task

Build the authenticated data layer and first vertical slice: sermon library →
sermon submission → processing status → generated notes. Add API fixtures,
pagination, retry/offline behavior, and a dedicated test account before wiring
AI-heavy flows.
