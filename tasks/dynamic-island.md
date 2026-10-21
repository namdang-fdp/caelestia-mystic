# Dynamic Island — Tide-style integration, 2026-10-09

The Island now presents small task-specific views instead of the old Dashboard widget grid. It keeps Caelestia's per-screen drawer integration and shared services. Tide's capsule layout, task separation and coordinated OutQuint morph are the interaction references; Tide's separate C++ backend is not required.

## Interaction

- Idle: time, short date, battery percentage and a small power-profile icon (leaf, balance or rocket). The profile icon is green for Power saver, primary for Balanced and tertiary for Performance; clicking it opens Info. Charging shows a bolt; plugged/full shows a plug. Both use a green accent. On battery, the level icon and colour change together: green at 60%+, yellow from 25–59%, and red below 25%. Battery is omitted on machines without a laptop battery.
- Playback: cover, time, a secondary label that alternates every five seconds between date and track/system-audio info, six real shared CAVA bars and battery. Paused media shows a pause mark and resting bars. Non-MPRIS system audio still uses the existing PipeWire activity tracking.
- Hover the pill for 350 ms: the full workspace thumbnail overview, without taking keyboard focus. Leave for 300 ms to collapse. Other parts of the top edge do not open the Island.
- Left click or **Super+I**: workspace overview. Middle click: Music. Right click or **Super+V**: Clipboard. Super+V again closes Clipboard.
- Expanded navigation contains Workspaces, Music, Clipboard, Info, a notification bell, Controls and Power. Icon-only buttons have tooltips. It pairs a small month calendar with CPU usage/temperature, RAM usage, primary disk usage and battery status, using the existing CPU/Memory/Storage/UPower services. Month arrows browse; clicking the month title returns to the current month.
- Each output reserves a fixed top strip for the idle capsule: border thickness + 36 logical pixels (46 with the current 10 px border). Opening, hovering or changing pages does not alter this reservation. Fullscreen and disabling the Island release the additional 36 px. There is no old Dashboard grid, avatar picker or Wi-Fi/Bluetooth control panel.
- Escape, the close button and clicking away close the expanded view.

## Workspaces

Both hover and expanded views show six desktop cells per page, with native window snapshots positioned proportionally to their actual desktop geometry. The active workspace has a highlight; empty cells can be activated. Clicking a thumbnail focuses its window. Dragging a thumbnail to another cell moves the window without switching to the destination. Arrow buttons change pages; 1–6 choose a cell and keyboard arrows change pages.

Snapshots are captured only while the overview is visible. Primitive window keys remain stable while it is mounted, then are pruned on unload. Normal/Special tabs share the same overview. Special workspaces include Default, Todo, Music, Communication, Sysmon and live custom names. Click a special cell to toggle it; drag to move between special workspaces or back to the current normal workspace. While dragging a normal thumbnail, a footer provides direct special destinations. The standalone Overview instance and Super+Tab binding have been removed.

## Notifications

The presenter uses `Notifs`/`NotifData` and the existing `NotificationServer`: DND, arrival monitor, history, original expiry and actions remain authoritative. One foreground capsule shows app/title/body plus the pending count. Clicking expands text and action buttons. Hover pauses the foreground lifetime; queued entries retain their original deadlines. Expanded geometry stays stable when a notification arrives; the bell and notification footer open the original grouped history inside the Island. History still uses the same tracked objects, actions, DND and server. Dismissals are persisted independently of presentation locks, and deferred removal uses the notification id scope explicitly.

Releasing the final presentation lock defers removal of a closed notification until the current pending-list binding has finished evaluating. This avoids a binding loop during action invocation.

## Clipboard

Uses the existing `cliphist` database and `wl-clipboard` watchers; it does not start extra watchers. The view searches the latest 200 records, copies text or binary image data, and can delete an individual record. Up/Down selects an entry and Enter copies it. Copy completes through a shared service before the view closes. Commands use argument arrays and validated numeric IDs; clipboard content is never interpolated into a shell command.

