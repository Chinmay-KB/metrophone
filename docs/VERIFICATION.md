# Verification evidence

Verified on 2026-08-30 with Flutter 3.47.1, Dart 3.13.1, Android SDK 36,
and the `pixel_play` x86_64 emulator running Android API 35.

## Automated

```powershell
flutter analyze --no-pub
flutter test --no-pub
flutter build apk --debug --no-pub
flutter test integration_test/launcher_platform_test.dart -d emulator-5554 --no-pub
```

Observed results:

- analyzer: no issues;
- Dart/widget tests: 12 passed;
- debug APK: built successfully;
- Android integration test: passed;
- real package catalog: 21 launchable activities;
- original and monochrome icon responses: valid non-empty PNG data;
- controller reached ready state through the real method/event channels.

## UI fidelity

The final deterministic 480×800 candidate uses the same launcher widgets as the
shipping app. Held-out comparisons against the WP8.1 emulator passed:

- Start: 11 of 11 tile surfaces, zero maximum edge error;
- app list: 10 of 10 measured headers/icons, zero maximum edge error;
- alphabet: 28 of 28 cells, zero maximum edge error.

On the 1080×2400 API 35 runtime, the visible Calendar tile occupied
`(54,126)–(525,598)` versus the width-scaled expected
`(54,126)–(525,597)`, a maximum one-physical-pixel edge difference.

The launcher owns a 280 ms staggered exit and does not call the platform launch
bridge until that sequence completes. Deterministic frames are sampled every
16.667 ms. This qualifies pose order and the launcher callback contract, not an
exact match to native WP timing; the available native recording cadence is too
coarse for that claim.

## Runtime launcher path

The debug APK was installed on the emulator, granted the Home role through
Android's role command, and enabled as a notification listener. A shell test
notification was posted before starting the app.

Observed runtime evidence:

- `METROPHONE_READY apps=21 tiles=0 notifications=2 home=true`;
- Android role holder: `com.chinmaykb.metrophone`;
- notification listener bound:
  `MetrophoneNotificationListenerService`;
- Home key resumed `com.chinmaykb.metrophone/.MainActivity`;
- Calendar was pinned from the app list and appeared as a persisted Start tile;
- tapping that tile resumed Google Calendar;
- pressing Home returned focus to Metrophone.

The emulator intentionally remains configured with Metrophone as Home and with
notification access enabled for continued UI work.

See the [evidence index](evidence/launcher-ui-2026-08-30/README.md) for runtime
screens, video, deterministic frames, reports, and source snapshots.
