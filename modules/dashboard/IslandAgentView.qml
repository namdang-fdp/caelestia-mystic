pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.services
import "helpers/AgentLogic.js" as Logic

// Claude Code and Codex at a glance: quota used, local token counts, a 7-day
// chart and a small mascot whose mood follows the agents. Nothing here
// animates continuously.
ColumnLayout {
    id: root
    objectName: "islandAgentView"
    property real maximumHeight: 520
    property string tab: "all"
    property bool renaming

    readonly property var providers: [
        { key: "claude", name: "Claude Code", icon: "asterisk", usage: AiUsage.provider("claude"), stats: AgentState.provider("claude") },
        { key: "codex", name: "Codex", icon: "code", usage: AiUsage.provider("codex"), stats: AgentState.provider("codex") }
    ].filter(p => p.stats?.available || (p.usage && !p.usage.missing && p.usage.session))
    readonly property var tabs: ["all", ...providers.map(p => p.key)]
    readonly property string activeTab: tabs.includes(tab) ? tab : "all"
    readonly property var current: providers.find(p => p.key === activeTab) ?? null
    readonly property real nowSeconds: AgentState.now / 1000
    readonly property real peak: Logic.peakPercent([].concat(...providers.map(p => [p.usage?.session?.usedPercent, p.usage?.weekly?.usedPercent])))
    readonly property string mood: Logic.petMood(AgentState.foreground, peak)
    readonly property var weekSource: current ? [current.stats?.week] : providers.map(p => p.stats?.week)
    readonly property var week: Logic.sumWeeks(weekSource)
    readonly property real weekPeak: Math.max(1, ...week.map(d => d.tokens))
    readonly property real todayTokens: (current ? [current] : providers).reduce((n, p) => n + (p.stats?.today?.tokens ?? 0), 0)
    readonly property real todayCalls: (current ? [current] : providers).reduce((n, p) => n + (p.stats?.today?.calls ?? 0), 0)
    spacing: 14

    function sessionsOf(key: string): var { return AgentState.live.filter(s => s.state !== "done" && (!key || s.agent === key)); }
    function stateOf(key: string): string {
        const list = sessionsOf(key);
        return list.some(s => s.state === "waiting") ? "waiting" : list.length ? "working" : "";
    }
    function colourFor(percent: real): color {
        const level = Logic.severity(percent);
        return level === "high" ? IslandTheme.palette.m3error : level === "warn" ? IslandTheme.palette.warning : IslandTheme.palette.success;
    }
    function clock(seconds: real): string { return seconds ? Qt.formatTime(new Date(seconds * 1000), "HH:mm") : "--:--"; }
    function leftText(seconds: real): string { return seconds ? qsTr("%1 left").arg(Logic.elapsed(seconds - nowSeconds)) : ""; }

    Component.onCompleted: { AgentState.viewers++; AiUsage.refresh(false); }
    Component.onDestruction: AgentState.viewers--

    // Tabs
    RowLayout {
        Layout.fillWidth: true
        spacing: 8
        Repeater {
            model: root.tabs
            Rectangle {
                id: chip
                required property string modelData
                readonly property bool selected: modelData === root.activeTab
                readonly property var info: root.providers.find(p => p.key === modelData)
                readonly property string state: root.stateOf(modelData === "all" ? "" : modelData)
                implicitWidth: label.implicitWidth + 32 + (state ? 14 : 0)
                implicitHeight: 34
                radius: 17
                color: selected ? "#ffffff" : tap.containsMouse ? IslandTheme.palette.m3surfaceContainerHighest : IslandTheme.palette.chip
                Accessible.role: Accessible.PageTab
                Accessible.name: label.text
                Accessible.selected: selected
                Accessible.onPressAction: root.tab = modelData
                RowLayout {
                    id: label
                    property alias text: name.text
                    anchors.centerIn: parent
                    spacing: 7
                    MaterialIcon { text: chip.modelData === "all" ? "grid_view" : chip.info?.icon ?? ""; color: chip.selected ? "#000000" : IslandTheme.palette.m3onSurfaceVariant; fontStyle: Tokens.font.icon.small }
                    IslandText { id: name; text: chip.modelData === "all" ? qsTr("All") : chip.info?.name ?? ""; font.pixelSize: 13; font.weight: Font.DemiBold; color: chip.selected ? "#000000" : IslandTheme.palette.m3onSurfaceVariant }
                    Rectangle { visible: !!chip.state; width: 7; height: 7; radius: 3.5; color: chip.state === "waiting" ? IslandTheme.palette.warning : IslandTheme.palette.success }
                }
                MouseArea { id: tap; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.tab = chip.modelData }
            }
        }
        Item { Layout.fillWidth: true }
        IslandButton {
            iconName: "refresh"; implicitHeight: 30; implicitWidth: 34; leftPadding: 6; rightPadding: 6
            Accessible.name: qsTr("Refresh usage")
            onClicked: { AgentState.refreshStats(); AiUsage.refresh(true); }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 18

        // Mascot
        ColumnLayout {
            Layout.preferredWidth: 112
            Layout.alignment: Qt.AlignTop
            spacing: 6
            IslandAgentPet { Layout.alignment: Qt.AlignHCenter; mood: root.mood; kind: IslandTools.petKind }
            IslandText { visible: !root.renaming; Layout.alignment: Qt.AlignHCenter; text: IslandTools.petName; font.pixelSize: 15; font.weight: Font.DemiBold
                TapHandler { onTapped: { root.renaming = true; nameField.text = IslandTools.petName; nameField.forceActiveFocus(); nameField.selectAll(); } }
                HoverHandler { cursorShape: Qt.PointingHandCursor }
            }
            IslandTextField {
                id: nameField
                visible: root.renaming
                Layout.alignment: Qt.AlignHCenter; Layout.preferredWidth: 104; implicitHeight: 28
                maximumLength: 16; horizontalAlignment: TextInput.AlignHCenter; leftPadding: 6; rightPadding: 6
                Accessible.name: qsTr("Pet name")
                onAccepted: { IslandTools.setPetName(text); root.renaming = false; }
                Keys.onEscapePressed: root.renaming = false
                onActiveFocusChanged: if (!activeFocus && root.renaming) { IslandTools.setPetName(text); root.renaming = false; }
            }
            Row {
                visible: root.renaming
                Layout.alignment: Qt.AlignHCenter
                spacing: 6
                Repeater {
                    model: ["#f08a33", "#5ea5ff", "#ff8fb3", "#6fd08c"]
                    Rectangle {
                        required property string modelData
                        required property int index
                        width: 16; height: 16; radius: 8; color: modelData
                        border.width: IslandTools.petKind === index ? 2 : 0; border.color: "#ffffff"
                        MouseArea { anchors.fill: parent; onPressed: IslandTools.setPetKind(parent.index) }
                    }
                }
            }
            IslandText { Layout.alignment: Qt.AlignHCenter; text: Logic.moodLabel(root.mood); font.pixelSize: 11; color: root.mood === "waiting" ? IslandTheme.palette.warning : IslandTheme.palette.m3onSurfaceVariant }
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 6
                MaterialIcon { text: "favorite"; color: root.colourFor(root.peak); fontStyle: Tokens.font.icon.small }
                Rectangle {
                    Layout.preferredWidth: 56; Layout.preferredHeight: 5; radius: 2.5; color: IslandTheme.palette.track
                    Rectangle { width: parent.width * Logic.health(root.peak) / 100; height: parent.height; radius: 2.5; color: root.colourFor(root.peak) }
                }
                IslandText { text: Logic.health(root.peak); font.pixelSize: 11; font.features: { "tnum": 1 }; color: IslandTheme.palette.m3onSurfaceVariant }
            }
        }
        Rectangle { Layout.fillHeight: true; implicitWidth: 1; color: IslandTheme.palette.divider }

        // Details
        Loader {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop
            sourceComponent: !root.providers.length ? emptyView : root.current ? detailView : overviewView
        }
    }

    component Bar: Rectangle {
        property real fraction
        property color fill: IslandTheme.palette.success
        property real thickness: 6
        Layout.fillWidth: true
        implicitHeight: thickness
        radius: thickness / 2
        color: IslandTheme.palette.track
        Rectangle { width: parent.width * Math.max(0, Math.min(1, parent.fraction)); height: parent.height; radius: parent.radius; color: parent.fill }
    }

    Component {
        id: emptyView
        ColumnLayout {
            spacing: 6
            IslandText { Layout.fillWidth: true; text: qsTr("No agent activity yet"); font.pixelSize: 15; font.weight: Font.DemiBold }
            IslandText { Layout.fillWidth: true; text: qsTr("Start Claude Code or Codex. Usage and live status show up here."); font.pixelSize: 12; color: IslandTheme.palette.m3onSurfaceVariant; wrapMode: Text.WordWrap }
        }
    }

    // One agent in detail.
    Component {
        id: detailView
        ColumnLayout {
            id: detail
            readonly property var p: root.current
            readonly property var session: p?.usage?.session ?? null
            readonly property var weekly: p?.usage?.weekly ?? null
            readonly property bool known: !!session
            readonly property real used: Logic.clampPercent(session?.usedPercent)
            readonly property real weeklyUsed: Logic.clampPercent(weekly?.usedPercent)
            spacing: 6
            RowLayout {
                Layout.fillWidth: true
                IslandText { text: qsTr("5-HOUR SESSION"); font.pixelSize: 11; font.weight: Font.DemiBold; color: IslandTheme.palette.m3onSurfaceVariant }
                Item { Layout.fillWidth: true }
                IslandAgentMark { visible: !!root.stateOf(detail.p.key); state: root.stateOf(detail.p.key) || "working"; size: 14 }
                IslandText { visible: !!root.stateOf(detail.p.key); text: root.stateOf(detail.p.key) === "waiting" ? qsTr("Needs you") : qsTr("Working"); font.pixelSize: 11; color: root.stateOf(detail.p.key) === "waiting" ? IslandTheme.palette.warning : IslandTheme.palette.m3onSurfaceVariant }
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                IslandText { text: detail.known ? `${detail.used}%` : "—"; font.pixelSize: 40; font.weight: Font.DemiBold; font.features: { "tnum": 1 }; color: detail.known ? root.colourFor(detail.used) : IslandTheme.palette.m3outline }
                IslandText { Layout.alignment: Qt.AlignBottom; Layout.bottomMargin: 6; text: qsTr("used"); font.pixelSize: 13; color: IslandTheme.palette.m3onSurfaceVariant }
                Item { Layout.fillWidth: true }
                IslandText { visible: detail.known; Layout.alignment: Qt.AlignBottom; Layout.bottomMargin: 4; text: `${100 - detail.used}%`; font.pixelSize: 24; font.weight: Font.DemiBold; font.features: { "tnum": 1 } }
                IslandText { visible: detail.known; Layout.alignment: Qt.AlignBottom; Layout.bottomMargin: 6; text: qsTr("left"); font.pixelSize: 12; color: IslandTheme.palette.m3onSurfaceVariant }
            }
            Bar { fraction: detail.used / 100; fill: root.colourFor(detail.used); thickness: 6 }
            RowLayout {
                visible: detail.known
                spacing: 6
                MaterialIcon { text: "schedule"; color: IslandTheme.palette.m3onSurfaceVariant; fontStyle: Tokens.font.icon.small }
                IslandText { text: qsTr("Reset %1 · %2").arg(root.clock(detail.session?.resetsAt)).arg(root.leftText(detail.session?.resetsAt)); font.pixelSize: 12; font.weight: Font.Medium; color: IslandTheme.palette.m3onSurfaceVariant }
            }
            IslandText { visible: !detail.known; text: qsTr("Quota unavailable. Showing local counts only."); font.pixelSize: 12; color: IslandTheme.palette.m3onSurfaceVariant }
            RowLayout {
                visible: !!detail.weekly
                Layout.topMargin: 6
                IslandText { text: qsTr("Weekly · 7d"); font.pixelSize: 12; font.weight: Font.DemiBold; color: IslandTheme.palette.m3onSurfaceVariant }
                Item { Layout.fillWidth: true }
                IslandText { text: `${detail.weeklyUsed}% · ${qsTr("%1% left").arg(100 - detail.weeklyUsed)}`; font.pixelSize: 12; font.weight: Font.DemiBold; color: root.colourFor(detail.weeklyUsed) }
                IslandText { text: `↻ ${Qt.formatDateTime(new Date((detail.weekly?.resetsAt ?? 0) * 1000), "ddd HH:mm")}`; font.pixelSize: 11; color: IslandTheme.palette.m3onSurfaceVariant }
            }
            Bar { visible: !!detail.weekly; fraction: detail.weeklyUsed / 100; fill: root.colourFor(detail.weeklyUsed); thickness: 4 }
            Loader { Layout.fillWidth: true; Layout.topMargin: 8; sourceComponent: tokensRow }
        }
    }

    // Both agents side by side in one list, plus what is running now.
    Component {
        id: overviewView
        ColumnLayout {
            spacing: 10
            Repeater {
                model: root.providers
                ColumnLayout {
                    id: row
                    required property var modelData
                    readonly property var session: modelData.usage?.session ?? null
                    readonly property real used: Logic.clampPercent(session?.usedPercent)
                    Layout.fillWidth: true
                    spacing: 4
                    RowLayout {
                        Layout.fillWidth: true
                        IslandText { text: row.modelData.name; font.pixelSize: 13; font.weight: Font.DemiBold }
                        IslandAgentMark { visible: !!root.stateOf(row.modelData.key); state: root.stateOf(row.modelData.key) || "working"; size: 14 }
                        Item { Layout.fillWidth: true }
                        IslandText { text: row.session ? `${row.used}%` : "—"; font.pixelSize: 20; font.weight: Font.DemiBold; font.features: { "tnum": 1 }; color: row.session ? root.colourFor(row.used) : IslandTheme.palette.m3outline }
                    }
                    Bar { fraction: row.used / 100; fill: root.colourFor(row.used); thickness: 5 }
                    IslandText {
                        text: [row.session ? qsTr("Reset %1 · %2").arg(root.clock(row.session.resetsAt)).arg(root.leftText(row.session.resetsAt)) : "", qsTr("%1 tokens today").arg(Logic.compact(row.modelData.stats?.today?.tokens ?? 0))].filter(t => t).join("  ·  ")
                        font.pixelSize: 11; color: IslandTheme.palette.m3onSurfaceVariant
                    }
                }
            }
            Repeater {
                model: root.sessionsOf("").slice(0, 3)
                RowLayout {
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: 8
                    IslandAgentMark { state: parent.modelData.state; size: 14 }
                    IslandText { Layout.fillWidth: true; text: `${parent.modelData.project || qsTr("Session")} · ${Logic.agentName(parent.modelData.agent)}`; font.pixelSize: 12; elide: Text.ElideRight }
                    IslandText { text: Logic.elapsed(root.nowSeconds - Number(parent.modelData.started ?? parent.modelData.updated)); font.pixelSize: 11; font.features: { "tnum": 1 }; color: IslandTheme.palette.m3onSurfaceVariant }
                }
            }
            Loader { Layout.fillWidth: true; sourceComponent: tokensRow }
        }
    }

    // Tokens, calls and the 7-day bars.
    Component {
        id: tokensRow
        RowLayout {
            spacing: 14
            ColumnLayout {
                spacing: 0
                IslandText { text: Logic.compact(root.todayTokens); font.pixelSize: 24; font.weight: Font.DemiBold; font.features: { "tnum": 1 } }
                IslandText { text: qsTr("tokens today"); font.pixelSize: 11; color: IslandTheme.palette.m3onSurfaceVariant }
            }
            ColumnLayout {
                spacing: 0
                IslandText { text: String(root.todayCalls); font.pixelSize: 24; font.weight: Font.DemiBold; font.features: { "tnum": 1 } }
                IslandText { text: qsTr("calls"); font.pixelSize: 11; color: IslandTheme.palette.m3onSurfaceVariant }
            }
            Item { Layout.fillWidth: true }
            Row {
                spacing: 6
                Repeater {
                    model: root.week
                    Column {
                        id: day
                        required property var modelData
                        required property int index
                        readonly property bool today: index === root.week.length - 1
                        spacing: 4
                        Item {
                            width: 20; height: 42
                            Rectangle {
                                anchors.bottom: parent.bottom
                                width: parent.width
                                height: day.modelData.tokens > 0 ? Math.max(4, parent.height * day.modelData.tokens / root.weekPeak) : 2
                                radius: day.modelData.tokens > 0 ? 4 : 1
                                color: day.today ? IslandTheme.palette.success : IslandTheme.palette.handle
                            }
                        }
                        IslandText { anchors.horizontalCenter: parent.horizontalCenter; text: Qt.formatDate(new Date(day.modelData.date + "T12:00:00"), "ddd").slice(0, 2); font.pixelSize: 10; font.weight: day.today ? Font.DemiBold : Font.Normal; color: day.today ? IslandTheme.palette.m3onSurface : IslandTheme.palette.m3outline }
                    }
                }
            }
        }
    }
}
