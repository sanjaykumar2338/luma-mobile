# Sermon Companion physical Android test report

Date: 28 November 2026. Device: Samsung SM-E225F, Android physical device connected through wireless ADB. Backend: `https://lumaword.app/api/v1`. Account: the already signed-in mobile account designated by the user. Only short sample content and two small test images were submitted. No mocked test is counted as live verification.

The first ARM64 debug APK was installed and launched. Wireless ADB briefly disconnected, then reconnected. The final ARM64 split APK was installed and its Companion detail title was visually checked.

| Feature | Result | Physical production evidence / limit |
| --- | --- | --- |
| Install and launch latest ARM64 APK | PASS | Final ARM64 split APK installed and launched into the signed-in account. |
| Existing premium designs intact | FAIL (incomplete verification) | Today, sermon library/study, Plans, More, account settings, Companion hub, editor, and detail rendered with the established cream, dark card, and lime design. All existing premium screens were not exercised. |
| Create and edit written sermon notes | PASS | Created a short Companion with James 1:22, edited personal and confirmed notes, and observed `Ready` status. |
| Camera capture of handwritten note | FAIL (skipped at user request) | Native camera opened. The available handwritten page contained unrelated private content, so it was not photographed or uploaded. |
| Multiple gallery images | PASS | Two small test note images were selected in Android's gallery and uploaded. Companion changed to `Extracting Notes`. |
| Actual OpenAI image extraction | FAIL | Both image jobs moved from queued to failed with `Attachment processing failed. Please retry.`; no extracted text was returned. |
| Recording permission and short sample | PASS | Microphone permission was granted and short physical device recordings were made. |
| Pause, resume, stop, audio upload | PASS after mobile fix | Pause, resume, and stop changed the controls as expected. Initial AAC `.m4a` upload failed file-type validation; after switching to WAV, a short clip uploaded and entered the queue. |
| Actual audio transcription | FAIL | The WAV audio job moved from queued to failed with `Attachment processing failed. Please retry.`; no transcript was returned. |
| Sunday in One Page | FAIL | Production accepted the request, changed to `Generating Recap`, then changed to `Failed`; no recap content appeared. |
| Five-day devotional | FAIL | Production accepted the request, then the plan changed to `Failed`; no days were available. |
| Seven-day devotional | FAIL | Production accepted the request, then the plan changed to `Failed`; no days were available. |
| Scripture references and devotional content | FAIL (incomplete) | James 1:22 was stored in the written Companion. No generated Scripture or devotional days could be checked. |
| Completion tracking and resume | FAIL (not reached) | Generation failures prevented a live day completion and resume check. A mobile bug that reloaded the first plan after completing any day was fixed in source. |
| Journal autosave after app restart | PASS | The journal showed `Saved`, and its text remained visible after the app was restarted/upgraded. |
| Memory-card practice | FAIL (blocked) | No cards appeared because recap failed. The backend currently accepts a client completion flag without validating answers; see the backend follow-up. |
| Notification preference persistence | PASS | Changed the midweek check-in switch, saved it, restarted the app, and observed the saved value. The switch was then restored to its original setting. Push delivery was not tested. |
| API errors, loading states, crashes | PASS for exercised flows | Queued/generating and Save loading states, server file-type validation, and visible failed job errors were observed. Refresh retrieved server changes. No app crash was seen during exercised flows. |
| Screenshots of new screens | PASS for reached screens | Hub, editor, detail, photo controls, gallery upload, recap and plan statuses were captured. Generated content screens were unavailable because jobs failed. |

## Mobile changes

- Added a Companion refresh action and pull to refresh, plus visible written/confirmed notes, attachment extraction text/status, and backend processing errors.
- Kept the selected devotional plan when a day is completed.
- Included Scripture references when editing a Companion.
- Preserved the recorder's returned file path on stop, handled recorder errors, and switched to mono 16 kHz WAV to satisfy production file validation.
- Prevented restoring a journal entry from triggering a redundant autosave.
- Shortened the detail app bar title to prevent clipping beside its action icons.

`flutter analyze` reported no issues and `flutter test` passed all 23 tests after the final source change. `flutter build apk --debug --split-per-abi --target-platform android-arm64 --dart-define=LUMA_API_ORIGIN=https://lumaword.app` succeeded. These checks do not establish live backend success.

## Screenshots

Selected captures are in `artifacts/screenshots/`. Relevant files: `40-final-today.png`, `02-more.png`, `03-companion-hub.png`, `04-editor-write.png`, `10-companion-detail.png`, `11-journal-saved.png`, `12-editor-edit.png`, `42-final-detail.png`, `18-recap-queued.png`, `19-five-day-queued.png`, `46-five-seven-failed.png`, `25-photo-controls.png`, `34-two-images-ready.png`, `50-recording-active.png`, `51-recording-paused.png`, `54-recording-stopped.png`, `58-wav-upload-result.png`, `62-notification-options.png`, `67-notifications-persisted-toggle.png`, `68-premium-library.png`, `69-premium-plans.png`, and `72-final-title-fixed.png`. Screenshots containing unrelated personal material were removed.
