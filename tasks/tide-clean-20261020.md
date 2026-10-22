# Tide clean implementation — 20 October 2026

Implemented the approved plan against the supplied historical recording. The existing Geist/neutral palette pass remains the foundation. Work is applied to the live desktop; no commit was created because this checkout already contains extensive unrelated pending changes.

## Delivered behavior

- Larger 190×36 idle capsule, 320–400×36 media capsule, persistent clock in audio/volume/player states. Actual system audio and MPRIS determine activity; the spectrum uses the existing audio service.
- Container morph is 380 ms OutCubic. Content fades separately, with a fixed natural pane width during geometry changes. Closed content survives its exit fade. The compositor skips its own animation for this shell layer.
- Main Control Center is 424×326 px. Wi-Fi and Bluetooth details are 300×366 px on opposite sides, separated by 12 px. Narrow outputs use inline details. Separate card and switch targets avoid accidentally disabling connectivity.
- Player is 400 px wide; optional unavailable timing/seek controls are handled truthfully. Notification backend/actions/history remain connected to existing services.
- Secondary controls remain reachable through More, native tray menus, Super+V and explicit page navigation. Hover preview, click pinning, Escape ordering and fullscreen overlays were exercised natively.
- Input masks follow visible surfaces. A slider press temporarily retains the whole output's pointer region, fixing fast drags that crossed the panel edge and canceled the preview. The normal desktop is clickable again on release.
- Removed the decorative desktop frame. Each output reserves a constant 48 px for the resting capsule, independent of expanded dimensions; fullscreen removes the reservation.
- Dwindle, border resize, manual resize animations, slide entry/exit/workspaces, fixed 24/8 px repeating binds, resize submap with visible cue and safe exits. Floating minimum is 320×180. A correction handles dwindle splitter direction on either side of a split.
- Bibata Modern Ice v2.0.7 at 24 px, synchronized with compositor and GTK cursor settings. Geist installed for fontconfig and GTK/Qt/shell sans UI; Maple Mono remains the monospace family.

## Verification and practical limits

Evidence directory: `/home/dorriss/Backups/tide-clean-20261020/`.

- `resize-results.json`, `resize-final-results.json`: measured coarse/fine/repeat/submap/mouse changes. Latest demo: 700×420 → 1108×420 with held coarse key; fine height 420→428; mouse drag 1108×764→1258×854. Earlier two-window tiled checks verified growth/shrink direction after the splitter fix.
- `mutation-check.json`: deliberately disabled the floating minimum guard; native check detected 296 px width, then passed at 320 px after restoration.
- `interaction-results.json`, `page-and-geometry-results.json`, `additional-runtime-results.json`: native Escape ordering, shortcuts, card navigation without radio toggling, notification action callback, DND guard, fullscreen behavior, boundary recovery, laptop backlight and both detail panels.
- `refinement-runtime-results.json`: larger dimensions, 48 px reservation on both outputs, monotonic opening geometry, hover, fast drag outside the panel, release collapse, real silent PipeWire stream and volume feedback, detail panels and More. Early versions of this test exposed the pointer-region bug; the final version passes after its fix.
- `final-pane-results.json`: all nine page loaders opened after the font synchronization. `laptop-refinement-result.json`: updated controls/details on the 1920×1200 laptop screen, followed by restoring focus to the 1920×1080 primary output.
- Existing activity JavaScript tests: 7 passed. Existing Python helper tests: 8 passed. Lua syntax, live Hyprland config errors and `git diff --check` clean. QML runtime has no new errors; the existing qtengine absolute-path watcher warning remains.
- `resource-after.json`: eight-second closed-panel sample, two outputs, no recorder/test audio: ~0.75% of one CPU core, RSS 442–447 MiB. Baseline RSS was ~470 MiB, but the baseline CPU figure was a lifetime average, so this is not a controlled performance comparison.
- `island-demo.mp4` (~8 s) and `resize-demo.mp4` (~5 s) are actual 1920×1080 captures at 60 fps. Media page in the latest Island recording is intentionally empty because the user's previous media app had closed; playback had already been tested against the real MPRIS player earlier.

The aggregate `validate-runtime.py` is an earlier diagnostic script, not an all-pass report: its focus synchronization assumption failed when crossing an empty output. Laptop, fullscreen and other remaining cases were then checked separately and recorded in the files above. Theme configuration is synchronized; an already-open GTK/Qt app can require reopening to apply fonts/cursors. Different app themes and wallpaper still affect the reference's glass appearance.

All disposable test windows, recorders and silent streams were stopped. The primary workspace and original terminal were restored. Audio volume was restored exactly, laptop brightness restored after its test, DND false and Keep Awake true.

## Review

Reviewed the task-only archive comparison for state/lifecycle correctness, loader sizing, input-region boundaries, keyboard exits, native service use and timer/resource behavior. No new dependency or external request path was added to the shell. Network/password operations continue through existing Nmcli; no credentials were recorded. Changes are split across compact, controls, detail, media and auxiliary components, with geometry/navigation in Wrapper.

## Sources and delivery

- User recording: `/home/dorriss/Videos/Recordings/recording_20261019_23-51-12.mp4`, especially player ~5 s and controls/details ~49–52 s.
- [Tide Island](https://github.com/enhaoswen/Tide-island), [author's Hyprland configuration](https://github.com/enhaoswen/swen_hyprland_dotfile), installed Hyprland 0.56.2 Lua API stubs and configuration.
- [Bibata](https://github.com/ful1e5/Bibata_Cursor/releases/tag/v2.0.7); Geist's OFL accompanies both font copies.
- User reference: `/home/dorriss/Backups/tide-clean-20261020/SHORTCUTS.md`. Change/restore notes: `CHANGES.md` in that directory. Original Geist-pass backup remains at `/home/dorriss/Backups/island-geist-20261020/`.
