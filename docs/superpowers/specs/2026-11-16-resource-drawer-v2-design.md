# Resource Drawer v2 — Design

Date: 2026-11-16 · Builds on `2026-11-16-left-resource-drawer-design.md` (v1, merged) · Status: **awaiting approval, nothing built**

## 1. Intent and why

v1 shows memory, processes and agent sessions in a left-edge drawer. The owner wants the drawer to
become their one place to *manage* the machine, and asked for six additions: (1) stop orphaned
agent processes, (2) a warning before the machine gets slow, (3) look inside a process group,
(4) a short history, (5) the dev ports/PRs card that already exists in the island, (6) GPU, disk
and network. The owner delegated layout, UI and UX, and wants macOS look: icons and colours.

## 2. Goals / non-goals / anti-goals

Goals
- Everything in one drawer without it feeling crowded; the first thing seen is still "is my
  machine OK, and what is the one thing to do about it".
- Stop an orphaned Claude process, or any of the user's own processes, safely (confirmed, verified).
- Warn once, calmly, when memory or swap is under pressure; never nag.
- Reuse what exists: `DevData` (PRs, ports, Docker), `NetworkUsage` (speed + history),
  `proc_top.py`, `ResourceLogic.js`.

Non-goals
- Replacing htop/Activity Monitor; per-process GPU or disk attribution (not available on this
  machine without root); changing the island's own dev view (it stays as is).

Anti-goals
- A drawer that needs scrolling to find the main number; many tiny icons with no meaning.
- Any way to stop a process by accident, a system process, or someone else's process.
- Process spawns or visible CPU use while the drawer is closed.
- Alerts that repeat every few seconds.

## 3. Constraints

- Quickshell QML, same drawer shell, trigger and animation as v1 (unchanged).
- Helpers are Python (`python3 -I`), logic in `*Logic.js`, every new function has a test.
- This machine: Intel integrated GPU (i915, no utilisation counter without root), NVMe disk,
  two monitors. Fonts installed: Inter, Geist, Maple Mono; icons: Material Symbols (MaterialIcon).
- No Apple assets: SF Symbols and SF Pro cannot be shipped.

## 4. Approaches considered (layout)

| | How | Verdict |
|---|---|---|
| A. Tabs, Activity-Monitor style | Segmented control on top, one focused page per tab | **Chosen** |
| B. One long scrolling page with collapsible sections | Everything stacked | Rejected: the key number scrolls away; six features would make a long page |
| C. Wider two-column panel | Side-by-side | Rejected: the drawer sits on a 1920 px screen beside the work; width is precious |

## 5. Decided design

### Information architecture (five tabs)

| Tab | Icon tile (colour) | Content |
|---|---|---|
| **Overview** | gauge (blue) | Three cards, each a value + sparkline over the last ~10 min: Memory, CPU (+temperature), Swap. A compact network ↓↑ line. A banner when something needs attention, linking to the tab that fixes it. Alert switch. |
| **Processes** | list (orange) | Groups by app, sort RAM/CPU. Tap a group to expand its top 5 processes (name, PID, RAM, CPU). A process row has **Stop**. |
| **Agents** | sparkle (purple) | Claude and Codex rows as in v1. Orphan rows get **Stop**; header action **Stop N orphans**. |
| **Dev** | terminal (green) | Listening ports (with Stop), Docker containers (with Stop), open pull requests with CI state. Reuses `DevData`. |
| **System** | cpu (teal) | GPU clock (current/max MHz), disk usage and read/write throughput, network speeds with history. |

Sketch
```
┌────────────────────────────────┐
│ [Overview][Procs][Agents][Dev][Sys]│   <- segmented control, icon + label of the active one
│ ┌ Memory ─────────  8.5/14.5 GB┐ │
│ │ ▁▂▂▃▃▄▄▄▅▅▅▅  green          │ │
│ └──────────────────────────────┘ │
│ ┌ CPU ────────────  9% · 73°C ─┐ │
│ ┌ Swap ───────────  4.6 GB ────┐ │
│ ⚠ Memory is high — 3 idle agent  │
│   sessions use 0.6 GB      [View]│
└────────────────────────────────┘
```

