---
name: Metrophone
description: A native Android Home surface built from measured Windows Phone 8.1 launcher primitives.
colors:
  field: "#000000"
  foreground: "#FFFFFF"
  accent: "#3E65FF"
  progress-track: "#202020"
  secondary-text: "rgba(255, 255, 255, 0.70)"
  hint-text: "rgba(255, 255, 255, 0.54)"
  tile-green: "#107C10"
  tile-orange: "#EB3C00"
  tile-purple: "#80397B"
  tile-pale-blue: "#9DAFFF"
typography:
  wp-light:
    fontFamily: "Selawik"
    fontWeight: 300
  wp-regular:
    fontFamily: "Selawik"
    fontWeight: 400
rounded:
  square: "0px"
---

# Design System: Metrophone

## Overview

**Creative North Star: “The Spatial Start Screen”**

Metrophone is a phone-first, native Flutter Android launcher whose primary surface behaves like Windows Phone 8.1 rather than like an Android app grid with Metro styling. Its visual thesis is a black field, flat saturated tile planes, light Selawik typography, explicit square geometry, lateral navigation, press tilt, and staggered scene movement. The launcher's first job is still to be a trustworthy Home surface: glance at live tiles, swipe once to the alphabetical catalog, hold to edit, and tap to launch.

The reference world is deliberately spare. There is no decorative app chrome, card framing, floating panel, gradient, or ornamental shadow on the Home surface. Android-owned consent screens remain native Android UI; Metrophone does not restyle or imitate them.

**Key characteristics:**

- Black edge-to-edge field with white type and a saturated blue default accent.
- A measured four-column Start grid and an adjacent alphabetical app catalog.
- Lightweight type, square tile geometry, and depth communicated through motion rather than shadow.
- Installed-app icons and notification-derived live content, kept inside the WP8.1 composition.
- System insets, Android Back, semantics, and reduced-motion behavior treated as launcher requirements.

### Evidence and limits

This document describes the implementation represented by `PRODUCT.md`, `README.md`, `lib/src/ui/launcher_screen.dart`, `lib/src/ui/launcher_tile_layout.dart`, `pubspec.yaml`, and the final Android captures in `docs/evidence/launcher-ui-2026-08-30/`. The reusable visual primitives come from `wp_pivot_flutter` 2.3.0 pinned at Git commit `c75bda8`.

The recorded fidelity scope is specific: at the 480×800 reference viewport, held-out comparisons cover 11 Start tiles, 10 visible app-list slots, and all 28 alphabet cells with zero edge error; a 1080×2400 Android emulator check was within one physical pixel. The deterministic capture verifies the shipping 280 ms exit sequence and launch-after-exit behavior. Native Windows Phone easing and physical latency remain qualitative because the emulator host recording cadence cannot establish exact curves. The shipped target documented here is an Android phone; no tablet, foldable, landscape, or desktop layout contract is established by this evidence.

## Colors

The palette is a high-contrast black-and-white shell punctuated by flat, saturated tile planes. The YAML tokens above are normative.

### Primary

- **Metro Blue** (`accent`): the default tile plane, focused search underline, progress indicator, enabled alphabet cells supplied by the component system, and failure action background.

### Secondary

- **Game Green** (`tile-green`): assigned when an app identity contains “music” or “game.”
- **Office Orange** (`tile-orange`): assigned when an app identity contains “office.”
- **Notebook Purple** (`tile-purple`): assigned when an app identity contains “note.”
- **People Pale Blue** (`tile-pale-blue`): assigned when an app identity contains “people” or “contact.”

These are implemented launcher policies, not a general-purpose rainbow. All other pinned apps use Metro Blue.

### Neutral

- **Black Field** (`field`): the launcher, Start, app-list, alphabet, setup, notice, loading, and failure backgrounds.
- **White Foreground** (`foreground`): primary labels, icons, rules, and system-bar icon treatment.
- **Progress Track** (`progress-track`): the subdued loading track; the component library also supplies its own measured disabled alphabet-cell treatment.
- **Secondary White** (`secondary-text`): failure detail text.
- **Hint White** (`hint-text`): inactive search placeholder text.

**The Flat Plane Rule.** Tile identity is expressed by a single solid color plane. Do not add gradients, glass, outlines, or shadows to make tiles feel richer.

**The Black Field Rule.** Launcher-owned surfaces stay black. Color belongs to tiles, selection, focus, and essential state—not to extra containers.

## Typography

**Display and UI font:** Selawik, inherited through the Windows Phone component theme. The launcher uses light weight for large, characterful type and regular weight where control clarity matters.

The component package owns the measured typography for tiles, app rows, headers, and other reusable WP primitives. Launcher-owned type observed in the implementation is limited and purposeful:

