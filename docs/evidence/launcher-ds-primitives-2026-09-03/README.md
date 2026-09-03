# Launcher DS-primitives integration evidence (PR #4)

Date: 2026-09-03. Branch: `codex/consume-ds-primitives`, app `0.1.3+5`,
`wp_pivot_flutter` @ `127e5949afd2a571a915b69a4b14c76274e93b04`.

Device: Android API 35 `sdk_gphone64_x86_64` emulator (`pixel_play`),
1080x2400, debug APK, `adb screenrecord` (H.264, ~2.5 fps on debug build).

- [Walkthrough](walkthrough.mp4) (36 s): Start -> swipe to Apps -> tap
  search circle -> Back x2 -> swipe to Start.
- [Apps with search open](apps-search-open.png): X close affordance,
  underline field with cursor, `c/d/e/f/g` section headers, Calendar through
  Gmail rows on the black field.

## Fidelity vs Windows Phone (pre-merge check)

Reference: `docs/evidence/launcher-ui-2026-08-30/comparisons/apps-side-by-side.png`
(native WP8.1 emulator frame, left) and `round-03/apps.png` (settled runtime).

- Composition matches: circular search/close affordance top-left, 74-unit row
  cadence, accent-outlined section-header frames, black field, white labels,
  blue tile planes. The refactor changed no app-row code (`_AppRow` is
  byte-identical to `main`); geometry is preserved.
- Open deviation in this capture: installed-icon glyphs render as flat blue
  planes (no white decals), while `round-03/apps.png` on the same emulator
  profile shows settled glyphs. Cause is unsettled icon layers in this debug
  session, not the refactor (icon path untouched). Re-verify on a settled
  release run before claiming icon fidelity.
- Motion: emulator recording cadence (~2.5 fps, debug) cannot qualify the
  240 ms lateral, 440/340 ms alphabet, or 280/320 ms scene durations. Those
  remain covered by widget tests and the deterministic launch-exit capture in
  `launcher-ui-2026-08-30/deterministic/`, not by this video.
