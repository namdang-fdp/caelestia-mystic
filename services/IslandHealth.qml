pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import Caelestia.Config
import qs.utils
import "../modules/dashboard/helpers/ActivityLogic.js" as Logic

Singleton {
    id: root
    property real temperature: -1
    property int hotSamples: 0
    property bool hot: false
    readonly property int batteryWarning: Logic.batteryLevel(UPower.displayDevice.isLaptopBattery, UPower.onBattery, UPower.displayDevice.percentage)
    readonly property bool warning: batteryWarning > 0 || hot
    readonly property string icon: batteryWarning > 0 ? "battery_alert" : "device_thermostat"
    readonly property string label: batteryWarning > 0 ? qsTr("Battery %1%").arg(Math.round(UPower.displayDevice.percentage * 100)) : qsTr("CPU %1°C").arg(Math.round(temperature))
    // Low battery is announced by BatteryMonitor's toasts; the pill only reflects it.
    onHotChanged: if (hot) Quickshell.execDetached(["notify-send", "-a", "Island", "-i", "dialog-warning", qsTr("CPU temperature is high"), qsTr("%1°C for consecutive samples. Consider Balanced or Power saver.").arg(Math.round(temperature))])
    function sample(): void { if (!sensor.running) sensor.running = true; }
    Process {
        id: sensor
        command: ["python3", Paths.toLocalFile(Qt.resolvedUrl("../modules/dashboard/helpers/temperature.py"))]
        stdout: StdioCollector {
            onStreamFinished: {
                let value = null;
                try { value = JSON.parse(text).temperature; } catch (error) {}
                root.temperature = typeof value === "number" ? value : -1;
                const result = Logic.temperatureState(value, root.hotSamples, root.hot);
                root.hotSamples = result.samples;
                root.hot = result.active;
            }
        }
    }
    Timer { interval: 30000; repeat: true; running: GlobalConfig.dashboard.enabled; triggeredOnStart: true; onTriggered: root.sample() }
}