- **Alphabet cells:** 50 reference units, weight 300, line height 1; the globe icon is 38 reference units.
- **Failure headline:** 34 logical pixels, weight 300.
- **App search input:** 25 reference units, white; its cursor is Metro Blue.
- **Live-tile title:** 19 logical pixels, one line with ellipsis.
- **Live-tile body:** 16 logical pixels, line-height multiplier 1.12, at most two lines with ellipsis.
- **Live notification count:** 25 logical pixels, weight 300.
- **Empty-state instruction:** 21 logical pixels, weight 300, line-height multiplier 1.25, centered.
- **Setup controls:** 18 logical pixels, weight 400.
- **Pin/unpin notice:** 19 logical pixels.

Reference-unit sizes are multiplied by `screenWidth / 480`; unmarked launcher-owned logical-pixel sizes remain fixed as implemented.

**The Lightweight Voice Rule.** Use weight 300 for prominent Windows Phone-style display text. Reserve weight 400 for controls and utility copy; do not introduce bold hierarchy unless the component library already specifies it.

**The Component Type Rule.** Do not restyle library-owned tile labels, app rows, or headers locally. Extend the shared WP theme or component package when their typography must change.

## Layout

Metrophone composes a 480-unit-wide WP8.1 reference system and scales selected reference geometry by `screenWidth / 480`. The entire Home experience is two horizontally adjacent surfaces owned by `WpSplitSurfaceView`: Start first, apps second. Swiping or the empty-state affordance moves laterally between them.

### Start geometry

- The tile field begins at reference y=56.
- Tiles pack into four columns in persisted order, always choosing the first available cells.
- Small tiles occupy 1×1 cells, medium tiles 2×2, and wide tiles 2×4.
- The component library owns physical cell size, gap, grid edge geometry, tile clipping, and measured hit behavior. The launcher supplies only row, column, and span placements.
- Start scroll content reserves 32 logical pixels plus the Android bottom inset.

### App-list geometry

- The list uses a 74-unit row cadence.
- Content begins at reference x=86; the first content slot begins at reference y=51.
- The search field occupies the first slot: left 86, top 51, right 24, height 74, with an inner height of 62 reference units.
- App icons supplied by the launcher are 42 logical pixels inside the library-owned row.
- The list bottom padding is 24 reference units plus the Android bottom inset converted into reference coordinates.

### Responsive behavior

The Start top offset, app-list placement, search field, alphabet glyphs, and alphabet-cell padding scale from the 480-wide reference. Setup controls and transient notices use fixed 24-logical-pixel side and bottom offsets, then add the device bottom inset. The alphabet surface adds the status-bar top inset. This preserves the measured phone composition while keeping system-owned areas unobstructed.

**The Reference Geometry Rule.** Scale from the 480-unit source relationships; do not independently tune child widths, row heights, or offsets for a screenshot.

**The Phone Boundary Rule.** Do not infer tablet or landscape behavior from width scaling alone. A new device class requires its own measured contract and evidence.

## Elevation & Depth

The launcher is flat at rest. There are no tile shadows, card elevations, surface tints, or layered panels. Separation comes from black negative space, saturated planes, typography, and the component library's press tilt and spatial transitions. The only explicit line treatment on Start is the 2-logical-pixel white top rule above setup actions; the search field uses a one-pixel white underline at rest and a 2-logical-pixel Metro Blue underline when focused.

**The Motion-Is-Depth Rule.** Use tilt, lateral movement, and stagger to communicate spatial depth. Do not simulate depth with generic Material shadows on launcher-owned WP surfaces.

## Shapes

Square geometry is the default. Tiles, setup actions, and the failure retry action use zero corner radius. Alphabet cells remain square. The search input is an underline field rather than a rounded text box.

The one prominent exception is the app-list search/close action: a circular transparent control with a 2-logical-pixel white ring and a 28-logical-pixel white icon. This circle is a functional WP8.1 navigation affordance, not permission to round other controls.

**The Explicit Square Rule.** New launcher-owned surfaces and actions are square unless they reproduce an already-established functional silhouette such as the circular search action.

## Components

### Start tiles

- `WpTileGrid`, `WpTile`, and `WpTilePlacement` own the reusable Start presentation and interaction geometry.
- Small tiles suppress labels and use a 42-logical-pixel installed-app icon. Medium and wide tiles show the library-owned label and use a 64-logical-pixel icon.
- A wide tile with live content uses 18-logical-pixel top/side padding and 34-logical-pixel bottom padding. It places the icon, an 18-logical-pixel gap, ellipsized title/body, and an optional count when more than one notification is present.
- Tap launches when not editing. Long press enters edit mode. In edit mode, tap exits; unpin and resize actions are exposed by `WpTile`. Resize cycles the persisted small, medium, and wide states.
- Tapping the surrounding Start field clears edit mode. Changing lateral surface also clears it.
- When no tiles exist, a centered 44-logical-pixel forward arrow and the instruction “swipe to apps / then hold an app to pin it” open the app catalog.

### App list and search

- `WpAppListView`, `WpAppListHeader`, and `WpAppListRow` own the reusable list geometry and typography.
- Apps sort case-insensitively by label. A new header appears when the first normalized character changes; `a`–`z` receive their letter and all other starts map to `#`.
- Search filters case-insensitively across both app label and package name. The circular leading action toggles search/close, and the text field autofocuses in the list's first slot.
- Tap launches. Long press pins or unpins and exposes an equivalent custom semantics action. Feedback appears over the black field for 1600 ms and fades over 120 ms.

