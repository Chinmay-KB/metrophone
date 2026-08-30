# Architecture

## Boundary

The scaffold keeps Android policy and framework APIs below a typed platform
boundary. Flutter owns launcher state and rendering; Kotlin owns capabilities
that only Android can provide.

```text
Flutter UI (replaceable)
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

The UI consumes `LauncherController` only. A redesign should replace widgets in
`lib/src/ui` while retaining the controller, models, store, and platform layer.
The current two-page shell is hosted by `WpPivotView`, so the component library
remains the navigation and motion foundation rather than a one-off visual import.

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

The pipeline is presentation-neutral. A final tile UI can rotate, flip, paginate,
or suppress content without changing Android integration. Notification text must
be treated as private user data: keep it on-device, avoid analytics, respect lock
screen privacy, and provide per-tile opt-out.

## Extension points

- Replace shared preferences with a database when tile layouts gain folders,
  multiple screens, or migration-heavy schemas.
- Add an icon memory/disk cache behind `LauncherPlatform.getAppIcon` once the final
  density and invalidation behavior are known.
- Add package-change broadcasts to refresh the catalog immediately instead of
  relying on resume/manual refresh.
- Add app shortcuts and widgets behind separate repositories; do not overload
  notification-derived live tiles with unrelated Android APIs.
- Add a lock-state privacy policy before showing notification bodies on a real
  always-visible launcher surface.
