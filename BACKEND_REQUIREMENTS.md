# LUMA mobile backend requirements

This file records the mobile-facing contracts that must be confirmed or added
in the separate Laravel repository. The mobile app continues to use
`https://lumaword.app/api/v1` and this workspace does not change Laravel.

## Existing contracts used by the app

The current client calls the existing versioned resources below with a bearer
token unless noted otherwise:

| Method | Endpoint | Client payload / response used |
| --- | --- | --- |
| POST | `/mobile/auth/login` | `{email,password,device_name}`; `{token,data:user}` |
| POST | `/mobile/auth/register` | `{name,email,password,password_confirmation,device_name}`; `{token,data:user}` |
| POST | `/mobile/auth/logout` | Authenticated; revoke current token |
| GET | `/user` | `data:user` |
| PATCH | `/user/profile` | `{name,email}`; `data:user` |
| PUT | `/user/password` | `{current_password,password,password_confirmation}` |
| POST | `/auth/forgot-password` | `{email}` |
| GET | `/entitlements` | `data:{membership,usage}` |
| GET/POST | `/sermons` | List or `{source_type,title,source_url,transcript,auto_process}`; multipart uses `media` |
| GET | `/sermons/{id}` | `data:sermon`, including notes and processing fields |
| POST | `/sermons/{id}/conversation/messages` | `{question,content,client_request_id}`; answer resource |
| GET | `/bible/books` | `translation` query; list of books |
| GET | `/bible/{book}/chapters/{chapter}` | `translation` query; passage resource |
| GET | `/bible/search` | `translation,q` query; list of verse results |
| GET/POST | `/bible-studies` | List or `{reader_reference:{translation,book,chapter},depth}` |
| GET | `/devotionals`, `/devotionals/today` | Devotional resources |
| GET | `/reading-plans` | Plans with day resources |
| POST | `/reading-plans/{id}/enrollments` | Creates/returns enrollment and completed day IDs |
| PUT | `/reading-plan-enrollments/{id}/days/{day}` | `{completed:boolean}` |
| POST | `/beta-feedback` | `{message}` |

All non-2xx responses should be JSON with `message` and optional `errors`.

## Native device-token contract

The client uses the finalized path `/mobile/device-tokens` (or an equivalent
build override) and remains disabled until Firebase credentials are configured.

`POST /mobile/device-tokens` (authenticated)

```json
{
  "provider": "fcm",
  "token": "<opaque FCM token>",
  "platform": "android|ios",
  "app_version": "0.1.0+1"
}
```

Return `201` or `200` with the persisted token resource. Registration must be
idempotent by `(user_id, provider, token)` and update the platform/version and
last-seen timestamp. `DELETE /mobile/device-tokens` accepts `{provider,token}`
and revokes only the current user's matching token. Do not reuse the browser
`/push-subscriptions` Web Push contract.

The Laravel notification gateway must send FCM/APNs notifications without
exposing provider credentials to the app. Define payload fields for `type`,
`title`, `body`, and optional `route`/`route_arguments`; document each route
the app can open from a notification tap.

## Native subscription verification contract

The client uses `POST /mobile/purchases/verify` (authenticated) and remains
disabled until store credentials and the billing enable flag are configured.

```json
{
  "store": "app_store|play_store",
  "product_id": "luma_monthly|luma_annual",
  "transaction_id": "<store transaction/order id>",
  "verification_data": "<opaque store receipt/token>"
}
```

The server must verify directly with Apple/Google, reject replayed or invalid
transactions, map products to the existing Laravel entitlement model, and
return the updated entitlement resource. Add a server-side restore/status
operation if the app needs to reconcile a purchase after reinstall. Cancellations,
refunds, grace periods, billing retries, and expiration must be reflected by
the existing entitlement source of truth.

## Account deletion and legal links

The finalized contract is authenticated `DELETE /user` with
`{"confirmation":"DELETE"}`. It returns `200` with
`{"message":"Account permanently deleted."}`. The client now requires the
user to type `DELETE` before sending it. Provide canonical HTTPS URLs for the
privacy policy and terms of service before store review.

## Contract validation checklist

- Confirm exact response envelopes and pagination metadata for every resource.
- Sermon edit, retry, and delete use the finalized PATCH/process/DELETE routes
  documented above and are now integrated by the mobile client.
- Confirm AI study mode values beyond `quick_read` and `go_deeper`.
- Notification preferences are user-level and use `GET|PUT
  /mobile/notification-preferences`.
- Confirm entitlement/quota fields and the 402/403 response shape for limits.

## Client feedback follow-up contracts

The finalized backend contract adds these fields consumed by the mobile client:

- `GET|PUT /mobile/notification-preferences`: `reading_plan_reminders`,
  `reminder_time` (`HH:MM`), and IANA `timezone`, in addition to the existing
  switches. Saving preferences does not imply FCM/APNs delivery.
- `GET /reading-plans`: plan-level `complete_canon` and day-level `readings`
  assignments. The complete-canon 30-day plan must cover all 66 books and
  1,189 chapters exactly once while preserving existing enrollments.
- `GET /entitlements`: membership `source` (`stripe`, `mobile_purchase`,
  `manual`, or null) and `canceled`; future cancellation dates must preserve
  valid paid access until expiration.

The mobile client accepts `Nehemiah 1`, `Nehemiah 1:1`, and `Nehemiah 1:1-3`
and sends a structured `reader_reference`. The Laravel validator and study
generator must accept `translation`, `book`, `chapter`, and optional
`verse_start`/`verse_end`, with book-name normalization.

The completed-sermon action uses `POST /sermons/{id}/devotional`. It must
authorize the sermon owner, enforce membership limits, ground output in the
stored transcript and Scripture references, save it to the current user's
history, and return title, Scripture reference/text, reflection, application,
and prayer. It must not invent preacher quotations.

YouTube processing should expose finite states such as `awaiting_captions`,
`retrieving_transcript`, `processing`, `completed`, and `failed`, together
with a user-safe `processing_error`. Queue retries should use bounded backoff;
unavailable captions must fail with manual transcript/audio fallback guidance
instead of waiting forever.

This workspace cannot verify live YouTube OAuth/captions, Laravel queue
workers, store purchases, Firebase/APNs delivery, or iOS compilation. These
remain external blockers until backend services, provider credentials, store
product IDs, and platform build toolchains are available.

Notification preferences currently persist the implemented global, sermon,
devotional, and subscription switches. Before exposing reading-plan reminders,
custom times, frequency, or timezone controls, extend the preference resource
with server-side scheduling semantics and confirm the FCM/APNs scheduler honors
them; the mobile client intentionally does not show controls for an unverified
backend capability.
