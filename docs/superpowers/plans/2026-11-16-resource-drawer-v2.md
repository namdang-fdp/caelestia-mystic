# Resource Drawer v2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the left-edge drawer into a five-tab, macOS-styled panel (Overview, Processes, Agents, Dev, System) with history, safe Stop actions, memory alerts, and the island's dev data.

**Architecture:** Pure logic stays in `ResourceLogic.js` (node-tested). Python helpers stay stdlib-only and stateless: `proc_top.py` (extended), new `proc_action.py` (safe stop), new `sys_stats.py` (GPU clock, disk). QML singletons: `Resources` (poll while open, exists), new `ResourcesHistory` (5 s `/proc` file reads, no spawn), new `ResourcesAlerts`, new `ResourcesActions`. The Dev tab only reads `DevData`.

**Tech Stack:** Quickshell QML, Python 3 stdlib (`unittest`), plain JS (`node --test`).

**Spec:** `docs/superpowers/specs/2026-11-16-resource-drawer-v2-design.md` (v1 spec: `2026-11-16-left-resource-drawer-design.md`).

## Global Constraints

- Branch `feat/resource-drawer-v2`, cut from `feat/island-dev-tools`. The owner keeps uncommitted WIP in this repo: commit with **explicit paths only**, never `git add -A`, never touch `README.md`.
- Tests: `python3 -m unittest discover -s modules/dashboard/helpers -p 'test_*.py'` and `node --test modules/dashboard/helpers/*.cjs` (never the bare directory). `qmlformat` is a syntax check only; `qmllint` is unusable here.
- QML does not hot-reload: apply with `qs -c caelestia kill; setsid qs -c caelestia -n -d`. The owner approved restarts for this feature work; if the harness blocks one, stop and ask. If load breaks, `git checkout --` the changed QML files and restart.
- Drive/inspect on Hyprland: `hyprctl dispatch "hl.dsp.cursor.move({ x = 1, y = 540 })"`, `grim -o HDMI-A-1 f.png` (never `-o` with `-g`). The owner moves the real mouse too.
- Palette (dark macOS): blue `#0A84FF`, green `#30D158`, orange `#FF9F0A`, red `#FF453A`, purple `#BF5AF2`, teal `#64D2FF`; panel `#0A0A0A`, card `#1C1C1E`, separator `#38383A`, label `#FFFFFF`, secondary `#EBEBF5` at 60%. Radii 12 panel / 10 card / 6 control. Font `Inter Variable`, tabular numbers (`font.features: { "tnum": 1 }`). Drawer card width **400**.
- Icons: Material Symbols via `MaterialIcon` (`fill` 0) in 22 px rounded-square tiles, white glyph on a system-colour fill.
- Closed drawer: no spawned process; allowed work is the 5 s `/proc` file reads of `ResourcesHistory`. Open drawer: tabs poll only what they show.
- Stop = SIGTERM only, two-step (first click arms for **3000 ms**, second fires). Alerts: RAM ≥ **0.85** or swap ≥ **0.5** on **3** consecutive **30 s** samples, once per **30 min** per kind. History: sample every **5000 ms**, keep **120** points.
- Protected names (never stoppable): `Hyprland, hyprland, quickshell, qs, systemd, pipewire, pipewire-pulse, wireplumber, dbus-daemon, dbus-broker, Xwayland`.

## Review Focus

- Stop with a stale `start` (pid reused), another user's process, a protected name, pid ≤ 1 or the helper's own/parent pid is **refused** (Task 3 tests).
- Double-click on one Stop within the confirm window fires once; a different row re-arms (Task 7 test).
- A single hot sample never alerts; after an alert the same kind stays quiet for 30 min; RAM and swap are independent (Task 1 tests).
- Truncated or odd `/proc/meminfo` / `/proc/stat` (missing `MemAvailable`, zero totals) never yields NaN or Infinity in the history (Task 1 tests).
- Nothing spawns while the drawer is closed, and leaving the Dev tab stops port polling (Task 5 and Task 10 checks).
- Two Stop requests while one is running are ignored, not queued (Task 7 check).

---

### Task 1: Pure logic for history, alerts and attention

**Files:**
- Modify: `modules/dashboard/helpers/ResourceLogic.js`
- Test: `modules/dashboard/helpers/test_resources.cjs`