### Look (macOS)
- Dark macOS palette. System colours: blue `#0A84FF`, green `#30D158`, orange `#FF9F0A`, red
  `#FF453A`, purple `#BF5AF2`, teal `#64D2FF`. Labels: primary `#FFFFFF`, secondary
  `#EBEBF5` at 60%, tertiary at 30%. Panel `#0A0A0A` (v1) with grouped cards `#1C1C1E`,
  separators `#38383A`; radii 12 (panel) / 10 (cards) / 6 (controls). *[my call]*
- Font: **Inter** (closest installed face to SF Pro) with tabular numbers everywhere,
  replacing Geist/Maple Mono in this panel. *[my call]*
- Icons: Material Symbols Rounded inside 22 px rounded-square "app icon" tiles with a system
  colour fill and a white glyph, the way macOS System Settings draws its sidebar. This keeps the
  Mac look without Apple assets. *[my call]*
- Controls: segmented control with a sliding highlight; destructive actions in red, always
  two-step.
- Panel widens from 360 to **400 px** to fit the tab bar and the port rows. *[my call]*

### Behaviour
- **Stop (1, 3):** first click turns the button into "Stop?" for 3 s; second click sends SIGTERM.
  A new helper `proc_action.py stop <pid> <start_ticks>` re-reads `/proc/<pid>` and refuses unless
  the process is the user's own, its start time still matches (pid reuse), and its name is not on a
  protected list (Hyprland, quickshell/qs, systemd, pipewire, wireplumber, dbus, the display server,
  and the current shell session's own processes). Result is shown as a one-line status.
- **Alerts (2):** `notify-send` (same pattern as `IslandHealth`). Fire when RAM used >= 85% or swap
  >= 50% for 3 consecutive 30 s samples; at most once per 30 min per kind; one switch on Overview
  (default on), persisted like the island's settings. The notification names the biggest group.
- **History (4):** a ring buffer of RAM/swap/CPU percentages, sampled every 5 s from `/proc/meminfo`
  and `/proc/stat` through QML file reads (no process spawn), ~10 min kept, so the sparklines are
  filled when the drawer opens. This relaxes v1's "no work while closed" to "no spawned process and
  no visible CPU while closed". *[my call]*
- **Dev (5):** the same data, laid out compactly: ports (`:3000 · node · project`, local/open badge),
  Docker, PRs with CI dots. Ports poll only while the Dev tab is visible (`portViewers`), as in the island.
- **System (6):** GPU shows `gt_cur_freq_mhz` against `gt_max_freq_mhz` and is labelled **clock**,
  not utilisation (the i915 driver exposes no busy counter without root). Disk: `statvfs` for
  usage plus `/proc/diskstats` deltas for throughput. Network: `NetworkUsage` speeds and history.
- Tabs poll only what they show; the Processes/Agents data still comes from `proc_top.py`, now also
  returning the top 5 processes per group.

## 6. Phasing (one plan, six increments)

1. Foundation: Mac theme + Inter, icon tiles, segmented tabs, Overview with history + sparklines (4).
2. Processes drill-down and Stop, with `proc_action.py` (3).
3. Agents: Stop orphans (1).
4. Alerts (2).
5. Dev tab (5).
6. System tab (6).

## 7. Risks

- Stopping processes is the one dangerous feature; the safeguards in §5 and their tests are the point of phase 2.
- The Dev tab couples to `DevData`'s polling and notification side effects (`pullEvent`, `party`); only read its data.
- Inter weights/tabular figures in QML (`font.features`) need a check on this machine.
- 400 px width may collide with very narrow windows beside the drawer; it overlays, as in v1.
- The always-on 5 s sampling is the only closed-state cost; measure it, and drop to 10 s if it shows.

## 8. Left to the builder

Sparkline drawing (Canvas vs Shape), exact paddings, animation of tab changes (a short cross-fade),
the persisted-settings file, wording of banners and status lines, and the tests.
