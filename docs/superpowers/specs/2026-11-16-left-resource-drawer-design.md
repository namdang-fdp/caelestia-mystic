# Left-edge Resource Drawer — Design

Date: 2026-11-16 · Repo: `caelestia-mystic` (`~/.config/quickshell/caelestia`) · Status: **awaiting approval, nothing built**

## 1. Intent and why

The owner wants to see "what is eating RAM/CPU" without opening htop, and to see their
AI agent sessions (Claude Code, Codex) in the same place. Today the island shows what an
agent is *doing* (`AgentState`, hook files), but a session that stops reporting is dropped
from view while its `claude` process stays in RAM (found 2026-11-16: 14 `claude` processes,
~2.7 GB, most idle for 7-11 h; 6 of them with a deleted worktree). The shell has no
per-process RAM/CPU view at all (only temperature, battery, network).

Result wanted: move the mouse to the left screen edge, a panel slides in showing system
resources, top processes grouped by app, and live agent sessions. Move away, it slides out.

## 2. Goals / non-goals / anti-goals

Goals
- Left-edge drawer, same family as the existing bottom-right `utilities` panel.
- System summary: RAM used/total, swap, CPU %, CPU temperature.
- Processes grouped by app (Zen, Claude, Electron apps, ...), sortable by RAM or CPU.
- Agents section: Claude Code sessions (project, state, age, RAM, "orphan" badge when the
  working directory is deleted) and Codex sessions (state from logs) + Codex total RAM.
- Cheap: no work while the drawer is closed.

Non-goals (v1)
- Killing/stopping processes (see Phase 2).
- Per-window GPU, disk or network views. Wayland/Hyprland-independent portability.
- Replacing htop/btop.

Anti-goals (failure even if it "works")
- The drawer opening when the pointer merely brushes the edge or travels along it.
- Polling or a timer running while closed; any visible CPU cost from the shell itself.
- Numbers that don't add up (summed RSS exceeding physical RAM).
- Low-contrast or wallpaper-tinted look; Material-You colour drift.

## 3. Constraints

- Quickshell/QML, existing patterns: `Wrapper` + `Content` per panel, `screenState` flags,
  `Anim` + `offsetScale` for slide animation, `Interactions.qml` for hover zones/timers.
- Helpers are Python run as `python3 -I <script>`; logic that can be pure lives in
  `*Logic.js`; each helper has a `test_*.py` / `test_*.cjs` beside it.
- Linux only (`/proc`). Left edge is free: the owner no longer uses the bar.
- Don't open while a window is fullscreen (same rule `utilities` follows).
- `Caelestia.Config` comes from a compiled plugin (`libcaelestia-coreplugin.so`): adding a
  new `Config.*` key may not be possible from QML alone.

## 4. Approaches considered

