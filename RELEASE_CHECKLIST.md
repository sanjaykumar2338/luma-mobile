# LUMA Mobile release checklist

Status at final development review: source development is complete for the
documented mobile API. Store release and physical-device validation remain
external activities.

## Verified in this workspace

- [x] Production API default is `https://lumaword.app/api/v1`.
- [x] No Laravel repository or production server was modified.
- [x] Bearer tokens use `flutter_secure_storage` and are cleared on logout,
      invalid-session restore, and account deletion.
- [x] Account deletion uses `DELETE /user` with typed `DELETE` confirmation.
- [x] Sermon edit, retry, and delete use the finalized owner-authorized routes.
- [x] Device-token registration/removal and notification preferences use the
      finalized mobile endpoints.
- [x] Purchase verification and entitlement status use the finalized mobile
      purchase endpoints.
- [x] Firebase notifications default to disabled.
- [x] Billing defaults to disabled.
- [x] WEB, KJV, and ASV Bible reader flows are present.
- [x] Android and iOS LUMA launcher/splash assets are generated from the
      existing logo mark.
- [x] Privacy policy: https://lumaword.app/privacy
- [x] Terms of service: https://lumaword.app/terms
- [x] `flutter analyze` passes with 0 issues.
- [x] `flutter test` passes.
- [x] Debug APK built with both feature flags false.
- [x] Debug APK installed on the connected Samsung SM E225F without launching
      or manually testing it.

## Required approval before release

- [ ] Approve proposed identifiers: `app.lumaword.mobile` for Android and iOS.
      The repository still uses the temporary `com.example.luma_mobile` Android
      identifier and Flutter-generated iOS placeholder settings.
- [ ] Configure Android release signing, keystore, Play Console ownership, and
      upload credentials.
- [ ] Configure iOS signing, provisioning profiles, App Store Connect access,
      and the approved bundle identifier.
- [ ] Replace any final placeholder display/app metadata after identifier
      approval.

## Firebase and notifications

- [ ] Add the production Firebase Android configuration and iOS configuration.
- [ ] Configure APNs capability, APNs key, entitlements, and provisioning.
- [ ] Configure Laravel notification delivery credentials and
      `FIREBASE_NOTIFICATIONS_ENABLED=true` only after provider validation.
- [ ] Build with `LUMA_FIREBASE_ENABLED=true` only after credentials are
      installed; keep the device-token path `/mobile/device-tokens`.
- [ ] Validate foreground, background, terminated, token refresh, sign-out
      removal, and documented tap routes on physical devices.

## Billing and entitlements

- [ ] Create and approve `luma_monthly` and `luma_annual` products in Apple and
      Google stores.
- [ ] Configure store receipt/service-account credentials on Laravel.
- [ ] Enable Laravel purchase verification only after replay, refund,
      cancellation, grace-period, and expiration handling is validated.
- [ ] Build with `LUMA_BILLING_ENABLED=true` only after store products and
      server verification are ready.
- [ ] Verify purchase, pending, error, restore, cancellation, refund, and
      entitlement refresh behavior on both stores.

## Build and deployment

- [ ] Run `flutter pub get` from a clean checkout.
- [ ] Run `flutter analyze` and `flutter test` in CI.
- [ ] Build signed Android App Bundle with release flags and approved ID.
- [ ] Build signed iOS archive on macOS with approved ID and credentials.
- [ ] Confirm API base URL and feature flags in release build configuration.
- [ ] Confirm no API tokens, Firebase private keys, store secrets, or test
      credentials are committed.
- [ ] Review privacy disclosures, permissions, data deletion, and store
      metadata.

## Manual device test matrix

- [ ] Fresh install, upgrade install, uninstall/reinstall, and session restore.
- [ ] Registration, login, logout, invalid token, password reset, profile, and
      password change.
- [ ] Account deletion and post-deletion token/session invalidation.
- [ ] Sermon URL, transcript, file upload, processing, edit, retry, delete,
      notes, and Ask LUMA.
- [ ] Bible translations, chapter navigation, search, copy, and study handoff.
- [ ] AI study modes, quota failures, devotional history, reading-plan
      enrollment, and progress.
- [ ] Notification permission, delivery states, token rotation, preferences,
      and notification taps.
- [ ] Store purchase and entitlement lifecycle on Apple and Google.
- [ ] Safe areas, keyboard, rotation, offline/error/empty/loading states,
      Android 13 notification permission, and accessibility text scaling.

## Known non-release blockers

- Physical-device behavior has not been manually exercised by this review.
- Release identifiers and signing credentials are intentionally not finalized.
- Firebase/APNs and Apple/Google billing credentials are intentionally absent.
