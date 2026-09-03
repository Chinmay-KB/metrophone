# Start entry evidence (PR #4)

Date: 2026-09-03. Native source: Emulator 8.1 WVGA 4 inch 512MB
(`Emulator 8.1 WVGA 4 inch 512MB.chinmay`), 480x800, captured with
wp-mirror (`C:\Users\Chinmay\wp-mirror`), 30 fps output.

- [Native dialer -> Start](wp-dialer-home.mp4) (17 s, 513 frames): tap the
  Phone tile on Start, wait in the dialer (history page), press the Start
  button, settle back on Start.
- [Native app exit](native-app-exit.png): the dialer page swings out as one
  rigid plane anchored at its left edge.
- [Native Start entry, mid](native-start-entry-mid.png): the Start panorama
  swings back as one rigid page, right edge near the viewer and left edge
  receding. All tiles share a single transform; nothing staggers or fades.
- [Native Start entry, settling](native-start-entry-settling.png): the page
  flattens into place with the adjacent app list peeking at the right edge.
- [Launcher page entry, mid](launcher-page-entry-mid.png): deterministic
  480x800 widget render after the fix, showing the same rigid right-edge
  swing with no per-tile stagger or fade.

## What changed and why

Before: scene return staggered every tile/row with its own fade and rotation
around its own edge (exit choreography replayed in reverse). The native
capture shows return is a single opaque page swing around the right edge,
mirrored against the exit rotation.

After: exit keeps the measured per-tile/per-row stagger (`_exitOrder`,
0.35-step app rows, right-edge pivots); entry wraps each surface once
(`start-scene-page-entry`, `apps-scene-page-entry`: order 0, `fade: false`,
right-edge pivot, mirrored rotation from `wp_pivot_flutter` @ `c75bda8`).

## Limits

- Rotation magnitude/translation (-12 units) and the 320 ms `easeOutCubic`
  entry are carried over, not re-fitted; the host recording cadence cannot
  qualify exact native curves (same bound as `launcher-ui-2026-08-30`).
- The launcher does not reproduce the neighbor-surface peek visible while
  the native panorama settles.