Utilities keeps its original recording, Keep Awake, quick toggles and Settings entry. Screen recording is also available in Controls, including pause/resume and stop/save; the compact recording indicator opens Controls. The Focus tab, Island timer/Pomodoro service and `focusTimer` IPC target were removed on October 17, 2026, after moving that workflow to Look. `dynamicIsland status` no longer exposes `focusRunning` or `focusRemaining`. The taskbar, sidebar, right OSD and separate session drawer are no longer instantiated. Original component files remain available for recovery. The Island retains the existing StatusNotifier host while its Controls view is unloaded; native menus, activation and secondary activation are connected to the original tray items.

## Settings and compatibility

Settings → Panels → Dynamic Island contains Enabled, Preview on hover, Music view, a GIF file picker with preview, Animate GIF and playback speed. The existing sessionGif and sessionGifSpeed keys are reused. `dashboard.enabled`, `dashboard.showOnHover` and `dashboard.showMedia` remain the configuration keys. Old Dashboard tab/widget keys no longer affect this compact UI.

The `caelestia:dashboard` and `drawers toggle dashboard` targets remain compatible. `Super+V` now targets `caelestia:islandClipboard` in `/home/dorriss/.config/hypr/hyprland/keybinds.lua`; the Alt+Super+V deletion shortcut remains available.

```sh
qs ipc -c caelestia call dynamicIsland open workspaces
qs ipc -c caelestia call dynamicIsland open media
qs ipc -c caelestia call dynamicIsland open clipboard
qs ipc -c caelestia call dynamicIsland open info
qs ipc -c caelestia call dynamicIsland open controls
qs ipc -c caelestia call dynamicIsland open notifications
qs ipc -c caelestia call dynamicIsland open power
qs ipc -c caelestia call dynamicIsland toggle
qs ipc -c caelestia call dynamicIsland close
qs ipc -c caelestia call dynamicIsland status
```

Legacy `open dashboard/system/weather` calls resolve to Workspaces. Explicit opening respects the enabled setting and can show the Island as an overlay over fullscreen; idle and hover remain hidden there. Volume, brightness and workspace changes use a short transient capsule when the Island is resting on the focused monitor.

## Controls, power and status

Controls contains output volume, microphone mute/level, brightness for the Island's monitor, and background app tray icons. Left click activates an app (or opens menu-only items), right click opens its native menu, middle click invokes secondary activation. Platform menus require the root UseQApplication pragma; focus grab pauses while a menu is open and resumes after it closes. Mouse sliders use StyledSlider's interaction signal; keyboard and wheel changes use its native moved signal.

Power offers the configured Logout, Shutdown, Hibernate and Restart commands. Selecting an action shows Cancel/Confirm; Escape cancels selection, then closes the view. Closing clears a pending selection. The original anime GIF appears here and plays only while visible. No power command was executed during validation.

Info groups the battery status with a power-profile selector: Power saver, Balanced and Performance. It uses the existing Quickshell PowerProfiles service; the active label and selected icon follow changes from other applications. Performance is disabled if unsupported, and hardware degradation is shown when reported. Clicking the resting capsule's battery opens Info directly; other capsule clicks keep their existing actions. The added rows expand only the Info overlay and retain the 46 px desktop reservation.

Keep Awake still belongs to Utilities and uses the existing IdleInhibitor. A small purple coffee badge appears on the compact Island while enabled. Charging/plugged battery continues using the green accent.

## Validation

The power-profile follow-up has seven passing native checks in [tide-power-profile-runtime-results.json](tide-power-profile-runtime-results.json): all three mouse selections change the actual daemon profile, battery click opens Info, keyboard Tab/Space selects a profile, both outputs retain their desktop reservation, and the original Performance profile is restored. External profile changes were visually checked. QML loaded without runtime errors and `git diff --check` passed. Backup: `/tmp/caelestia-before-island-power-profile`.

