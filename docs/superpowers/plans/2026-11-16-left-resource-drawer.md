# Left-edge Resource Drawer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A drawer that slides in from the left screen edge, showing system RAM/swap/CPU, processes grouped by app, and live Claude/Codex sessions.

**Architecture:** A stateless Python helper (`proc_top.py`) reads `/proc` and prints JSON. Pure QML-agnostic logic lives in `ResourceLogic.js` (unit-tested with `node --test`). A `Resources` singleton polls the helper every 2 s only while the drawer is visible. The drawer is a new `Wrapper` in `Panels.qml` with its **own** fixed-palette background (no `PanelBg` blob), opened by a new left-strip zone in `Interactions.qml`.

**Tech Stack:** Quickshell QML, Python 3 stdlib (`unittest`), plain JS (`.pragma library`, tested via `node:test` + `vm`).

**Spec:** `docs/superpowers/specs/2026-11-16-left-resource-drawer-design.md`
(Deviation from spec §6: `ContentWindow.qml` is **not** edited. The panel draws its own near-black rounded rect instead of joining the blob group, because the blob uses the wallpaper-derived `surfaceColour`, which the spec forbids for this panel.)

## Global Constraints

- All work on branch `feat/resource-drawer` of this repo; helpers go in `modules/dashboard/helpers/`, run as `python3 -I <script>`.
- Linux `/proc` only. Python tests: `python3 -m unittest <file>`; JS tests: `node --test <file>`.
- Closed drawer = no timers/Process running. Open = refresh every 2000 ms.
- Trigger: pointer in the leftmost **4 px**, y within **15%–85%** of screen height; enter delay **120 ms**, leave delay **250 ms**. Never opens during fullscreen or while a mouse button is pressed.
- Slide: `Behavior on offsetScale { Anim {} }` as in `modules/utilities/Wrapper.qml`; drawer width **360**, floating card with **12 px** margin and **12 px** radius, 1 px hairline border.
- Palette fixed in `services/ResourcesTheme.qml` (exact values in Task 4, surface `#0A0A0A`), never wallpaper-derived. Fonts: `Geist` UI, `Maple Mono NF` numbers.
- Severity: RAM warm ≥ 0.70, hot ≥ 0.85; CPU warm ≥ 0.70, hot ≥ 0.90; swap hot when used/total ≥ 0.5 (total 0 → ok).
- Process groups by **exe basename**; display map `zen-bin→Zen`, `claude→Claude`, `claude-desktop→Claude Desktop`, `electron*→Electron`, any name starting `codex→Codex`, else the basename.

## Review Focus