**Interfaces:**
- Produces:
  - `parseMeminfo(text: string) -> {total_kb, available_kb, swap_total_kb, swap_free_kb}` (ints, 0 when missing).
  - `parseCpuStat(text: string) -> {total, idle}` (first `cpu` line; idle = idle+iowait; zeros when malformed).
  - `cpuPercent(prev: {total,idle}|null, cur: {total,idle}) -> number` (0..100, 0 when `prev` null or no progress).
  - `ring(list: number[], value: number, max: number) -> number[]` (new array, drops the oldest beyond `max`; non-finite `value` stored as 0).
  - `sparkPoints(values: number[], width: number, height: number, ceiling: number) -> {x,y}[]` (x evenly spread, y inverted, clamped to the box).
  - `alertStep(state: object|null, sample: {ramFrac, swapFrac}, nowMs: number) -> {state, fire: "ram"|"swap"|null}` (thresholds/cooldown from Global Constraints; at most one `fire` per call, RAM first).
  - `alertText(kind, fraction, topGroup: string) -> {title, body}`.
  - `attention(sysFracs: {ram, swap}, rows: array) -> null | {level: "warm"|"hot", text, tab: "processes"|"agents"}` (rows from `agentRows`; points to `agents` when idle Claude rows hold ≥ 200 MB, else `processes`).
  - `confirmClick(armed: {key, until}|null, key: string, nowMs: number, windowMs: number) -> {fire: boolean, armed: {key, until}|null}`.
  - `orphanTargets(claude: array) -> [{pid, start}]` (only `orphan:true` rows).
  - `isProtected(name: string) -> boolean` (the protected-names list from Global Constraints; the QML hides Stop for these, `proc_action.py` enforces it independently).

- [ ] **Step 1: Write failing tests** (one `test(...)` each): `parseMeminfo reads kb fields and tolerates missing ones`, `parseCpuStat and cpuPercent over two samples`, `cpuPercent is 0 without a previous sample or progress`, `ring caps length and stores non-finite as 0`, `sparkPoints spreads x, inverts y and clamps`, `a single hot sample does not alert`, `three consecutive hot samples alert once then stay quiet inside 30 minutes`, `ram and swap alert independently`, `a cool sample resets the streak`, `attention points to agents when idle sessions hold memory, else processes`, `confirmClick arms then fires inside the window, re-arms after it or for another key`, `orphanTargets keeps only orphans`, `isProtected matches exactly the listed names`, `alertText names the top group`.
- [ ] **Step 2: Run** `node --test modules/dashboard/helpers/test_resources.cjs` → Expected: FAIL (functions not defined).
- [ ] **Step 3: Implement** the functions above in `ResourceLogic.js` (no new state outside arguments).
- [ ] **Step 4: Run** the same command → Expected: all PASS (old and new).
- [ ] **Step 5: Commit** `feat(resources): add history, alert, attention and confirm logic`.

### Task 2: `proc_top.py` returns top processes per group

**Files:**
- Modify: `modules/dashboard/helpers/proc_top.py`
- Test: `modules/dashboard/helpers/test_proc_top.py`

**Interfaces:**
- Consumes: existing `read_processes`/`collect`.
- Produces: each `read_processes` item gains `uid:int` (owner of the `/proc/<pid>` entry). `collect()["groups"][i]` gains `top: [{pid, name, ram_kb, cpu_percent, start, own}]` (up to 5, RAM descending, `own` = uid equals `os.getuid()`); each `collect()["claude"][i]` gains `start:int`.

- [ ] **Step 1: Write failing tests**: `test_groups_carry_top_five_by_ram_with_own_flag` (seven same-exe processes → five returned, descending), `test_top_entry_has_start_ticks_for_identity`, `test_claude_rows_carry_start`.
- [ ] **Step 2: Run** `python3 -m unittest modules/dashboard/helpers/test_proc_top.py` → Expected: FAIL (`KeyError: 'top'`).
- [ ] **Step 3: Implement** by extending the existing grouping loop; the JSON stays backward compatible.
- [ ] **Step 4: Run** the same command → Expected: all PASS; then `python3 -I modules/dashboard/helpers/proc_top.py | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['groups'][0]['top'][0])"` → a dict with `pid` and `start`.
- [ ] **Step 5: Commit** `feat(resources): return top processes per group and process identity`.

### Task 3: `proc_action.py` — safe stop

**Files:**
- Create: `modules/dashboard/helpers/proc_action.py`
- Test: `modules/dashboard/helpers/test_proc_action.py`

