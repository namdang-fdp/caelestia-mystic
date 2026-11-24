import QtQuick
import QtQuick.Layouts
import qs.services
import "../dashboard/helpers/ResourceLogic.js" as Logic

// Claude Code processes (joined with hook sessions) and Codex sessions. Orphans (working
// directory deleted) come first and can be stopped; the Codex RAM total is last.
Card {
    id: root

    readonly property int maxRows: 12
    readonly property var all: Logic.agentRows(Resources.claude, AgentState.live, Resources.groups).sort((a, b) => (a.aggregate - b.aggregate) || (b.orphan - a.orphan) || (b.ram_kb - a.ram_kb))
    readonly property var rows: all.slice(0, maxRows)
    readonly property var orphans: Logic.orphanTargets(Resources.claude)

    function dot(row): color {
        if (row.orphan)
            return ResourcesTheme.hot;
        if (row.state === "working")
            return ResourcesTheme.ok;
        if (row.state === "waiting")
            return ResourcesTheme.warm;
        return ResourcesTheme.textTertiary;
    }
    function detail(row): string {
        if (row.aggregate)
            return "all processes";
        if (row.orphan)
            return "orphan " + Logic.formatAge(row.age_s);
        return (row.state || "idle") + (row.age_s > 0 ? " " + Logic.formatAge(row.age_s) : "");
    }

    title: "Agents"

    RowLayout {
        visible: root.orphans.length > 0
        Layout.fillWidth: true
        Text {
            Layout.fillWidth: true
            text: root.orphans.length + (root.orphans.length === 1 ? " orphaned session" : " orphaned sessions") + " — working folder deleted"
            elide: Text.ElideRight
            color: ResourcesTheme.hot
            font.family: ResourcesTheme.uiFont
            font.pixelSize: 12
        }
        StopButton {
            key: "orphans"
            label: "Stop all"
            onConfirmed: ResourcesActions.stopAll(root.orphans)
        }
    }

    Text {
        visible: root.all.length === 0
        text: "No agent sessions"
        color: ResourcesTheme.textDim
        font.family: ResourcesTheme.uiFont
        font.pixelSize: 13
    }

    Repeater {
        model: root.rows

        RowLayout {
            id: row

            required property var modelData

            Layout.fillWidth: true
            spacing: 8

            Rectangle {
                implicitWidth: 7
                implicitHeight: 7
                radius: 4
                color: root.dot(row.modelData)
                visible: !row.modelData.aggregate
            }
            Text {
                Layout.fillWidth: true
                text: row.modelData.label
                elide: Text.ElideRight
                color: row.modelData.orphan ? ResourcesTheme.hot : ResourcesTheme.text
                font.family: ResourcesTheme.uiFont
                font.pixelSize: 13
            }
            Text {
                text: root.detail(row.modelData)
                color: ResourcesTheme.textDim
                font.family: ResourcesTheme.uiFont
                font.pixelSize: 12
                font.features: ({"tnum": 1})
            }
            Text {
                visible: row.modelData.ram_kb > 0
                text: Logic.formatKb(row.modelData.ram_kb)
                color: ResourcesTheme.text
                font.family: ResourcesTheme.numFont
                font.pixelSize: 12
                font.features: ({"tnum": 1})
                Layout.preferredWidth: 58
                horizontalAlignment: Text.AlignRight
            }
            StopButton {
                visible: row.modelData.orphan && row.modelData.pid > 0
                key: "pid:" + row.modelData.pid + ":" + row.modelData.start
                onConfirmed: ResourcesActions.stop(row.modelData.pid, row.modelData.start)
            }
        }
    }

    Text {
        visible: root.all.length > root.maxRows
        text: "+" + (root.all.length - root.maxRows) + " more"
        color: ResourcesTheme.textDim
        font.family: ResourcesTheme.uiFont
        font.pixelSize: 12
    }
}
