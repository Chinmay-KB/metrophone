# Metrophone

Metrophone is an Android launcher scaffold inspired by the Windows Phone Start
screen. The native launcher, app catalog, tile state, notification-backed live
tile pipeline, and icon rendering are implemented. The current Flutter surface
is intentionally plain so the next phase can concentrate on the final UI.

## What works

- Registers as an Android Home app and requests the Home role with user consent.
- Discovers and launches every activity that advertises itself as launchable.
- Persists pin, unpin, ordering, tile size, and live-tile enabled state.
- Receives active notification snapshots and posted/removed events after the
  user grants notification-listener access.
- Aggregates current notifications per package into UI-neutral live-tile data.
- Returns native monochrome adaptive-icon layers when available and otherwise
  derives a white transparent PNG without modifying the installed application.
- Uses `wp_pivot_flutter`'s `WpPivotView` as the component-library host for the
  basic Start/apps shell.
- Is covered by Dart unit/widget tests and a real Android integration test.

## Run it

Requirements: Flutter 3.22 or newer, Android SDK 35 or newer, and an Android
device or emulator.

```powershell
flutter pub get
flutter test
flutter run -d <android-device-id>
```

Use **set as home** and **enable live tiles** in the basic shell. Both actions
open Android-owned consent UI; Metrophone does not try to bypass user consent.

The component library is pinned to the exact Git commit containing its 2.2.0
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
- `lib/src/ui`: deliberately basic replaceable shell.
- `android/.../LauncherBridge.kt`: Android app catalog, launch, roles, and settings.
- `android/.../notifications`: notification listener and event repository.
- `integration_test`: bridge verification on a real Android runtime.

See [architecture](docs/ARCHITECTURE.md),
[Android capabilities](docs/ANDROID_CAPABILITIES.md), and
[verification evidence](docs/VERIFICATION.md) before building the final UI.
