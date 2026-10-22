# Island activity hub — 14 October 2026

Authorized scope: recording indicator/Pause/Stop, capsule mic toggle, low-battery/CPU-temperature warnings, Wi-Fi/Bluetooth/VPN controls plus timer/Pomodoro; redesign to reduce density; restore only Island typography; audit disk without deletion.

Design contract: keep existing dark surface/Material palette and OutQuint morph. Idle capsule: clock, short secondary text, battery and mic; a single priority activity slot (health alert > recording > focus timer > media). Keep at most five primary destinations: Spaces, Music, Focus, Connections, Controls. Clipboard stays reachable by right-click/Super+V, notifications and Info stay reachable through header utilities/Controls. Power remains under Controls. Give expanded panes consistent 680 px preferred width, readable labels and 20–24 px gutters; workspace overview keeps its existing geometry. Restore Google Sans Flex locally through IslandText, preserve Caskaydia elsewhere and Material icons. Preserve existing notification/workspace/clipboard semantics.

Modules/build order: activity-logic (timer transitions/alert hysteresis) -> activity-services (timer, health, recorder fixes) -> island-ui (capsule/navigation/focus/connections) -> native validation. Disk audit is independent, read-only.

Tests: node --test modules/dashboard/helpers/test_activity.cjs; python3 -m unittest discover -s modules/dashboard/helpers -p 'test_*.py'; native QML load, seven legacy + two new panes, keyboard/mouse mic and timer, screen recording Pause/Resume/Stop, alert threshold simulations, screenshots on both displays, resource sample. Validate timer against wall-clock deadlines (sleep/delays), pause freezes remaining, completion once, Pomodoro phase advances explicitly. Alert thresholds: battery 20%/10% only discharging, temperature >=90 C for sustained samples, hysteresis clear below85 C; unknown readings never alert. Do not trigger hibernation/power actions in tests.

Guardrails: no new dependency; no destructive disk cleanup; backup dirty working tree before edits; no commit of unrelated existing changes. Native shell has no conventional build script; qs compilation and targeted tests are the verification commands. Commands: qs -c caelestia -n -d; qs ipc -c caelestia call dynamicIsland open focus; qs ipc -c caelestia call dynamicIsland open connections; git diff --check.

Delivered. See /home/dorriss/Backups/island-hub-20261014/ISLAND-CHANGES.md and DISK-AUDIT.md for verified behavior, limits and measurements. Testing stopped at the user’s request.
