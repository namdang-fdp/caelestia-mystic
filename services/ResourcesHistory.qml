pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../modules/dashboard/helpers/ResourceLogic.js" as Logic

// Rolling RAM / swap / CPU percentages for the drawer's sparklines. Always on, but it only
// re-reads two tiny /proc files every few seconds: no process is spawned.
Singleton {
    id: root

    readonly property int interval: 5000
    readonly property int maxPoints: 120

    // Percentages 0..100, oldest first.
    property var ram: []
    property var swap: []
    property var cpu: []
    // Latest values as fractions 0..1.
    property real ramFrac
    property real swapFrac
    property real usedKb
    property real totalKb
    property real swapUsedKb
    property real swapTotalKb
    property bool ready

    property var cpuPrev: null

    signal sampled

    function sample(): void {
        memFile.reload();
        statFile.reload();
        const memText = memFile.text();
        const statText = statFile.text();
        if (!memText || !statText)
            return;
        const mem = Logic.parseMeminfo(memText);
        const cpuNow = Logic.parseCpuStat(statText);
        const ramF = Logic.fraction(mem.total_kb - mem.available_kb, mem.total_kb);
        const swapF = Logic.fraction(mem.swap_total_kb - mem.swap_free_kb, mem.swap_total_kb);
        usedKb = mem.total_kb - mem.available_kb;
        totalKb = mem.total_kb;
        swapUsedKb = mem.swap_total_kb - mem.swap_free_kb;
        swapTotalKb = mem.swap_total_kb;
        ramFrac = ramF;
        swapFrac = swapF;
        ram = Logic.ring(ram, ramF * 100, maxPoints);
        swap = Logic.ring(swap, swapF * 100, maxPoints);
        cpu = Logic.ring(cpu, Logic.cpuPercent(cpuPrev, cpuNow), maxPoints);
        cpuPrev = cpuNow;
        ready = true;
        sampled();
    }

    FileView {
        id: memFile
        path: "/proc/meminfo"
    }
    FileView {
        id: statFile
        path: "/proc/stat"
    }

    Timer {
        interval: root.interval
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.sample()
    }
}
