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

## Required native device-token contract

The client is prepared to use a path supplied through
`LUMA_DEVICE_TOKEN_PATH`; it is intentionally empty by default. Confirm the
final path before enabling the build. Recommended contract:

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

## Required native subscription verification contract

The client is prepared to use a path supplied through
`LUMA_PURCHASE_VERIFICATION_PATH`; it is intentionally empty by default.
Recommended path: `POST /mobile/purchases/verify` (authenticated).

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

Confirm an authenticated `DELETE /user` (or documented equivalent) with a
non-reversible confirmation requirement and the expected response. Until that
contract exists, the app must not present a deletion control. Provide canonical
HTTPS URLs for the privacy policy and terms of service before store review.

## Contract validation checklist

- Confirm exact response envelopes and pagination metadata for every resource.
- Confirm sermon edit, retry, and delete operations, if supported; the mobile
  client must not guess these routes.
- Confirm AI study mode values beyond `quick_read` and `go_deeper`.
- Confirm notification preference read/write endpoints and whether they are
  user-level or device-level.
- Confirm entitlement/quota fields and the 402/403 response shape for limits.