**Interfaces:**
- Produces: `PROTECTED: frozenset[str]` (Global Constraints list); `check(pid: int, start: int, proc: Path = Path("/proc"), uid: int = os.getuid(), self_pids: tuple = (os.getpid(), os.getppid())) -> str` returns `""` when stoppable, else a short reason (`"gone"`, `"changed"`, `"not yours"`, `"protected"`, `"system"`); `stop(pid, start, proc=..., uid=..., kill=os.kill) -> {"ok": bool, "error": str}` (SIGTERM via `kill` only when `check` is empty); CLI `proc_action.py stop <pid> <start>` prints that JSON.

- [ ] **Step 1: Write failing tests** with a fake `/proc` and an injected `kill`: `test_stop_sends_sigterm_once_for_own_matching_process`, `test_refuses_when_start_ticks_differ` (pid reuse), `test_refuses_other_users_process`, `test_refuses_protected_names` (each name in `PROTECTED`), `test_refuses_pid_1_and_below`, `test_refuses_own_and_parent_pid`, `test_missing_pid_reports_gone`, `test_cli_prints_json_and_bad_args_fail_cleanly`.
- [ ] **Step 2: Run** `python3 -m unittest modules/dashboard/helpers/test_proc_action.py` → Expected: FAIL (`ModuleNotFoundError`).
- [ ] **Step 3: Implement**; reuse `proc_top._parse_stat` for comm and start ticks (import it from the sibling file the way `test_*` modules do, via `sys.path`).
- [ ] **Step 4: Run** the same command → Expected: all PASS. Live: `sleep 600 & python3 -I modules/dashboard/helpers/proc_action.py stop $! <its start ticks>` → `{"ok": true, ...}` and the sleep is gone; `... stop $(pgrep -xo qs) 0` → `ok:false` with `protected` or `changed`.
- [ ] **Step 5: Commit** `feat(resources): add guarded process stop helper`.

### Task 4: macOS theme, icon tiles, tabs, cards

**Files:**
- Modify: `services/ResourcesTheme.qml`, `modules/resources/Wrapper.qml` (card width 400)
- Create: `modules/resources/IconTile.qml`, `modules/resources/TabBar.qml`, `modules/resources/Card.qml`

**Interfaces:**
- Produces: `ResourcesTheme` keeps every v1 property name and adds `card`, `separator`, `textTertiary`, `blue`, `purple`, `teal`, `radiusCard: 10`, `radiusControl: 6`; `uiFont` and `numFont` become `"Inter Variable"`. `IconTile { property string icon; property color tint }` (22 px). `TabBar { property var tabs; property string current; signal picked(string id) }` where `tabs` items are `{id, icon, tint, label}`; the active tab shows icon tile + label, others the tile only. `Card { property string title; property string trailing }` with a default content slot.

- [ ] **Step 1: Implement** the three components and the theme values per Global Constraints; the TabBar highlight slides (`Behavior on x`, 200 ms, no overshoot).
- [ ] **Step 2: Syntax check** `/usr/lib/qt6/bin/qmlformat` on each file → Expected: no error.
- [ ] **Step 3: Verify live** after a restart: open the drawer (cursor to `1,540`); `grim` crop shows 400 px card, Inter text, no QML errors (`strings -n 6 /run/user/1000/quickshell/by-id/*/log.qslog | grep -aiE "modules/resources|ResourcesTheme"` empty).
- [ ] **Step 4: Commit** `feat(resources): add macOS theme, icon tiles, tab bar and card`.

### Task 5: `ResourcesHistory` service

**Files:**
- Create: `services/ResourcesHistory.qml`

**Interfaces:**
- Consumes: `Logic.parseMeminfo/parseCpuStat/cpuPercent/ring`.
- Produces (singleton `ResourcesHistory`): `property var ram, swap, cpu` (arrays of 0..100, ≤120), `readonly property real ramFrac, swapFrac` (latest, 0..1), `readonly property bool ready`, `signal sampled()`. Samples every 5000 ms via `FileView` on `/proc/meminfo` and `/proc/stat` (same `reload()`/`text()` pattern as `NetworkUsage`), starting at singleton creation, no `Process`.

- [ ] **Step 1: Implement** the singleton; instantiate it from `Panels.qml`-level or `Content` so it exists at shell start (reference it once in `modules/resources/Wrapper.qml` via `Component.onCompleted: ResourcesHistory.ready`).
- [ ] **Step 2: Verify live**: after ~30 s `ResourcesHistory.ram.length` grows (temporary `console.log`, removed after); `pgrep -af proc_top` is empty while closed; idle cost: shell CPU time over 60 s with the drawer closed grows by < 0.5 s (`ps -o cputime= -p $(pgrep -xo qs)` at both ends).
- [ ] **Step 3: Commit** `feat(resources): add always-on lightweight history sampling`.