### Alphabet jump

- `WpAlphabetGrid` owns the measured 28-cell layout for `#`, `a`–`z`, and the terminal globe cell.
- Enabled letters are derived from the full installed-app catalog, not from the current search result. Selecting an enabled cell closes the grid and scrolls to the matching header; cancel returns to the app list.
- The launcher supplies white, left-aligned, lightweight glyphs with 12 reference units of left padding and 4 reference units of bottom padding. The globe cell uses the Material language icon because proprietary Microsoft artwork is not included.

### Setup, loading, and failure states

- Setup appears only while the app is not the default launcher or notification access is absent. It sits over Start on black, beneath a white top rule, and uses square text actions with a 48×48-logical-pixel minimum size.
- “set as home” and “enable live tiles” lead to Android-owned consent UI; the launcher does not counterfeit those system surfaces.
- Loading is a centered 160-logical-pixel-wide, 3-logical-pixel-high Metro Blue linear indicator on a dark track.
- Failure is a safe-area black surface with 24-logical-pixel padding, concise error text, and a square Metro Blue retry action with a 96×48-logical-pixel minimum size.

### Motion and platform behavior

- Moving to apps or returning to Start uses 240 ms with `easeOutCubic`.
- Launching waits for a 280 ms `easeInCubic` staggered exit before calling Android. Returning or recovering after a failed launch uses a 320 ms `easeOutCubic` entry.
- Alphabet jump scroll uses 220 ms with `easeOutCubic`.
- Tile stagger order comes from `WpStaggeredSceneGeometry` and is capped at 8. App-list exit order advances by 0.35 per entry and is capped at 8. Scene return is not staggered: each surface swings back as one rigid opaque page around the right edge with a mirrored rotation and no fade, matching the WP8.1 dialer-to-Start capture in `docs/evidence/launcher-start-entry-2026-09-03/`. `WpStaggeredSceneTransition` owns the reusable transform, pivots, and exit sequencing.
- Reduced-motion preference collapses surface, scene, and alphabet-jump durations to zero.
- Android Back dismisses alphabet first, then search, then returns apps to Start. At Start, `PopScope` keeps the Home surface in place rather than exiting it.
- The alphabet surface explicitly uses a transparent status bar with light icons and respects the status-bar inset. Scrollable content and overlays respect the Android navigation-bar bottom inset.
- Search, empty-state navigation, app rows, tile labels, and pin/unpin expose semantic intent; long-press pinning has a matching custom accessibility action.

### Component-library boundary

`wp_pivot_flutter` 2.3.0 at `c75bda8` owns the measured, reusable Windows Phone primitives: tile grid and tile behavior, app-list rows and headers, alphabet grid, split-surface navigation, staggered scene transforms/order geometry, press tilt, and the WP phone theme.

Metrophone owns launcher policy: Android catalog discovery and launching, installed icon rendering, persisted tile order and size, first-fit packing, pin/unpin/resize actions, notification-derived live content, app-specific tile-color mapping, search/filter rules, enabled alphabet sections, Back-state precedence, launch sequencing, capability prompts, and transient feedback. Do not move Android or launcher data policy into the component package, and do not reimplement shared WP geometry inside the launcher.

## Do's and Don'ts

### Consistency checklist — do

- **Do** keep the ready launcher on a black field with white Selawik type and Metro Blue as the default accent.
- **Do** preserve the 480-wide reference relationships, four-column tile spans, y=56 Start origin, and 74-unit app-list cadence.
- **Do** use the shared `Wp*` primitives for tiles, app rows, alphabet, lateral navigation, tilt, and stagger.
- **Do** keep small/medium/wide policy at 1×1, 2×2, and 2×4 and preserve persisted order during first-fit packing.
- **Do** keep Android Back's dismissal order and preserve status- and navigation-bar insets where a new launcher-owned overlay needs them.
- **Do** provide semantic labels or equivalent accessible actions for gesture-only behavior and honor disabled animations.
- **Do** validate material geometry against the documented 480×800 reference and an Android phone capture.

### Consistency checklist — don't

- **Don't** add Material app bars, bottom navigation, rounded cards, gradients, glass effects, shadows, or decorative chrome to the Home surface.
- **Don't** fork library-owned measurements or compensate for one device with per-child magic numbers.
- **Don't** use app color as unrestricted decoration; preserve the implemented identity mapping and blue fallback.
- **Don't** show tile labels on small tiles or expose live notification text outside the wide live-tile treatment.
- **Don't** launch before the exit sequence completes, trap Android Back, draw beneath system controls without insets, or force motion when animations are disabled.
- **Don't** restyle Android role and notification-access consent screens.
- **Don't** claim exact native Windows Phone timing, physical-device latency, or support for unverified device classes from emulator evidence.