| | Trigger | Panel | Verdict |
|---|---|---|---|
| A. Left-edge drawer | thin strip at x=0, middle band of the height, short enter delay | tall, ~360 px wide, slides from left | **Chosen** (owner's pick) |
| B. Bottom-left corner mirror of `utilities` | small corner zone | grows upward from the corner | Fallback if A mis-triggers in daily use |
| C. Claude mod only | none | inside the chat | Rejected: Claude-only, not in the shell, can't touch the sidebar |

Build order decided: a standalone helper first (usable from a terminal), then the drawer on top.

## 5. Decided behaviour

Trigger and motion (owner's words: slide gently from the left, only when the pointer
reaches the left limit, never randomly, drawer-like)
- Trigger strip: pointer at the leftmost 2-4 px, within a vertical band (default 15%-85% of
  screen height). *[my call: band and sizes]*
- Enter delay ~120 ms, leave delay ~250 ms after the pointer leaves strip+panel, same timer
  pattern as `utilitiesEnterTimer/LeaveTimer`. *[my call: values]*
- Stays open while the pointer is over the panel. Does not open during fullscreen.
- Animation: translate from `-width` to 0 plus opacity, `Behavior on offsetScale { Anim {} }`
  exactly like `utilities/Wrapper.qml`, mirrored to the left anchor. Short ease-out
  (~250 ms). No bounce, no overshoot.

Look (owner's words: high contrast, macOS / Vercel style)
- Dark only. Near-black surface, 1 px hairline border, white primary text, grey secondary,
  generous spacing, 12 px radii. Fixed palette in one theme object, **not** derived from the
  wallpaper. *[my call: fixed palette]*
- Fonts: Geist for UI (already configured), Maple Mono for numbers (tabular alignment).
- Status colours only for meaning: green normal, amber warm (RAM >70% / CPU >70%), red hot
  (RAM >85% / swap pressure). *[my call: thresholds]*
- Icons: thin line icons. Use the already-loaded Material Symbols at light weight; swap to an
  SVG set later if it looks off. *[my call]*

Layout sketch
```
┌ Resources ────────────────┐
│ RAM 8.9 / 14 GB  ▓▓▓▓▓▓░░ │
│ Swap 5.7 GB   CPU 23%  62°C│
│ ── Processes   [RAM|CPU] ──│
│ Zen           3.4 GB  22p │
│ Claude        1.5 GB   6p │
│ Electron      0.8 GB  10p │
│ ── Agents ─────────────── │
│ ● liftping      idle 5h   │
│ ○ KAN-357       idle 8h   │
│ ✕ KAN-360  orphan 11h     │
│ Codex  working · 121 MB   │
└───────────────────────────┘
```

Data
- `proc_top.py` (new, `modules/dashboard/helpers/`): reads `/proc`, returns JSON: system
  totals, groups (name, RAM, CPU, process count), and for `claude` processes: pid, cwd,
  age, RSS, `orphan` (cwd link ends with ` (deleted)`). CPU% from two samples a short
  interval apart. Prefer PSS (`smaps_rollup`) so shared pages aren't double counted; fall
  back to RSS where unreadable. Runnable from a terminal with a table output flag.
- `ResourceLogic.js` (new): grouping/sorting/thresholds, pure and unit-tested.
- `services/Resources.qml` (new singleton): refreshes every ~2 s **only while the drawer is
  visible**, same `viewers` idea as `AgentState`.
- Join with `AgentState.sessions` on pid, else on cwd, to label Claude rows with state.
  Codex rows come from `AgentState` (log-derived, `pid: 0`); Codex RAM is one aggregate row
  from the process groups (it runs as one daemon, per-session RAM is not knowable).

Phase 2 (not in v1 unless the owner says so)
- A "Stop" action on orphan agent processes and on a chosen group, with inline confirm.
- Optional `notify-send` when RAM/swap crosses a threshold (like `IslandHealth` does for heat).

## 6. Files expected to change

New: `modules/resources/{Wrapper,Content,...}.qml`, `services/Resources.qml`,
`modules/dashboard/helpers/{proc_top.py,ResourceLogic.js,test_proc_top.py,test_resources.cjs}`.
Edited: `modules/drawers/Panels.qml` (add left-anchored panel), `Interactions.qml` (strip
zone + timers), `ContentWindow.qml` (background/deform wiring, as `utilsBg` does),
`components/ScreenState.qml` (new `resources` flag).

## 7. Risks

- `ContentWindow.qml` draws a blob/SDF background per panel; a new panel needs the same
  treatment and may interact with the border shape. Biggest unknown.
- Bar hover: the bar only disables via `bar.excludedScreens`, which `shell.json` doesn't
  set. Verify the bar no longer appears at the left edge, else it will fight the drawer.
- Other things living at the left edge (Hyprland edge bindings, window scrollbars) may
  trigger it; mitigated by the middle band and delay.
- Multi-monitor: the flag is per `screenState`; confirm only the pointer's monitor opens.

## 8. Left to the builder

Exact pixel sizes, easing curve, how to wire the new flag if a `Config` key can't be added,
PSS vs RSS cost on this machine, row interaction details, and the test cases.
