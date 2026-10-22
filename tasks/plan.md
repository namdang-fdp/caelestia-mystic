# Plan: Tide video island, usable window resizing and consistent pointer UX

Status: approved by the user and implemented, 20 October 2026. Delivery and verification: [tide-clean-20261020.md](tide-clean-20261020.md).

## Target and evidence

The supplied recording is the visual target: recording_20261019_23-51-12.mp4. Current Tide upstream is technical reference; its newer UI must not silently replace the historical video design. Compare player around 5 s, notification/overview around 32 s, Control Center around 49 s, and Wi-Fi/Bluetooth side panels around 52 s.

Keep the approved Geist Sans and neutral black palette. Replace the broad tabbed dashboard presentation with a small capsule and task-sized panels. The existing Caelestia service layer remains the implementation foundation.

Observed: live Hyprland 0.56.2 uses master layout; manual resize and mouse drag animation are enabled; windowsMove is speed 2.5. Super+Alt+arrows and Super+Minus/Equal already exist, with repeat=true. Mouse move/resize binds are declared but hyprctl exposes mouse=false. This is diagnostic evidence, not a proven root cause: installed examples and public docs use the current declaration, so reproduce the actual interaction before choosing a fix. The current helper changes size by 10% of the window rather than 10 pixels. The active-window size.x/size.y fields were checked read-only and exist.

## Visual and interaction contract

- Resting capsule: 190×36 px, top margin 8 px, enlarged after the user's live feedback. Clock plus a quiet short date. Microphone, Keep Awake and detailed battery text move into expanded views; relevant alerts retain priority.
- Media capsule: 320–400 px wide, 36 px high; persistent clock, cover when available, one short title, subtle real audio spectrum. Volume feedback also retains the clock. Player is 400 px wide with its own clock, art/title/artist/progress and playback controls.
- Control Center: target 420–460 px wide; small clock/date/battery header, Wi-Fi and Bluetooth cards, rounded brightness and volume bars. Secondary controls are available through a compact More action.
- Detail panels: Wi-Fi opens on the left and Bluetooth on the right, each about 280–320 px wide with 12 px gaps. Fit and clamp to each output; on narrow screens use an inline detail view with Back. The card body opens details; a distinct switch toggles connectivity. Pairing/network clicks must not accidentally disable adapters.
- No permanent tab row, decorative headline or empty space reserved for absent content. Every panel sizes to its content. Clipboard, notifications, workspaces, VPN, microphone, recording, Info and power remain reachable through explicit shortcuts or secondary actions.
- Capsule click: media player when media exists, otherwise Control Center. Right click: Control Center. Middle click: workspaces. Super+I toggles Island; Super+V keeps clipboard access. Hover after 260 ms opens a compact contextual preview; moving into that preview keeps it open. Leave grace period 300 ms. Active slider dragging retains pointer input beyond the panel until release. Escape closes the topmost detail before the parent; clicking elsewhere closes the island.
- Pointer: Bibata Modern Ice, 24 px, consistent across compositor, GTK, Qt and XWayland. Resize cursor at borders, I-beam in inputs, pointing hand on actions, correct disabled state. No unexpected cursor warp when opening the island.
- Geometry morph: 380 ms OutCubic for width, height and radius, revised after the user's motion feedback. Content opacity animates separately; text retains its native scale and natural layout width. Retarget transitions and prevent double animation by the compositor. Respect the existing motion scale.

Dimensions and delays are initial targets, to be adjusted against captures from the supplied video at the same display scale.

## Proposed resize controls

| Binding | Behavior |
|---|---|
| Super + Alt + Left / Right | Width -24 / +24 px; hold to repeat |
| Super + Alt + Up / Down | Height -24 / +24 px; hold to repeat |
| Super + Alt + Shift + arrows | Same axes, fine 8 px steps |
| Super + Ctrl + R | Enter resize mode, show a small RESIZE hint |
| Arrows while in resize mode | Resize with the same 24 px steps; Shift gives 8 px |
| Escape or Enter in resize mode | Leave the mode and clear the hint |
| Super + right mouse drag | Resize the window under the pointer |
| Super + left mouse drag | Move the window under the pointer |
| Super + Alt + Space | Toggle floating/tiled, preserving the familiar existing binding |
| Super + Alt + C | Center a floating window |
| Drag a window border | Resize with a suitable visible hit area and resize cursor |

Recheck conflicts at implementation time. Keep existing workspace, launcher and fullscreen shortcuts. Floating windows support free geometry; tiled windows respect the split/layout constraints. A single tiled window cannot become a small floating window merely through a resize key. Ignore or explain unsupported fullscreen operations, clamp floating minimum sizes, and ensure a resize submap can always be exited.

## Desktop motion and materials

Use dwindle as the proposed default to match the author's split-oriented setup, with reversible config backup. Tune windowsMove toward speed 4–5 and bezier (0.16,1,0.3,1), slide window entry/exit and a restrained workspace slide. Validate responsiveness during continuous resize; reduce motion lag if necessary. Keep the recently approved black shadows and blur; remove the decorative purple full-screen frame and calculate the island's top reservation independently so windows remain reachable. Keep application content/text legible. Do not introduce wobble plugins or blanket extra opacity as a substitute for material styling.