- A pid disappears between `listdir` and reading its files → skipped, no crash (Task 1 test).
- `comm` containing spaces or `)` in `/proc/<pid>/stat` (e.g. `(Isolated Web Co)`, `(a) b)`) parses correctly (Task 1 test).
- Unreadable `exe`/`cwd`/`smaps_rollup` (other users' processes) → group by `comm`, RSS fallback, `orphan: false` (Task 1 test).
- Swap total 0 or `MemTotal` missing → no divide-by-zero, severity `ok` (Task 2 test).
- Two Claude processes in one cwd: join prefers pid; the unmatched one shows `idle`, never borrows another's state (Task 2 test).
- Pointer dragging along the edge with a button held must not open the drawer (Task 2 test + Task 4 check).

---

### Task 1: `proc_top.py` helper

**Files:**
- Create: `modules/dashboard/helpers/proc_top.py`
- Test: `modules/dashboard/helpers/test_proc_top.py`

**Interfaces:**
- Produces (`proc_top`), all taking `proc: Path` (root of a /proc-like tree, default `/proc`):
  - `read_meminfo(proc) -> dict` keys `total_kb, available_kb, swap_total_kb, swap_used_kb` (ints, 0 if missing).
  - `read_processes(proc) -> list[dict]` keys `pid:int, name:str (comm), exe:str, rss_kb:int, pss_kb:int, ticks:int (utime+stime), age_s:float, cwd:str, orphan:bool`.
  - `group_name(exe: str, comm: str) -> str` per the Global Constraints map.
  - `cpu_percent(before: dict[int,int], after: dict[int,int], dt_s: float, clk_tck: int) -> dict[int,float]` (pids in both; per-core %, 100 = one core).
  - `collect(proc: Path = Path("/proc"), interval: float = 0.3, sleep=time.sleep) -> dict`:
    `{"system":{"total_kb","used_kb","swap_total_kb","swap_used_kb","cpu_percent"}, "groups":[{"name","ram_kb","cpu_percent","count"}], "claude":[{"pid","cwd","project","age_s","ram_kb","orphan"}]}`; `used_kb = total − available`; group `ram_kb` sums `pss_kb or rss_kb`.
  - CLI: `python3 -I proc_top.py` prints that JSON; `--table` prints a human table; `--interval N`.

- [ ] **Step 1: Write failing tests** in `test_proc_top.py` using a temp fake `/proc` (follow `test_agent_sessions.py` style): `test_meminfo_parses_kb_and_swap`, `test_process_fields_from_fake_tree` (stat, `smaps_rollup` Pss, `exe` and `cwd` symlinks), `test_orphan_when_cwd_target_ends_with_deleted` (symlink target `"/x/y (deleted)"` → `orphan is True`), `test_stat_comm_with_spaces_and_parens` (comm `(a) b` → ticks still correct), `test_vanished_pid_is_skipped` (pid dir with no `stat`), `test_unreadable_exe_falls_back_to_comm_and_rss` (no `exe`, no `smaps_rollup` → `exe==""`, `pss_kb==0`; group by comm), `test_group_name_map` (the Global-Constraints table), `test_cpu_percent` (200 ticks over 1 s at `clk_tck=100` → `200.0`), `test_collect_groups_sum_pss_and_lists_claude` (two `claude` procs, one orphan; `sleep` injected as a no-op).
- [ ] **Step 2: Run** `python3 -m unittest modules/dashboard/helpers/test_proc_top.py -v` → Expected: FAIL (`ModuleNotFoundError: proc_top`).
- [ ] **Step 3: Implement** the functions above in `proc_top.py`. Parse `stat` by splitting after the **last** `)`; `age_s` from `starttime` and `/proc/uptime`; cwd via `os.readlink` (a trailing `" (deleted)"` sets `orphan`, and is stripped from `cwd`); wrap each per-pid read in `try/except (OSError, ValueError)` and skip the pid only if `stat` fails. System `cpu_percent` from two `/proc/stat` reads across `interval`.
- [ ] **Step 4: Run** the same command → Expected: all PASS. Then `python3 -I modules/dashboard/helpers/proc_top.py --table | head -8` on the real machine → Expected: a RAM/swap line and groups led by Zen/Claude, with RAM totals ≤ physical RAM.
- [ ] **Step 5: Commit** `feat(resources): add /proc helper for per-app RAM/CPU and Claude processes`.

### Task 2: `ResourceLogic.js`

**Files:**
- Create: `modules/dashboard/helpers/ResourceLogic.js` (starts with `.pragma library`)
- Test: `modules/dashboard/helpers/test_resources.cjs` (same `vm` loader as `test_live.cjs`)

**Interfaces:**
- Consumes: JSON shape from Task 1; `AgentState.sessions` items `{agent, session, project, cwd, pid, state, updated}`.
- Produces:
  - `severity(kind: "ram"|"cpu"|"swap", fraction: number) -> "ok"|"warm"|"hot"` (thresholds in Global Constraints; non-finite → `"ok"`).
  - `fraction(used: number, total: number) -> number` (0 when `total <= 0`).
  - `sortGroups(groups, key: "ram"|"cpu") -> array` (new array, descending, ties by name).
  - `formatKb(kb) -> string` (`"512 MB"`, `"3.4 GB"`), `formatAge(seconds) -> string` (`"12m"`, `"5h"`, `"3d"`).
  - `agentRows(claude, sessions, groups) -> array` of `{kind:"claude"|"codex", label, state, age_s, ram_kb, orphan}`: Claude rows join a process to a session by `pid`, else by identical `cwd` only when exactly one process has that cwd; unmatched → `state:"idle"`. Codex rows come from sessions with `agent==="codex"` (state as given, `age_s` from `updated`), plus one row `label:"Codex"` carrying the `Codex` group's `ram_kb`.
  - `triggerActive(p: {x, y, width, height, strip, bandStart, bandEnd, pressed, fullscreen}) -> bool` (true only when `x <= strip`, `bandStart*height <= y <= bandEnd*height`, not pressed, not fullscreen).
  - `inPanel(x, y, panelLeft, panelWidth, panelTop, panelHeight, slack) -> bool`.

- [ ] **Step 1: Write failing tests** (`node:test`): `severity thresholds at 0.70/0.85/0.90 and swap 0.5`, `swap total 0 is ok and fraction(5,0) is 0`, `sortGroups by ram then cpu is stable`, `formatKb and formatAge boundaries (1023 kB, 1 GB, 59 s, 3600 s)`, `agentRows joins by pid`, `agentRows two processes sharing a cwd do not borrow state (unmatched is idle)`, `agentRows adds Codex aggregate row`, `orphan flag passes through`, `triggerActive false when pressed, fullscreen, outside band, or x > strip`, `inPanel respects slack`.
- [ ] **Step 2: Run** `node --test modules/dashboard/helpers/test_resources.cjs` → Expected: FAIL (cannot read `ResourceLogic.js`).
- [ ] **Step 3: Implement** the functions in `ResourceLogic.js` per the signatures above.
- [ ] **Step 4: Run** the same command → Expected: all PASS.
- [ ] **Step 5: Commit** `feat(resources): add pure resource/agent row logic with tests`.

### Task 3: `Resources` service

**Files:**
- Create: `services/Resources.qml`

**Interfaces:**
- Consumes: `proc_top.py` JSON (Task 1).
- Produces (singleton `Resources`): `property int viewers`, `property var system`, `property var groups`, `property var claude`, `property bool ready`, `function refresh(): void`.

- [ ] **Step 1: Implement** the singleton modelled on `AgentState.qml`: `Process { command: ["python3","-I", Quickshell.shellPath("modules/dashboard/helpers/proc_top.py")] }` with a `StdioCollector` that parses JSON in `try/catch` and sets the properties; a `Timer { interval: 2000; repeat: true; triggeredOnStart: true; running: root.viewers > 0 }` that skips when the process is still running.
- [ ] **Step 2: Verify load**: with the shell running, `qs log -c caelestia | tail -30` → Expected: no `ERROR`/`WARN` naming `Resources.qml`.
- [ ] **Step 3: Commit** `feat(resources): add polling service gated on viewers`.

### Task 4: Drawer shell, trigger and slide animation

**Files:**
- Create: `services/ResourcesTheme.qml`, `modules/resources/Wrapper.qml`, `modules/resources/Content.qml` (placeholder text for now)
- Modify: `components/ScreenState.qml` (add `property bool resources`), `modules/drawers/Panels.qml` (add `readonly property alias resources: resources` and the left-anchored `Resources.Wrapper`), `modules/drawers/Interactions.qml` (strip zone + timers), `modules/drawers/Regions.qml` (input regions)

**Interfaces:**
- Consumes: `ResourceLogic.triggerActive`, `ResourceLogic.inPanel`.
- Produces: `ResourcesTheme` singleton (properties `surface "#0A0A0A"`, `border "#262626"`, `text "#FFFFFF"`, `textDim "#A1A1A1"`, `ok "#3DD68C"`, `warm "#F5A623"`, `hot "#FF4D4F"`, `radius 12`, `uiFont "Geist"`, `numFont "Maple Mono NF"`); `Wrapper` with `activationWidth: 4`, `offsetScale`, `visible`, `implicitWidth: 360 + 12`, `shouldBeActive: screenState.resources`; `Wrapper` loads `Content` only while `shouldBeActive || visible`.

- [ ] **Step 1: Implement** `Wrapper.qml` by mirroring `modules/utilities/Wrapper.qml` to the left: `anchors.left: parent.left`, `anchors.verticalCenter`, `anchors.leftMargin: (-implicitWidth - 5) * offsetScale`, `opacity: 1 - offsetScale`, `Behavior on offsetScale { Anim {} }`, a `Rectangle` background (`ResourcesTheme.surface`, 1 px `border`, `radius`) with 12 px outer margin and height ≈ 80% of the screen; `Content` is a `Loader` item like utilities.
- [ ] **Step 2: Wire it**: `Panels.qml` instance anchored left; `Regions.qml` adds `R { panel: root.panels.resources; enabled: !root.win.hasFullscreen }` plus a strip `Region` (`x:0`, `y: 0.15*height`, `width: activationWidth`, `height: 0.7*height`, width 0 when fullscreen); `Interactions.qml` adds `updateResourcesHover()` called from `onEntered` and `onPositionChanged`, a `resourcesEnterTimer` (120 ms) and `resourcesLeaveTimer` (250 ms) following the `utilities` timers, using `ResourceLogic.triggerActive({..., pressed: root.pressed})` for the strip and `inPanel(...)` while visible; on `onContainsMouseChanged` stop the enter timer and restart the leave timer.
- [ ] **Step 3: Verify behaviour** (Hyprland): `hyprctl dispatch movecursor 600 540` then `grim /tmp/r0.png` → drawer absent; `hyprctl dispatch movecursor 1 540`, wait 0.5 s, `grim /tmp/r1.png` → drawer visible; move to `600 540`, wait 0.6 s → hidden again; `movecursor 1 20` (outside band) → stays closed. Expected as stated; the slide must be visibly animated (check by eye). Also hold a button while moving to the edge → must not open.
- [ ] **Step 4: Verify the bar does not fight it**: moving to x=1 shows no bar; if it does, set `bar.excludedScreens` in `~/.config/caelestia/shell.json` to the monitor name and re-check.
- [ ] **Step 5: Commit** `feat(resources): add left-edge drawer shell with hover trigger and slide`.

### Task 5: Summary header

**Files:**
- Create: `modules/resources/Summary.qml`
- Modify: `modules/resources/Content.qml` (replace placeholder; add `Component.onCompleted: Resources.viewers++` and `Component.onDestruction: Resources.viewers--`)

**Interfaces:**
- Consumes: `Resources.system`, `IslandHealth.temperature` (−1 means unknown, hide it), `ResourceLogic.fraction/severity/formatKb`, `ResourcesTheme`.
- Produces: `Summary` item showing RAM `used / total` with a thin bar coloured by severity, swap line (coloured by `severity("swap", …)`), CPU % and temperature.

- [ ] **Step 1: Implement** `Summary.qml` per the layout sketch in the spec §5; numbers in `numFont`.
- [ ] **Step 2: Verify**: open the drawer; values match `free -h` within a few percent; `grim` screenshot shows high-contrast text on `#0A0A0A`. Closing the drawer stops polling: `pgrep -f proc_top.py` returns nothing 3 s after closing.
- [ ] **Step 3: Commit** `feat(resources): add RAM/swap/CPU summary`.

### Task 6: Process groups list

**Files:**
- Create: `modules/resources/GroupList.qml`, `modules/resources/SortToggle.qml`
- Modify: `modules/resources/Content.qml`

**Interfaces:**
- Consumes: `Resources.groups`, `ResourceLogic.sortGroups`.
- Produces: `GroupList` (rows: name, RAM, CPU %, process count `22p`), `SortToggle` with `property string key: "ram"` and `signal changed(string key)`.

- [ ] **Step 1: Implement** the list (top 8 groups) and the `RAM | CPU` toggle; selected key persists only while the drawer exists.
- [ ] **Step 2: Verify**: top rows equal `python3 -I …/proc_top.py --table`; toggling to CPU reorders; screenshot check.
- [ ] **Step 3: Commit** `feat(resources): add sortable process group list`.

### Task 7: Agents section

**Files:**
- Create: `modules/resources/AgentList.qml`
- Modify: `modules/resources/Content.qml`

**Interfaces:**
- Consumes: `Resources.claude`, `Resources.groups`, `AgentState.sessions`, `ResourceLogic.agentRows`.
- Produces: `AgentList` rows: status dot (working green, waiting amber, idle grey, orphan red ✕), label, state/age (`idle 5h`, `orphan 11h`), RAM; Codex aggregate row last.

- [ ] **Step 1: Implement** `AgentList.qml` rendering `ResourceLogic.agentRows(...)`; orphan rows use `hot` colour; no actions (spec: stop button is Phase 2).
- [ ] **Step 2: Verify** against the live machine: the Claude row count equals `pgrep -xc claude`; orphan rows match `readlink /proc/<pid>/cwd` ending `(deleted)`; Codex row shows a RAM figure.
- [ ] **Step 3: Commit** `feat(resources): add Claude and Codex agent rows`.

### Task 8: Edge cases and wrap-up

**Files:**
- Modify: whichever file a failing check points to; `README.md` (one paragraph on the drawer)

- [ ] **Step 1: Run all tests**: `python3 -m unittest discover -s modules/dashboard/helpers -p 'test_*.py'` and `node --test modules/dashboard/helpers/` → Expected: all PASS, including pre-existing tests.
- [ ] **Step 2: Manual matrix**: fullscreen window → drawer never opens; two monitors → only the pointer's monitor opens; drag a window to the left edge → no open; open, then leave and return within 250 ms → stays open (no flicker).
- [ ] **Step 3: Update the spec** §6/§7 to record that `ContentWindow.qml` was not touched and why; add the README paragraph.
- [ ] **Step 4: Commit** `docs(resources): record drawer design deviation and usage`.
