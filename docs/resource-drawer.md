# Resource drawer

Rest the pointer on the **left edge** of a screen (middle 70% of its height) and a drawer slides in.
Move away and it slides out. It never opens in fullscreen or while a mouse button is held.

Five tabs (macOS-style segmented control):

| Tab | What it shows |
|---|---|
| Overview | Memory, CPU (+ temperature) and Swap with ~10 minutes of history, network speed, an attention banner, and a switch for memory alerts |
| Processes | Apps grouped by RAM or CPU. Tap a group for its top 5 processes; hover a row to **Stop** your own, non-protected ones |
| Agents | Claude Code and Codex sessions. Orphans (working folder deleted) are red and can be stopped one by one or all at once |
| Dev | Listening ports, Docker containers and open pull requests (the island's `DevData`), with Stop for ports and containers |
| System | GPU clock (not utilisation), disk usage and read/write rates, network history |

Look and motion: a translucent glass panel (lit edge, soft shadow) that is exactly as tall as its content (up to 80%
of the screen) with its top fixed, so the tab bar never moves. It springs in from the left with a small overshoot,
springs to the new height when you change tab, and each page eases in. Overview is a bento: a memory ring with the
pressure level, autoscaled sparklines (so small movements show), CPU and swap side by side, network and the alerts
switch. The backdrop blur comes from one Hyprland layer rule in `~/.config/hypr/hyprland/rules.lua`:
`hl.layer_rule({ match = { namespace = "caelestia-drawers" }, blur = true, ignore_alpha = 0.55 })`.
Without it the glass is merely translucent; raise `glassAlpha` in `ResourcesTheme.qml` to ~0.8 then.

Safety: every Stop is two-step (first click arms it for 3 s) and goes through `proc_action.py`, which
re-checks that the process is still the one you saw, is yours, and is not protected (Hyprland, quickshell,
systemd, pipewire, ...). It only ever sends SIGTERM.

Alerts: one notification when memory is above 85% or swap above 50% for three 30 s samples in a row, then quiet
for 30 minutes. The switch is persisted in `~/.local/state/caelestia/resources.json`.

Cost: with the drawer closed only two tiny `/proc` files are read every 5 s (about 0.5% of one core, no
spawned process). Each tab polls only while it is on screen.

Code: `modules/resources/`, `services/Resources*.qml`, helpers in `modules/dashboard/helpers/`
(`proc_top.py`, `proc_action.py`, `sys_stats.py`, `ResourceLogic.js` and their tests). Designs:
`docs/superpowers/specs/2026-11-16-left-resource-drawer-design.md` and `...-resource-drawer-v2-design.md`.
