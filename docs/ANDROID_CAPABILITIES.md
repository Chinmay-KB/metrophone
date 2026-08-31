# Android capabilities and consent

Metrophone follows Android's role and listener models instead of requesting a
large blanket permission set.

| Capability | Mechanism | User action | Current use |
|---|---|---|---|
| Home launcher | `MAIN` + `HOME` + `DEFAULT` activity filter and `ROLE_HOME` | Approve Android's Home-role prompt | Receive Home and stay out of the recent-app stack |
| App catalog | `queries` for `MAIN` + `LAUNCHER` activities | None | List only apps that can actually be launched |
| App launch | Explicit component intent | Tap an app/tile | Start the selected launchable activity |
| Live notifications | `NotificationListenerService` protected by `BIND_NOTIFICATION_LISTENER_SERVICE` | Enable Metrophone in Android's notification-access screen | Maintain active notification snapshots and events |
| Tile preferences | App-private shared preferences | None | Persist pin/order/size/live-enabled choices |

`QUERY_ALL_PACKAGES` is deliberately absent. Intent-based visibility is enough
for a launcher app list and avoids a sensitive Google Play declaration. If a
future feature truly requires non-launchable packages, reevaluate that feature
and Play policy before expanding visibility.

`POST_NOTIFICATIONS` is also absent. Metrophone reads notifications after the
separate notification-listener grant; it does not currently post its own Android
notifications.

## White icon pipeline

Metrophone never changes another application's icon or APK.

1. On Android 13+, use an adaptive icon's authored monochrome layer when present.
2. For adaptive icons without one, render the foreground layer and tint its alpha
   mask white.
3. For legacy icons, derive a white mask and attempt to remove a uniform opaque
   corner background.
4. Return an in-memory PNG plus a flag indicating whether the source was an
   authored native monochrome layer.

The fallback cannot infer the semantic logo inside every photographic or gradient
legacy icon. A future icon-settings surface should offer per-app overrides and
retain the original-color icon as a fallback.

Relevant Android references:

- [Home roles](https://developer.android.com/reference/android/app/role/RoleManager)
- [Package visibility](https://developer.android.com/training/package-visibility/declaring)
- [NotificationListenerService](https://developer.android.com/reference/android/service/notification/NotificationListenerService)
- [Adaptive and monochrome icons](https://developer.android.com/develop/ui/compose/system/icon_design_adaptive)
