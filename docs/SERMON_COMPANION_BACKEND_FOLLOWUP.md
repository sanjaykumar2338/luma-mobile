# Sermon Companion backend follow-up

This document records production testing findings from 28 November 2026. The Laravel backend was inspected read-only and was not modified.

## Missing memory-card answer validation

The current authenticated routes are `GET /api/v1/sermon-companions/{id}/memory-cards` and `POST /api/v1/sermon-companion-memory-cards/{id}/practice`. The practice request accepts only a client-supplied `completed` boolean. The controller stores that boolean and increments `attempts` without checking any entered answer. The resource sends `correct_answers` to the client. The mobile screen therefore shows a verse and a completion checkbox; it cannot verify recall.

Required backend changes:

1. Add an authenticated answer submission endpoint, for example `POST /api/v1/sermon-companion-memory-cards/{id}/answers`, authorized against the card's Companion owner.
2. Accept the user's answers for the blanks in order, validate their count and length, and compare them server side with normalized expected words. Define the normalization rule (case, punctuation, whitespace, and acceptable variants) in the contract.
3. Return per-blank correctness, an overall result, attempts, and completion state. Persist an attempt and update completion only from the server's result. The client should never be able to mark an incorrect attempt complete by sending a boolean.
4. Remove `correct_answers` from the ordinary card response. If answer reveal is desired, expose it through an explicit practice or reveal response with its own policy.
5. Add tests for ownership, malformed answers, correct and incorrect attempts, repeated attempts, answer reveal, and concurrent submissions. Document the exact JSON request and response before mobile integration.

## Live processing and generation failures

The production test Companion accepted two image uploads, one WAV audio upload, a recap request, and five-day and seven-day plan requests. All six jobs moved to `failed` during observation. The server exposes only generic processing errors: `Attachment processing failed. Please retry.`, `Recap generation failed. Please retry.`, and `Devotional generation failed. Please retry.`. The mobile app now displays those errors. Check production queue worker and Laravel logs for the underlying exceptions, OpenAI credentials/model responses, attachment storage access, Scripture verification, and reservation handling. Retry with the same short test content after the backend issue is resolved. Do not infer that OpenAI content was generated merely because a job was queued.

The initial Android AAC recording had an `.m4a` extension, but local PHP `finfo` identified its container as `video/mp4`; the production `File::types(['mp3', 'm4a', 'wav', 'aac'])` rule rejected it. The mobile recorder now produces mono 16 kHz WAV, which the production endpoint accepted. The WAV processing job still failed and needs server-side investigation.