The October 10 hub integration has native interaction results in [tide-hub-runtime-results.json](tide-hub-runtime-results.json): hover/focus, all seven views, retained geometry, removal of legacy taskbar/Overview, removed Super+Tab, Launcher handoff, compatibility routes, DND, native Fcitx menu focus, Utilities corner hover, settings restoration, normal/special drag round trips, laptop brightness and fullscreen overlay. Original notification action callbacks and persisted dismissal were exercised; no closed notification object remained after unloading. Volume/mute, the Utilities Keep Awake switch and purple badge, power Cancel/Escape, GIF preview and file-picker cancellation were checked directly. The pre-change panel files and tracked patch are in `/tmp/caelestia-before-island-hub`; UI captures and temporary runtime scripts are in `/tmp/island-hub-validation`.

Native QML loading, `git diff --check`, Hyprland Lua bytecode compilation and six clipboard contract tests passed. Real notification history was retained; fixture windows and notification records were removed. Audio level/mute, brightness, DND, Keep Awake, focus and the settings file were restored after checks. Both current outputs use scale 1. Other tray apps and fractional scaling were not exercised. No numerical CPU/RAM savings claim is made.

Earlier iterations below are historical validation records:


The spacing/Disk refinement reduces the idle capsule to 32 px high with 2 px margins and the total top reservation to 46 px. Disk uses `Storage.primaryDisk`, with percentage and used/total capacity. The pane remains 368 px high. Six current runtime checks in [tide-spacing-disk-runtime-results.json](tide-spacing-disk-runtime-results.json) verify both outputs, all four panes and idle geometry. The Disk display was visually checked. Backup: `/tmp/caelestia-before-island-spacing-disk`.

The initial Info/top-spacing follow-up had 16 passing native checks in [tide-info-runtime-results.json](tide-info-runtime-results.json): both monitors reserve 72 px, existing tiled windows move down 62 px, all four panes and hover keep client geometry stable, native Music → Info navigation and calendar browsing work, Escape closes Info, and fullscreen/disabled states release and restore the extra reservation. The settings file was restored byte for byte after validation. Backup: `/tmp/caelestia-before-island-info`.

- Native QML compilation, QML lint, `git diff --check` and Hyprland Lua bytecode compilation passed.
- Live interaction results are in [tide-runtime-results.json](tide-runtime-results.json). They cover hover, workspace activation, thumbnail dragging, media buttons, compact/expanded notifications, original server action invocation, hover lifetime, queues, DND, two-monitor destination, Escape/click-away, compatibility targets, clipboard search/Enter, text and PNG round trips, shortcuts, volume feedback and fullscreen.
- Clipboard has six contract tests, including an actual private cliphist database and rejection of invalid IDs. An inverted ID-validation condition is caught by the tests.
- Validation fixture windows/players and their history records are removed afterward. The original clipboard, DND, output volume and active workspace are restored.
- Final screenshots of the relevant capsules are under `/tmp/tide-*-capsule.png`. Native snapshots were visually checked on HDMI-A-1 and eDP-1, both at scale 1.

Physical unplug/replug and fractional scaling were not exercised. The green plugged/full state was inspected on the real battery; an actual discharge-to-charging hardware transition was not induced. No claim about CPU/RAM savings is made.

## Reference and recovery

Reference: [Tide-island](https://github.com/enhaoswen/Tide-island), reviewed at `e44fe2a5b7e09e0aacec98e18128ade662102f6f`. [DynamicIslandWindow](https://github.com/enhaoswen/Tide-island/blob/e44fe2a5b7e09e0aacec98e18128ade662102f6f/DynamicIslandWindow.qml) and [NotificationLayer](https://github.com/enhaoswen/Tide-island/blob/e44fe2a5b7e09e0aacec98e18128ade662102f6f/qml/island/NotificationLayer.qml) inform the interaction structure. The implementation uses native Caelestia components/services and adds no independent web runtime or Tide installation.

The pre-integration modified files, Hyprland bindings and tracked diff are in `/tmp/caelestia-before-tide-integration`. This snapshot preserves the earlier Island implementation and the user's existing changes. Start the shell with `qs -c caelestia -n -d`; inspect logs with `qs log -c caelestia -t 100 --no-color`.