## Ordered tasks

1. Baseline and resize reproduction. Snapshot settings/live binds, screenshots, window geometry and resource sample. Use disposable test windows to exercise the existing keyboard/mouse binds on master, floating and fullscreen; inspect logs and Lua dispatch behavior. Acceptance: each reported failure has a reproducible scenario or a documented unresolved condition. Files: task evidence, relevant Hypr Lua files read-only. Depends: none.
2. Repair resize and add the proposed controls. Prefer user overrides; fix a helper only if the reproduction proves it wrong. Acceptance: each key changes measured geometry, repeat works, the submap exits reliably, mouse drag resizes the intended window, constraints are respected. Files: hypr-user.lua, any proven helper fix, evidence. Depends: 1.
3. Layout and compositor motion. Apply dwindle and tune geometry/entry/exit/workspace motion, enable border resizing with clear hit areas. Acceptance: actual geometry and capture show smooth resizing, no trapped or inaccessible windows, fullscreen and two outputs work. Files: hypr-user.lua, hypr-vars.lua, evidence. Depends: 2.
4. Pointer consistency. Install the verified Bibata Modern Ice assets, set matching compositor/toolkit settings, and use a native Hyprcursor variant only if a compatible asset exists. Acceptance: matching pointer shape/size on desktop, terminal, browser, Island and an XWayland app; resize and text cursor shapes work. Files: theme assets, user env/config, toolkit settings. Depends: 1.
5. Compact capsule. Implement idle/media/recording/alert states and move secondary controls to their destinations. Acceptance: normal idle fits the target size; real activities and essential warnings remain truthful; no layout jumps or clipped labels. Files: IslandCompact.qml, IslandBattery.qml, IslandAwakeBadge.qml, Wrapper.qml. Depends: 1.
6. Player and notification capsule. Rebuild the small player and notification presentation. Acceptance: available playback controls work, paused state is clear, seek availability is respected, notification actions/history/expiry remain functional. Files: IslandMediaView.qml, IslandSpectrum.qml, IslandNotification.qml, Wrapper.qml. Depends: 5.
7. Compact Control Center. Build clock/date/battery header, two connectivity cards, pill sliders and secondary controls. Acceptance: all existing settings remain reachable, content fits without large decorative headings, toggles and detail navigation have separate targets. Files: IslandControlsView.qml, IslandConnectionsView.qml, shared button/slider component as needed, Wrapper.qml. Depends: 5.
8. Connectivity detail panels. Implement the side panels, screen-aware positioning and keyboard navigation. Audit the existing network-loading lifecycle and bound loading/error states before moving it into the new presentation. Acceptance: connected/empty/loading/error states complete visibly; travel between parent and details does not collapse them; edge and small-screen cases fit. Files: connectivity view, at most two detail components, Wrapper.qml, drawer input regions. Depends: 7.
9. Navigation, motion and desktop frame. Remove permanent tabs, wire the specified click/hover/keyboard rules, animate container and content coherently, and remove the decorative full-screen frame while preserving correct reserved space. Split into separate increments if it exceeds five touched files. Acceptance: no double scaling, no flicker on rapid reversal, no transparent surface stealing clicks, top reservation stable throughout expansion. Depends: 3, 6, 8.
10. Final validation and delivery. Compare the named video scenes with side-by-side screenshots and a short local recording. Test both outputs, cursor shapes, keyboard-only flows, fullscreen, rapid transitions and actual resize geometry. Sample whole-shell resource use against baseline, check QML/Hypr logs and diff hygiene. Deliver binding cheat sheet, before/after captures and rollback notes. Depends: 2–9.

## Checkpoints and done criteria

- After resize work: demonstrate actual keyboard and mouse resizing, including repeat, floating/tiled constraints and reliable mode exit.
- After capsule/player work: compare idle, media and notification geometry/motion directly with the video.
- After Control Center/details: review a near-reference screenshot and test card-vs-switch behavior.
- Complete: no new QML/Hypr configuration errors; both monitors behave correctly; user functions remain reachable; essential states are readable; resources have no unexplained sustained regression; backups and a clear shortcut reference exist.

## Risks and decisions

The clip shows an older Tide revision and its wallpaper/app themes contribute to its appearance. Match the observed Island silhouettes, density and interactions; exact pixel equality across different app content and display refresh rates cannot be guaranteed. Preserve behavior while relocating controls. Extra side panels require matching pointer/input regions and monitor-edge handling. Dwindle is an intentional workflow change, explicitly included in this proposal. Font/material work already approved remains the starting point.

## Sources

- Supplied local recording and existing live configuration.
- https://github.com/enhaoswen/Tide-island
- https://github.com/enhaoswen/swen_hyprland_dotfile/blob/main/hypr/hyprland.conf
- https://wiki.hypr.land/0.56.0/Configuring/Basics/Binds/
- Installed API references: /usr/share/hypr/stubs/hl.meta.lua and /usr/share/hypr/hyprland.lua.
