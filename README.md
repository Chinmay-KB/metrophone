# Metrophone

Metrophone is an Android launcher scaffold inspired by the Windows Phone Start
screen. It combines native Android launcher capabilities with the measured
Windows Phone 8.1 primitives published by `wp_pivot_flutter` 2.3.0.

| Start | Apps | Alphabet jump |
| --- | --- | --- |
| ![Metrophone Start screen](docs/evidence/launcher-ui-2026-08-30/round-02/start-settled.png) | ![Metrophone app list](docs/evidence/launcher-ui-2026-08-30/round-03/apps.png) | ![Metrophone alphabet jump grid](docs/evidence/launcher-ui-2026-08-30/round-03/alphabet.png) |

[Watch the Android walkthrough](docs/evidence/launcher-ui-2026-08-30/round-02/walkthrough.mp4)
or inspect the [complete fidelity evidence](docs/evidence/launcher-ui-2026-08-30/README.md).

## What works

- Registers as an Android Home app and requests the Home role with user consent.
- Discovers and launches every activity that advertises itself as launchable.
- Persists pin, unpin, ordering, tile size, and live-tile enabled state.
- Receives active notification snapshots and posted/removed events after the
  user grants notification-listener access.
- Aggregates current notifications per package into UI-neutral live-tile data.
- Returns native monochrome adaptive-icon layers when available and otherwise
  derives a white transparent PNG without modifying the installed application.
- Uses `WpTileGrid`, `WpTile`, `WpAppListView`, `WpAlphabetGrid`,
  `WpSplitSurfaceView`, and `WpStaggeredSceneTransition` from
  `wp_pivot_flutter`; launcher policy remains in this app.
- Packs small, medium, and wide tiles into the measured four-column Start grid.
- Supports Start editing, app search, alphabet jump, pin/unpin, Android Back,
  and a caller-owned staggered exit before launching an app.
- Is covered by Dart unit/widget tests and a real Android integration test.

## Run it

Requirements: Flutter 3.22 or newer, Android SDK 35 or newer, and an Android
device or emulator.

```powershell
flutter pub get
flutter test
flutter run -d <android-device-id>
```

Use **set as home** and **enable live tiles** when prompted. Both actions
open Android-owned consent UI; Metrophone does not try to bypass user consent.

The component library is pinned to the exact Git commit containing its 2.3.0
API because that version is not yet published on pub.dev. For local development
against a newer `wp_pivot_flutter` checkout, create an uncommitted
`pubspec_overrides.yaml`:

```yaml
dependency_overrides:
  wp_pivot_flutter:
    path: ../path/to/wp_pivot_flutter
```

## Project map

- `lib/src/models`: UI-independent launcher, tile, notification, and icon data.
- `lib/src/controller`: orchestration, persistence, and live-tile aggregation.
- `lib/src/platform`: typed Flutter interface and method/event channel adapter.
- `lib/src/storage`: tile persistence and an in-memory test implementation.
- `lib/src/ui`: Windows Phone component composition and launcher-owned policy.
- `android/.../LauncherBridge.kt`: Android app catalog, launch, roles, and settings.
- `android/.../notifications`: notification listener and event repository.
- `integration_test`: bridge verification on a real Android runtime.

See [architecture](docs/ARCHITECTURE.md),
[Android capabilities](docs/ANDROID_CAPABILITIES.md), and
[verification evidence](docs/VERIFICATION.md) when extending the launcher.
CI behavior and the required branch-protection check are documented in
[GitHub Actions](docs/CI.md).

## Fidelity scope

At the 480×800 reference viewport, the held-out geometry comparisons pass for
11 Start tiles, 10 visible app-list slots, and all 28 alphabet cells with zero
edge error. A 1080×2400 Android emulator check was within one physical pixel.
The deterministic exit capture verifies the shipping 280 ms state sequence and
that launching waits for it. Native WP motion timing remains qualitative because
the emulator recording cadence is not precise enough to claim an exact curve.
