pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../modules/dashboard/helpers/DevLogic.js" as Logic

// Developer data for the island: pull requests and CI, listening ports and
// containers, time per project, the commit streak and the standup draft.
Singleton {
    id: root

    readonly property string helpers: Quickshell.shellPath("modules/dashboard/helpers")

    // Pull requests: polled in the background, announced when something changes.
    property var pulls: ({ prs: [], merged: [], error: "" })
    property var pullState: null
    readonly property bool ciFailing: Logic.anyFailing(pulls)
    property double partyUntil
    property double now: Date.now()
    readonly property bool party: partyUntil > now
    signal pullEvent(string type, var pr)

    // Ports and containers: polled while the Ports tab is visible.
    property var ports: []
    property var containers: []
    property int portViewers
    property string portError

    // Time per project, the streak and level, refreshed when a view asks and every ten minutes.
    property var time: []
    property var streak: ({ streak: 0, level: 1, points: 0, next: 3, commits: 0, activeDays: 0 })
    signal standupReady(string text)
    signal failed(string message)

    function refreshPulls(): void { if (!pullsProcess.running) pullsProcess.running = true; }
    function refreshPorts(): void { if (!portsProcess.running) portsProcess.running = true; }
    function refreshReport(): void { if (!reportProcess.running) reportProcess.running = true; }
    function draftStandup(): void { if (!standupProcess.running) standupProcess.running = true; }
    function killPort(pid: int): void { act(["kill", String(pid)]); }
    function stopContainer(name: string): void { act(["stop", name]); }
    function act(args: var): void {
        if (actionProcess.running) return;
        actionProcess.command = ["python3", "-I", `${helpers}/dev_ports.py`, ...args];
        actionProcess.running = true;
    }

    Process {
        id: pullsProcess
        command: ["python3", "-I", `${root.helpers}/dev_prs.py`]
        stdout: StdioCollector {
            onStreamFinished: {
                let result;
                try { result = JSON.parse(text); } catch (_) { return; }
                // Errors (offline, signed out) keep the last good data and stay silent.
                if (result.error) { root.pulls = Object.assign({}, root.pulls, { error: result.error }); return; }
                const diff = Logic.diffPulls(root.pullState, result);
                root.pullState = diff.state;
                root.pulls = result;
                for (const e of diff.events) {
                    if (e.type === "merged") { root.now = Date.now(); root.partyUntil = root.now + 60000; }
                    root.pullEvent(e.type, e.pr);
                }
            }
        }
    }
    Process {
        id: portsProcess
        command: ["python3", "-I", `${root.helpers}/dev_ports.py`, "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { const r = JSON.parse(text); root.ports = r.ports ?? []; root.containers = r.containers ?? []; root.portError = r.error ?? ""; }
                catch (_) { root.portError = qsTr("Could not read ports"); }
            }
        }
    }
    Process {
        id: actionProcess
        stdout: StdioCollector {
            onStreamFinished: {
                try { const r = JSON.parse(text); if (r.error) root.failed(r.error); } catch (_) {}
                root.refreshPorts();
            }
        }
    }
    Process {
        id: reportProcess
        command: ["python3", "-I", `${root.helpers}/dev_report.py`, "report"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { const r = JSON.parse(text); if (!r.error) { root.time = r.time ?? []; root.streak = r.streak ?? root.streak; } } catch (_) {}
            }
        }
    }
    Process {
        id: standupProcess
        command: ["python3", "-I", `${root.helpers}/dev_report.py`, "standup"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { const r = JSON.parse(text); if (r.text) root.standupReady(r.text); else root.failed(r.error || qsTr("Could not draft the standup")); }
                catch (_) { root.failed(qsTr("Could not draft the standup")); }
            }
        }
    }

    Timer { interval: 150000; repeat: true; running: true; onTriggered: root.refreshPulls() }
    Timer { interval: 5000; running: true; onTriggered: root.refreshPulls() }
    Timer { interval: 8000; running: true; onTriggered: root.refreshReport() }
    Timer { interval: 600000; repeat: true; running: true; onTriggered: root.refreshReport() }
    Timer { interval: 5000; repeat: true; running: root.portViewers > 0; triggeredOnStart: true; onTriggered: root.refreshPorts() }
    // Only ticks while the party face is showing.
    Timer { interval: 2000; repeat: true; running: root.partyUntil > root.now; onTriggered: root.now = Date.now() }
}