### Task 6: Tab host and Overview

**Files:**
- Create: `modules/resources/Sparkline.qml`, `modules/resources/MetricCard.qml`, `modules/resources/Overview.qml`
- Modify: `modules/resources/Content.qml` (TabBar + `StackLayout`; Overview, Processes = `GroupList`, Agents = `AgentList`; keep `Resources.viewers` lifecycle)

**Interfaces:**
- Produces: `Sparkline { property var values; property color tint; property real ceiling: 100 }` (draws `Logic.sparkPoints`, Canvas or Shape); `MetricCard { property string title, value, detail; property var values; property color tint }`; `Overview` shows Memory, CPU (+`IslandHealth.temperature` when ≥ 0) and Swap cards plus a network line (`NetworkUsage.downloadSpeed/uploadSpeed`, `refCount` raised while visible) and an attention banner from `Logic.attention(...)` whose button switches tab; an alert switch row is added in Task 9.

- [ ] **Step 1: Implement** the components; tint from `Logic.severity` (green/orange/red).
- [ ] **Step 2: Verify live**: Overview matches `free -h` and a sparkline of ≥ 20 points appears within 2 minutes of shell start; switching tabs shows Processes and Agents unchanged; banner appears when `Logic.attention` is non-null (force with a lowered threshold temporarily, then revert).
- [ ] **Step 3: Commit** `feat(resources): add tab host and Overview with history sparklines`.

### Task 7: Processes drill-down and Stop

**Files:**
- Create: `services/ResourcesActions.qml`
- Modify: `modules/resources/GroupList.qml`

**Interfaces:**
- Consumes: `Resources.groups[].top`, `Logic.confirmClick`, `proc_action.py` (Task 3).
- Produces (singleton `ResourcesActions`): `property bool busy`, `property string status`, `function stop(pid: int, start: int): void` (ignored while `busy`; runs `python3 -I proc_action.py stop <pid> <start>`, sets `status` to the result), `signal stopped(var result)`.

- [ ] **Step 1: Implement** expandable group rows (one open at a time) showing top 5 processes (name, PID, RAM, CPU); each row has a Stop button for `own` processes that are not `Logic.isProtected`, using `confirmClick` (first click shows "Stop?", second calls `ResourcesActions.stop`); after `stopped` refresh via `Resources.refresh()`.
- [ ] **Step 2: Verify live** on a throwaway process: `sleep 900 &` appears under its group within a few seconds, Stop? then Stop removes it; a protected row (`qs`) shows no Stop button; clicking Stop twice quickly fires once (`pgrep -fc "proc_action.py stop"` over the click window ≤ 1).
- [ ] **Step 3: Commit** `feat(resources): expand groups and stop own processes with confirmation`.

### Task 8: Agents — stop orphans

**Files:**
- Modify: `modules/resources/AgentList.qml`

**Interfaces:**
- Consumes: `Logic.orphanTargets(Resources.claude)`, `ResourcesActions.stop`, `Logic.confirmClick`.

- [ ] **Step 1: Implement** a Stop button on orphan rows and a header action "Stop N orphans" (hidden when 0), both two-step; the bulk action stops targets one after another (next starts on `stopped`).
- [ ] **Step 2: Verify live** with a synthetic orphan: `cp /usr/bin/sleep /tmp/claude; mkdir /tmp/orph; (cd /tmp/orph && exec /tmp/claude 900 &); rmdir /tmp/orph` (its exe basename is `claude` and its cwd is deleted, so it appears as a red orphan row); Stop? then Stop removes it; "Stop N orphans" shows the same N as `orphanTargets`; clean up `/tmp/claude`.
- [ ] **Step 3: Commit** `feat(resources): stop orphaned agent processes`.

### Task 9: Alerts

**Files:**
- Create: `services/ResourcesAlerts.qml`
- Modify: `modules/resources/Overview.qml` (alert switch row)

**Interfaces:**
- Consumes: `ResourcesHistory.ramFrac/swapFrac`, `Logic.alertStep/alertText`.
- Produces (singleton `ResourcesAlerts`): `property bool enabled` (persisted in `${Paths.state}/resources.json` through the same `FileView` + `JsonAdapter` + 400 ms save timer as `IslandTools`), `function setEnabled(on: bool): void`. Every 30 s it feeds `alertStep`; on `fire` it runs `proc_top.py` once to name the biggest group and then `Quickshell.execDetached(["notify-send", "-a", "Island", "-i", "dialog-warning", title, body])`.

