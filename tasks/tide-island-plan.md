# Tide-style Island integration

## Design contract

- Idle: clock, date, battery percentage and charging status. Charging uses a green accent plus a bolt, so colour is not the only indicator.
- Playback: compact title, cover, real shared CAVA and playback controls in a hover peek.
- Click / Super+I: morph into a focused workspace overview. Three small navigation actions: Workspaces, Music, Clipboard. No old Dashboard, avatar, calendar, weather grid, Wi-Fi or Bluetooth controls.
- Workspace peek: compact numbered buttons; expanded: monitor-aware desktop thumbnails, workspace activation and window movement. Empty workspaces remain selectable.
- Notifications: Tide-style compact text capsule, expand to read/actions; keep Caelestia's NotificationServer, destination, DND, expiry and history.
- Clipboard: existing cliphist / wl-clipboard history, search, text/image copy and selected entry deletion. Do not start duplicate watchers.
- Use Caelestia tokens, native QML and shared services. Animate width, height and radius together using Tide's OutQuint morph; no perpetual idle animation.
- Per-screen geometry, bounded width/height, click-away/Escape, existing compatibility IPC and Settings must continue working.

## Reference

Tide-island source reviewed at `e44fe2a5b7e09e0aacec98e18128ade662102f6f`. Reference components downloaded to `/tmp/tide-clipboard.qml` and `/tmp/tide-workspaces.qml`. Rebuild the useful interaction structure using existing Caelestia services instead of introducing Tide's duplicate C++ backend.

## Recovery

Pre-integration modified files and the initial tracked diff are saved in `/tmp/caelestia-before-tide-integration`. This snapshot includes the user's earlier Island changes.

## Validation completed

33 live interaction checks passed. QML load/lint and Lua compilation passed. Live checks cover real screenshots, workspace selection/window movement, clipboard text and binary round trip, notification actions/hover/expiry/DND, media controls, Escape/click-away, both monitors, fullscreen and disabled guards. See `tide-runtime-results.json` and `dynamic-island.md`. Six clipboard contract tests pass; an ID-validation mutation is detected.
