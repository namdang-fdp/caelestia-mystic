# Resource drawer

Rest the pointer on the **left edge** of a screen (middle 70% of its height) and a drawer slides in:
memory/swap/CPU, processes grouped by app (sort by RAM or CPU), and your Claude Code and Codex sessions.
Move away and it slides out. It never opens in fullscreen or while a mouse button is held.

- Data: `modules/dashboard/helpers/proc_top.py` (also runnable alone: `python3 -I proc_top.py --table`).
- Logic and tests: `ResourceLogic.js`, `test_resources.cjs`, `test_proc_top.py`.
- Polling runs only while the drawer is open (`services/Resources.qml`).
- Orphan agents (red) are Claude processes whose working directory was deleted: safe to close from the app.
- Design: `docs/superpowers/specs/2026-11-16-left-resource-drawer-design.md`.
