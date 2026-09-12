pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia
import qs.utils

Singleton {
    id: root

    readonly property string stateDirectory: `${Paths.state}/leetcode-timer`
    readonly property string currentPath: `${stateDirectory}/current.json`
    readonly property string historyPath: `${stateDirectory}/history.jsonl`
    readonly property int historyLimit: 250
    readonly property int recentLimit: 8

    property string problemNumber
    property string problemTitle
    property string difficulty: "Medium"
    property int targetDuration: 25 * 60 * 1000
    property double firstStartedAt
    property double startedAt
    property double elapsedBeforeCurrentRun
    property string status: "idle"
    property var checkpoints: []
    property string lastResult
    property double now: Date.now()

    property var history: []
    property bool currentLoaded
    property bool historyLoaded
    property var appendQueue: []
    property string appendPayload

    readonly property bool storageReady: currentLoaded && historyLoaded
    readonly property bool hasActiveSession: status === "running" || status === "paused"
    readonly property bool isRunning: status === "running"
    readonly property int elapsedDuration: Math.max(0, Math.floor(elapsedAt(now)))
    readonly property real targetProgress: targetDuration > 0 ? Math.min(1, elapsedDuration / targetDuration) : 0
    readonly property var recentSessions: history.slice(0, recentLimit)
    readonly property int acCountToday: acSessionsToday().length
    readonly property int averageAcDurationToday: {
        const sessions = acSessionsToday();
        if (sessions.length === 0)
            return -1;
        return Math.round(sessions.reduce((sum, session) => sum + session.totalElapsedDuration, 0) / sessions.length);
    }
    readonly property int personalBest: {
        const matches = history.filter(session => session.result === "AC" && sameProblem(session));
        return matches.length === 0 ? -1 : Math.min(...matches.map(session => session.totalElapsedDuration));
    }
    readonly property int attemptCount: history.filter(session => sameProblem(session)).length

    signal sessionStarted
    signal sessionCompleted(string result)

    function presetFor(value: string): int {
        if (value === "Easy")
            return 10 * 60 * 1000;
        if (value === "Hard")
            return 40 * 60 * 1000;
        return 25 * 60 * 1000;
    }

    function elapsedAt(epoch: double): double {
        const carried = Number.isFinite(elapsedBeforeCurrentRun) ? elapsedBeforeCurrentRun : 0;
        if (status !== "running" || startedAt <= 0)
            return carried;
        return carried + Math.max(0, epoch - startedAt);
    }

    function formatDuration(milliseconds: double): string {
        if (!Number.isFinite(milliseconds) || milliseconds < 0)
            return "--:--";
        const totalSeconds = Math.floor(milliseconds / 1000);
        const hours = Math.floor(totalSeconds / 3600);
        const minutes = Math.floor((totalSeconds % 3600) / 60);
        const seconds = (totalSeconds % 60).toString().padStart(2, "0");
        return hours > 0
            ? `${hours}:${minutes.toString().padStart(2, "0")}:${seconds}`
            : `${minutes.toString().padStart(2, "0")}:${seconds}`;
    }

    function normalisedTitle(value: string): string {
        return String(value ?? "").trim().toLowerCase().replace(/\s+/g, " ");
    }

    function sameProblem(session: var): bool {
        const currentNumber = String(problemNumber ?? "").trim();
        const sessionNumber = String(session?.problemNumber ?? "").trim();
        if (currentNumber && sessionNumber)
            return currentNumber === sessionNumber;
        const currentTitle = normalisedTitle(problemTitle);
        return !!currentTitle && currentTitle === normalisedTitle(session?.title ?? "");
    }

    function acSessionsToday(): var {
        const today = new Date().toDateString();
        return history.filter(session => session.result === "AC"
            && new Date(session.completedAt ?? session.startedAt).toDateString() === today);
    }

    function parseProblemTitle(windowTitle: string): var {
        const primitiveTitle = String(windowTitle ?? "").trim();
        const match = primitiveTitle.match(/^\s*(\d+)\.\s+(.+?)\s+-\s+LeetCode(?:\s*[-|·].*)?\s*$/i);
        if (!match)
            return null;
        const number = match[1].trim();
        const title = match[2].trim();
        return number && title ? {
            problemNumber: number,
            title
        } : null;
    }

    function prefillFromTitle(windowTitle: string, force = false): bool {
        if (hasActiveSession)
            return false;
        const detected = parseProblemTitle(windowTitle);
        if (!detected)
            return false;
        if (!force && status !== "finished" && (problemNumber || problemTitle))
            return false;
        if (status === "finished")
            resetSession(false);
        problemNumber = detected.problemNumber;
        problemTitle = detected.title;
        return true;
    }

    function prefillFromActiveWindow(force = false): bool {
        // Copy the live QObject's title immediately; never retain the toplevel.
        const activeTitle = String(Hypr.activeToplevel?.title ?? "");
        return prefillFromTitle(activeTitle, force);
    }

    function setProblem(number: string, title: string): void {
        problemNumber = String(number ?? "").trim();
        problemTitle = String(title ?? "").trim();
        saveCurrent();
    }

    function setDifficulty(value: string): void {
        if (!["Easy", "Medium", "Hard"].includes(value))
            return;
        const previousPreset = presetFor(difficulty);
        difficulty = value;
        if (targetDuration === previousPreset || targetDuration <= 0)
            targetDuration = presetFor(value);
        saveCurrent();
    }

    function setTargetMinutes(value: var): bool {
        const minutes = Number(value);
        if (!Number.isFinite(minutes) || minutes <= 0 || minutes > 999)
            return false;
        targetDuration = Math.round(minutes * 60 * 1000);
        saveCurrent();
        return true;
    }

    function startOrToggle(): void {
        if (!storageReady)
            return;
        if (status === "running") {
            pause();
            return;
        }
        if (status === "paused") {
            resume();
            return;
        }
        const epoch = Date.now();
        elapsedBeforeCurrentRun = 0;
        firstStartedAt = epoch;
        startedAt = epoch;
        checkpoints = [];
        lastResult = "";
        status = "running";
        now = epoch;
        saveCurrent();
        sessionStarted();
    }

    function pause(): void {
        if (status !== "running")
            return;
        const epoch = Date.now();
        elapsedBeforeCurrentRun = elapsedAt(epoch);
        startedAt = 0;
        status = "paused";
        now = epoch;
        saveCurrent();
    }

    function resume(): void {
        if (status !== "paused")
            return;
        const epoch = Date.now();
        startedAt = epoch;
        status = "running";
        now = epoch;
        saveCurrent();
    }

    function resetSession(clearProblem = false): void {
        status = "idle";
        firstStartedAt = 0;
        startedAt = 0;
        elapsedBeforeCurrentRun = 0;
        checkpoints = [];
        lastResult = "";
        now = Date.now();
        if (clearProblem) {
            problemNumber = "";
            problemTitle = "";
            difficulty = "Medium";
            targetDuration = presetFor(difficulty);
        }
        clearCurrent();
    }

    function checkpointElapsed(name: string): int {
        const checkpoint = checkpoints.find(item => item.name === name);
        return checkpoint ? checkpoint.elapsedDuration : -1;
    }

    function addCheckpoint(name: string): bool {
        if (!hasActiveSession || !["Idea", "Code", "Debug"].includes(name)
                || checkpoints.some(item => item.name === name))
            return false;
        const next = checkpoints.slice();
        const epoch = Date.now();
        const preciseElapsed = Math.max(0, Math.floor(elapsedAt(epoch)));
        next.push({
            name,
            elapsedDuration: preciseElapsed
        });
        checkpoints = next;
        now = epoch;
        saveCurrent();
        return true;
    }

    function complete(result: string): bool {
        if (!hasActiveSession || !["AC", "GIVE_UP"].includes(result))
            return false;
        const epoch = Date.now();
        const total = Math.max(0, Math.floor(elapsedAt(epoch)));
        const record = {
            version: 1,
            problemNumber: String(problemNumber ?? "").trim(),
            title: String(problemTitle ?? "").trim(),
            difficulty,
            startedAt: firstStartedAt,
            completedAt: epoch,
            totalElapsedDuration: total,
            targetDuration,
            result,
            checkpoints: checkpoints.map(item => ({
                name: item.name,
                elapsedDuration: item.elapsedDuration
            }))
        };
        history = [record, ...history].slice(0, historyLimit);
        enqueueHistoryRecord(record);
        elapsedBeforeCurrentRun = total;
        startedAt = 0;
        status = "finished";
        lastResult = result;
        now = epoch;
        clearCurrent();
        sessionCompleted(result);
        return true;
    }

    function currentRecord(): var {
        return {
            version: 1,
            problemNumber: String(problemNumber ?? "").trim(),
            title: String(problemTitle ?? "").trim(),
            difficulty,
            targetDuration,
            firstStartedAt,
            startedAt,
            elapsedBeforeCurrentRun,
            status,
            checkpoints: checkpoints.map(item => ({
                name: item.name,
                elapsedDuration: item.elapsedDuration
            }))
        };
    }

    function saveCurrent(): void {
        if (!currentLoaded || !hasActiveSession)
            return;
        currentFile.setText(JSON.stringify(currentRecord(), null, 2) + "\n");
    }

    function clearCurrent(): void {
        if (currentLoaded)
            currentFile.setText("{}\n");
    }

    function validCheckpoint(item: var): bool {
        return !!item && ["Idea", "Code", "Debug"].includes(item.name)
            && Number.isFinite(Number(item.elapsedDuration)) && Number(item.elapsedDuration) >= 0;
    }

    function restoreCurrent(text: string): void {
        try {
            const data = JSON.parse(text || "{}");
            if (!data || !["running", "paused"].includes(data.status)) {
                currentLoaded = true;
                return;
            }
            const restoredTarget = Number(data.targetDuration);
            const restoredElapsed = Number(data.elapsedBeforeCurrentRun);
            const restoredFirstStart = Number(data.firstStartedAt);
            const restoredStartedAt = Number(data.startedAt);
            if (!Number.isFinite(restoredTarget) || restoredTarget <= 0
                    || !Number.isFinite(restoredElapsed) || restoredElapsed < 0
                    || !Number.isFinite(restoredFirstStart) || restoredFirstStart <= 0
                    || (data.status === "running" && (!Number.isFinite(restoredStartedAt) || restoredStartedAt <= 0)))
                throw new Error("invalid recoverable timer fields");

            problemNumber = String(data.problemNumber ?? "").trim();
            problemTitle = String(data.title ?? "").trim();
            difficulty = ["Easy", "Medium", "Hard"].includes(data.difficulty) ? data.difficulty : "Medium";
            targetDuration = Math.round(restoredTarget);
            firstStartedAt = restoredFirstStart;
            startedAt = data.status === "running" ? restoredStartedAt : 0;
            elapsedBeforeCurrentRun = restoredElapsed;
            status = data.status;
            checkpoints = Array.isArray(data.checkpoints)
                ? data.checkpoints.filter(validCheckpoint).map(item => ({
                    name: item.name,
                    elapsedDuration: Math.floor(Number(item.elapsedDuration))
                }))
                : [];
            now = Date.now();
        } catch (error) {
            console.info(lc, `Ignoring invalid LeetCode timer recovery state: ${error}`);
            Qt.callLater(clearCurrent);
        }
        currentLoaded = true;
    }

    function validHistoryRecord(data: var): bool {
        return !!data && ["AC", "GIVE_UP"].includes(data.result)
            && Number.isFinite(Number(data.startedAt)) && Number(data.startedAt) > 0
            && Number.isFinite(Number(data.totalElapsedDuration)) && Number(data.totalElapsedDuration) >= 0
            && Number.isFinite(Number(data.targetDuration)) && Number(data.targetDuration) > 0;
    }

    function loadHistory(text: string): void {
        const records = [];
        let ignored = 0;
        for (const line of String(text ?? "").split("\n")) {
            if (!line.trim())
                continue;
            try {
                const data = JSON.parse(line);
                if (!validHistoryRecord(data)) {
                    ignored++;
                    continue;
                }
                records.push({
                    version: Number(data.version ?? 1),
                    problemNumber: String(data.problemNumber ?? "").trim(),
                    title: String(data.title ?? "").trim(),
                    difficulty: ["Easy", "Medium", "Hard"].includes(data.difficulty) ? data.difficulty : "Medium",
                    startedAt: Number(data.startedAt),
                    completedAt: Number(data.completedAt ?? data.startedAt),
                    totalElapsedDuration: Math.floor(Number(data.totalElapsedDuration)),
                    targetDuration: Math.floor(Number(data.targetDuration)),
                    result: data.result,
                    checkpoints: Array.isArray(data.checkpoints) ? data.checkpoints.filter(validCheckpoint) : []
                });
            } catch (error) {
                ignored++;
            }
        }
        records.sort((a, b) => b.completedAt - a.completedAt);
        history = records.slice(0, historyLimit);
        historyLoaded = true;
        if (ignored > 0)
            console.info(lc, `Ignored ${ignored} malformed LeetCode history ${ignored === 1 ? "entry" : "entries"}`);
        Qt.callLater(startNextAppend);
    }

    function enqueueHistoryRecord(record: var): void {
        const next = appendQueue.slice();
        next.push(JSON.stringify(record));
        appendQueue = next;
        startNextAppend();
    }

    function startNextAppend(): void {
        if (!historyLoaded || appendProcess.running || appendQueue.length === 0)
            return;
        appendPayload = appendQueue[0];
        appendProcess.exec(["sh", "-c", "IFS= read -r line; printf '%s\\n' \"$line\" >> \"$1\"", "caelestia-leetcode-history", historyPath]);
    }

    Timer {
        interval: 250
        running: root.status === "running"
        repeat: true
        triggeredOnStart: true
        onTriggered: root.now = Date.now()
    }

    Process {
        id: storageInitialiser

        onExited: exitCode => {
            if (exitCode !== 0) {
                console.warn(lc, `Unable to create LeetCode timer state directory (exit ${exitCode})`);
                return;
            }
            currentFile.path = root.currentPath;
            historyFile.path = root.historyPath;
        }
    }

    FileView {
        id: currentFile

        atomicWrites: true
        printErrors: false
        onLoaded: root.restoreCurrent(text())
        onLoadFailed: error => {
            root.currentLoaded = true;
            if (error !== FileViewError.FileNotFound)
                console.warn(lc, `Unable to load LeetCode timer recovery state: ${FileViewError.toString(error)}`);
            Qt.callLater(root.clearCurrent);
        }
        onSaveFailed: error => console.warn(lc, `Unable to save LeetCode timer recovery state: ${FileViewError.toString(error)}`)
    }

    FileView {
        id: historyFile

        printErrors: false
        onLoaded: root.loadHistory(text())
        onLoadFailed: error => {
            root.history = [];
            root.historyLoaded = true;
            if (error === FileViewError.FileNotFound)
                setText("");
            else
                console.warn(lc, `Unable to load LeetCode timer history: ${FileViewError.toString(error)}`);
            Qt.callLater(root.startNextAppend);
        }
        onSaveFailed: error => console.warn(lc, `Unable to initialise LeetCode timer history: ${FileViewError.toString(error)}`)
    }

    Process {
        id: appendProcess

        stdinEnabled: true
        onStarted: write(root.appendPayload + "\n")
        onExited: exitCode => {
            const next = root.appendQueue.slice(1);
            root.appendQueue = next;
            if (exitCode !== 0)
                console.warn(lc, `Unable to append LeetCode timer history (exit ${exitCode})`);
            Qt.callLater(root.startNextAppend);
        }
    }

    IpcHandler {
        function status(): string {
            return JSON.stringify({
                state: root.status,
                problemNumber: root.problemNumber,
                title: root.problemTitle,
                difficulty: root.difficulty,
                targetDuration: root.targetDuration,
                elapsedDuration: Math.max(0, Math.floor(root.elapsedAt(Date.now()))),
                checkpoints: root.checkpoints,
                historyCount: root.history.length,
                stats: {
                    acCountToday: root.acCountToday,
                    averageAcDurationToday: root.averageAcDurationToday,
                    personalBest: root.personalBest,
                    attemptCount: root.attemptCount
                },
                recentSessions: root.recentSessions
            });
        }

        function detect(title: string): string {
            return JSON.stringify(root.parseProblemTitle(title));
        }

        function prefill(title: string): bool {
            return root.prefillFromTitle(title, true);
        }

        function setProblem(number: string, title: string): void {
            root.setProblem(number, title);
        }

        function start(): void {
            if (root.status !== "running")
                root.startOrToggle();
        }

        function pause(): void {
            root.pause();
        }

        function resume(): void {
            root.resume();
        }

        function reset(): void {
            root.resetSession(false);
        }

        function checkpoint(name: string): bool {
            return root.addCheckpoint(name);
        }

        function finish(result: string): bool {
            return root.complete(result);
        }

        target: "leetcodeTimer"
    }

    Component.onCompleted: storageInitialiser.exec(["mkdir", "-p", stateDirectory])

    LoggingCategory {
        id: lc

        name: "caelestia.qml.leetcodetimer"
        defaultLogLevel: LoggingCategory.Info
    }
}
