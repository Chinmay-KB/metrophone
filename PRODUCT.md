# Product

<!-- impeccable:product-schema 1 -->

## Platform

android

## Stack

Flutter and Dart own the launcher UI, state, and persistence. A Kotlin Android
bridge owns Home-role integration, installed-app discovery and launching,
notification access, and icon rendering. The UI consumes the reusable
`wp_pivot_flutter` component package rather than reimplementing its measured
Windows Phone primitives.

## Users

The primary user is an Android owner who wants a daily-usable launcher that
behaves and reads like Windows Phone 8.1, not an Android grid wearing Metro
colors. The first implementation is being built and evaluated by the project
owner against the Windows Phone emulator research corpus.

## Product Purpose

Metrophone replaces the Android Home surface with a Start screen of resizable,
persistent tiles and a horizontally adjacent alphabetical app list. Success
means the launcher can perform the essential Home jobs—find, pin, resize,
unpin, and launch apps—while the visible geometry and motion remain grounded
in captured Windows Phone behavior.

## Positioning

Metrophone combines real Android launcher capabilities with a separately tested
component library whose tile, app-list, alphabet, lateral-navigation, tilt, and
stagger primitives are measured against a Windows Phone 8.1 emulator.

## Operating Context

The launcher is encountered whenever Android returns Home. People swipe between
Start and the app list, scroll both surfaces, tap to launch, hold tiles to edit,
use alphabet jump navigation for large catalogs, and occasionally enter
Android-owned consent screens for the Home role or notification access.

## Capabilities and Constraints

- Preserve the existing controller, persistence, platform-channel, app-catalog,
  icon, Home-role, and notification implementations.
- Use `wp_pivot_flutter` for reusable presentation and interaction primitives.
- Keep launcher-specific discovery, launching, ordering, persistence, and live
  data in this app, outside the component package.
- Support small, medium, and wide persisted tile sizes and notification-derived
  live content.
- Microsoft artwork and proprietary icon assets are not part of the project;
  installed-app icon layers and OFL-licensed Selawik are the available assets.
- Emulator host-capture timestamps do not qualify exact native animation curves
  or physical latency. Such claims remain explicitly bounded.

## Brand Commitments

The product name is Metrophone. The requested visual authority is the captured
Windows Phone 8.1 Start/app-list experience: black field, flat saturated tile
planes, lightweight typography, explicit square geometry, lateral spatial
navigation, press tilt, and right-edge staggered scene transitions. Fidelity to
that reference takes precedence over generic Material styling on the Home
surface, while Android-owned system flows remain native Android UI.

## Evidence on Hand

- `C:\Users\Chinmay\wp_pivot_flutter_site\research\start-screen` contains the
  component contract, research article, and tracked runtime summary.
- `C:\Users\Chinmay\wp_pivot_flutter_site\artifacts\launcher-primitives-01`
  contains the local native captures, deterministic Flutter renders, trajectory
  comparisons, and side-by-side stagger evidence.
- `docs/VERIFICATION.md` records a working Android API 35 launcher path with
  Home-role, notification, app-catalog, pin, launch, and return-to-Home checks.
- No user testimonials, commercial claims, or Lumia hardware captures are on
  hand and none should be fabricated.

## Product Principles

1. Behave like a launcher before looking like a theme.
2. Prefer measured Windows Phone relationships over approximate nostalgia.
3. Keep Android authority and consent explicit and reversible.
4. Keep private notification content on-device and user-controllable.
5. Retain evidence for every material fidelity claim.

## Accessibility & Inclusion

Preserve semantic labels, keyboard/focus operation where Flutter supports it,
system font scaling, high foreground contrast, and reduced-motion behavior.
Android system Back and lifecycle behavior must remain trustworthy.
