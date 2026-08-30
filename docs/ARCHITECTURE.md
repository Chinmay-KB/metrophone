# Architecture

## Boundary

The scaffold keeps Android policy and framework APIs below a typed platform
boundary. Flutter owns launcher state and rendering; Kotlin owns capabilities
that only Android can provide.

```text
wp_pivot_flutter primitives + Metrophone launcher policy
                         |
                 LauncherController
                    |             |
                TileStore     LauncherPlatform
                    |             |
              Shared prefs  MethodChannel + EventChannel
                                   |
                            Android LauncherBridge
                              |       |       |
                           packages  roles   notifications
```

The UI consumes `LauncherController` only. `WpSplitSurfaceView` hosts the Start
and apps surfaces; `WpTileGrid`, `WpTile`, `WpAppListView`, `WpAlphabetGrid`,
and `WpStaggeredSceneTransition` supply reusable Windows Phone geometry and
motion. Metrophone retains Android catalog/launch behavior, persistence,
first-fit placement, search, pinning, live-content, and sequencing policy.

## Startup flow

1. Subscribe to notification events before reading initial state.
2. Load the installed app catalog, capabilities, active notifications, and
   persisted tiles concurrently.
3. Remove persisted tiles for packages that are no longer installed.
4. Publish one ready state to the UI.
5. Refresh catalog, capabilities, and notifications when Android resumes the app
   after a system consent screen.

## Tile state

`PinnedTile` intentionally stores only stable user choices:

- package name;
- small, medium, or wide size;
- live content enabled or disabled;
- list position, represented by persisted order.

Labels, activities, icons, and notifications remain runtime data. This prevents
stale app metadata from being permanently copied into launcher preferences.

## Live tiles

The notification listener stores active notifications by Android notification
key. The event channel emits posted, removed, and reset events. Flutter aggregates
the latest title/text and active count per package into `LiveTileContent`.

The pipeline is presentation-neutral. The current wide-tile presentation can
evolve without changing Android integration. Notification text must be treated
as private user data: keep it on-device, avoid analytics, respect lock-screen
privacy, and preserve per-tile opt-out.

## Extension points

- Replace shared preferences with a database when tile layouts gain folders,
  multiple screens, or migration-heavy schemas.
- Add an icon memory/disk cache behind `LauncherPlatform.getAppIcon` when its
  density and invalidation contract is defined.
- Add package-change broadcasts to refresh the catalog immediately instead of
  relying on resume/manual refresh.
- Add app shortcuts and widgets behind separate repositories; do not overload
  notification-derived live tiles with unrelated Android APIs.
- Add a lock-state privacy policy before showing notification bodies on a real
  always-visible launcher surface.