- [ ] **Step 1: Implement** the service and the switch (default on).
- [ ] **Step 2: Verify live**: temporarily set the RAM threshold to 0.01 and the cooldown to 60 s → exactly one notification, none again before the cooldown (`makoctl history`/the notification daemon in use); revert the constants; the switch off stops all notifications and persists across a shell restart.
- [ ] **Step 3: Commit** `feat(resources): add memory pressure notifications with a switch`.

### Task 10: Dev tab

**Files:**
- Create: `modules/resources/DevTab.qml`
- Modify: `modules/resources/Content.qml` (add the Dev tab, green `terminal` tile)

**Interfaces:**
- Consumes: `DevData.ports`, `DevData.containers`, `DevData.pulls`, `DevData.portViewers`, `refreshPorts()`, `refreshPulls()`, `killPort(pid)`, `stopContainer(name)`; the PR fields as produced by `dev_prs.py` (read its output shape, including the CI state from `summarize_checks`).

- [ ] **Step 1: Implement** compact sections Ports (`:3000`, name, project, local/open badge, two-step Stop), Docker (name, image, status, two-step Stop), Pull requests (title, `repo #n`, CI dot green/orange/red, review badge). Do not call anything that triggers `pullEvent` side effects; only read.
- [ ] **Step 2: Verify live**: start `python3 -m http.server 8765` → `:8765` appears within a refresh; Stop removes it; leaving the tab drops `portViewers` (`pgrep -af "dev_ports.py list"` empty after 5 s); PR list matches the island's Dev view.
- [ ] **Step 3: Commit** `feat(resources): add Dev tab reusing island dev data`.

### Task 11: System tab

**Files:**
- Create: `modules/dashboard/helpers/sys_stats.py`, `modules/dashboard/helpers/test_sys_stats.py`, `modules/resources/SystemTab.qml`
- Modify: `services/Resources.qml` (or a new `services/ResourcesSystem.qml`) to poll `sys_stats.py` while the System tab shows; `modules/resources/Content.qml` (teal `cpu` tile); `ResourceLogic.js` + test: `formatRate(bytesPerSec) -> string`

**Interfaces:**
- Produces: `sys_stats.collect(sys: Path = Path("/sys"), proc: Path = Path("/proc"), root: str = "/", interval: float = 0.3, sleep=time.sleep) -> {"gpu": {"cur_mhz", "max_mhz"} | None, "disk": {"total_kb", "used_kb", "read_bps", "write_bps"}}`; GPU from the first `/sys/class/drm/card*/gt_cur_freq_mhz` + `gt_max_freq_mhz`, `None` when absent; disk usage via `os.statvfs(root)`, throughput from `/proc/diskstats` deltas of the root device's whole disk (sectors × 512).

- [ ] **Step 1: Write failing tests** (fake sysfs/proc trees): `test_gpu_clock_from_first_card_with_freq_files`, `test_gpu_none_without_freq_files`, `test_disk_throughput_from_two_diskstats_samples`, `test_missing_diskstats_gives_zero_rates`; node: `formatRate 0, 1023, 1 MB/s`.
- [ ] **Step 2: Run** both suites → Expected: FAIL.
- [ ] **Step 3: Implement** helper, `formatRate`, and the tab: GPU clock bar labelled "GPU clock" (not utilisation), disk used/total bar with read/write rates, network ↓↑ with `NetworkUsage` history (`refCount` raised while visible).
- [ ] **Step 4: Run** both suites → Expected: PASS. Live: values agree with `cat /sys/class/drm/card1/gt_cur_freq_mhz`, `df -h /`, and a `dd` write test moves the write rate.
- [ ] **Step 5: Commit** `feat(resources): add System tab with GPU clock, disk and network`.

### Task 12: Close-out

**Files:**
- Modify: `docs/resource-drawer.md`, `docs/superpowers/specs/2026-11-16-resource-drawer-v2-design.md` (status → built, findings)

- [ ] **Step 1: Run all suites** (both commands from Global Constraints) → Expected: all PASS.
- [ ] **Step 2: Manual matrix**: every tab renders without QML errors; closed-drawer idle cost (Task 5 measure) still < 0.5 s CPU per minute; hover trigger and slide unchanged from v1; stop safety on a throwaway process and refusal on `qs`.
- [ ] **Step 3: Update docs** (tabs, safeguards, findings such as the GPU being clock-only on this machine) and commit `docs(resources): document v2 tabs, safeguards and findings`.
