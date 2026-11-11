# Island phase 1 — 7 November 2026

Implemented the first batch selected after comparing NotchIsland's feature catalogue with the current working tree.

## Behavior

- Microphone mute is a compact badge plus the existing brief mute/unmute feedback. It no longer replaces music, stats or the idle companion. The title leaves room for concurrent timer and microphone badges.
- Compact activity selection lives in `helpers/ActivityLogic.js`. Hover and click use the same decision: health/stats → Info, recording → recording controls, timer → Timer, media → Media. A file drop still opens Shelf; disabling Media retains the timer/shelf/glance fallback.
- Recording preview offers pause/resume and stop/save through the existing Recorder service. A running recording also has a Controls entry. Utilities retains the full recorder interface.
- Carousel dots are 28×28 buttons with tooltips, focus indication and keyboard activation. The current page name opens a direct page menu.
- Controls opens an audio picker from either the output name or the microphone row. Output/Input tabs open at the requested section. Short device nicknames distinguish HDMI ports and built-in microphones; tooltips retain full descriptions.
- Device checkmarks follow actual PipeWire defaults. Switching has a pending state and timeout error. Delegates tolerate destroyed nodes during list changes. No new polling or dependency was added.
- Settings descriptions and README match the current interactions. IPC accepts `dynamicIsland open audio` and `dynamicIsland open recording`.

## Verification

- Activity JavaScript: 21 passing tests, including four new priority/routing cases (failed before implementation).
- Existing audio JavaScript: 7 passing tests.
- Existing Python helpers: 15 passing tests.
- Nine native QML checks passed: Controls selectors, page menu, pointer/keyboard dots, keyboard entry to Audio, real PipeWire output switching, real input switching, recording preview routing, persistent microphone badge, and concurrent music/timer/microphone layout.
- Audio checks used temporary PulseAudio/PipeWire null output and remapped input. A tone was sent only to that null output. Original default output and input were restored; virtual devices and playback were removed.
- Native laptop layer-panel checks passed for Controls and the Input tab on `eDP-1`; screenshots inspected. Native menu, Controls, Input, recording preview and compact screenshots were also inspected.
- The final shell loaded successfully. Controls, Audio, Media, Timer, Shelf, Clipboard and More opened through IPC on HDMI-A-1. Both outputs retain their 36px top reservation.
- `git diff --check` passed. Final native checks had no TypeError, ReferenceError or binding-loop messages. Existing missing application/tray icon warnings remain.
- Standalone qmllint could not resolve the runtime-generated `qs.*` import namespace; actual Quickshell compilation and rendering were used for QML validation.

Recording state was simulated in the isolated QML instance: no screen capture was started or stopped. Fractional scaling and physical unplug/replug were not exercised. A compositor focus dispatch changed native monitor focus without updating the shell's cached active-monitor value during the two-monitor IPC script; laptop rendering was therefore checked with an explicitly targeted native layer panel instead. No active-monitor behavior was changed in this batch.

## Recovery and evidence

Pre-edit files and the initial working-tree patch are under `/home/dorriss/Backups/island-phase1-20261107/before/`. Native test harnesses, logs, screenshots and live page results are under its `evidence/` directory.

To undo this batch, restore these existing files from `before/`: README.md, modules/Shortcuts.qml, modules/dashboard/IslandCompact.qml, modules/dashboard/IslandControlsView.qml, modules/dashboard/Wrapper.qml, modules/dashboard/helpers/ActivityLogic.js, modules/dashboard/helpers/test_activity.cjs, and modules/nexus/pages/panels/DashboardPanel.qml. Remove the three newly added QML components IslandAudioView.qml, IslandNavigation.qml and IslandRecordingView.qml, then restart the shell.

The user's pre-existing audio/media, drawer, utility and task-note changes were retained. No git commit was created.
