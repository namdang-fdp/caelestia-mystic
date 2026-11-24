pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import qs.components
import qs.services
import "helpers/DevLogic.js" as Logic

// Developer corner: open pull requests and CI, listening ports and containers,
// time per project with a standup draft.
ColumnLayout {
    id: root
    objectName: "islandDevView"
    property string section: "prs"
    property int confirmPid
    property string confirmContainer
    spacing: 10

    readonly property var sections: [
        { id: "prs", label: qsTr("Pull requests") },
        { id: "ports", label: qsTr("Ports") },
        { id: "time", label: qsTr("Time") }
    ]

    Component.onCompleted: { DevData.refreshPulls(); DevData.refreshReport(); }
    onSectionChanged: { if (section === "ports" && visible) DevData.refreshPorts(); confirmPid = 0; confirmContainer = ""; }
    // Ports poll only while their section is on screen.
    readonly property bool portsShowing: visible && section === "ports"
    onPortsShowingChanged: DevData.portViewers += portsShowing ? 1 : -1
    Component.onDestruction: if (portsShowing) DevData.portViewers--
    Timer { id: confirmReset; interval: 3000; onTriggered: { root.confirmPid = 0; root.confirmContainer = ""; } }

    RowLayout {
        Layout.fillWidth: true
        spacing: 6
        Repeater {
            model: root.sections
            IslandButton {
                required property var modelData
                text: modelData.label
                checked: modelData.id === root.section
                implicitHeight: 28; leftPadding: 12; rightPadding: 12
                onClicked: root.section = modelData.id
            }
        }
        Item { Layout.fillWidth: true }
        IslandButton {
            iconName: "refresh"; implicitHeight: 28; implicitWidth: 32; leftPadding: 5; rightPadding: 5
            Accessible.name: qsTr("Refresh")
            onClicked: { DevData.refreshPulls(); DevData.refreshPorts(); DevData.refreshReport(); }
        }
    }

    StackLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        currentIndex: root.sections.findIndex(s => s.id === root.section)

        // Pull requests
        ListView {
            id: prList
            clip: true
            spacing: 6
            model: DevData.pulls.prs
            ScrollBar.vertical: ScrollBar {}
            delegate: Rectangle {
                id: prRow
                required property var modelData
                width: prList.width
                height: 54
                radius: 16
                color: tap.hovered ? IslandTheme.palette.cardHover : IslandTheme.palette.card
                HoverHandler { id: tap; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: Quickshell.execDetached(["xdg-open", prRow.modelData.url]) }
                RowLayout {
                    anchors.fill: parent; anchors.leftMargin: 14; anchors.rightMargin: 14; spacing: 12
                    Rectangle {
                        implicitWidth: 10; implicitHeight: 10; radius: 5
                        color: ({ passing: IslandTheme.palette.green, failing: IslandTheme.palette.red, pending: IslandTheme.palette.orange })[prRow.modelData.ci] ?? IslandTheme.palette.handle
                        Accessible.name: qsTr("CI %1").arg(prRow.modelData.ci)
                    }
                    ColumnLayout {
                        Layout.fillWidth: true; spacing: 1
                        IslandText { Layout.fillWidth: true; text: prRow.modelData.title; font.pixelSize: 13; font.weight: Font.DemiBold; elide: Text.ElideRight }
                        IslandText { Layout.fillWidth: true; text: `${prRow.modelData.name} #${prRow.modelData.number}` + (prRow.modelData.failing.length ? ` · ${prRow.modelData.failing[0]} failed` : ""); font.pixelSize: 11; color: prRow.modelData.failing.length ? IslandTheme.palette.red : IslandTheme.palette.m3onSurfaceVariant; elide: Text.ElideRight }
                    }
                    IslandText {
                        visible: text !== ""
                        text: prRow.modelData.draft ? qsTr("Draft") : ({ APPROVED: qsTr("Approved"), CHANGES_REQUESTED: qsTr("Changes"), REVIEW_REQUIRED: qsTr("Review") })[prRow.modelData.review] ?? ""
                        font.pixelSize: 11; color: prRow.modelData.review === "APPROVED" ? IslandTheme.palette.green : prRow.modelData.review === "CHANGES_REQUESTED" ? IslandTheme.palette.orange : IslandTheme.palette.m3onSurfaceVariant
                    }
                }
            }
            IslandText { anchors.centerIn: parent; visible: !prList.count; text: DevData.pulls.error ? qsTr("GitHub is not reachable") : qsTr("No open pull requests"); font.pixelSize: 13; color: IslandTheme.palette.m3onSurfaceVariant }
        }

        // Ports and containers
        Flickable {
            id: portScroll
            clip: true
            contentHeight: portColumn.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar {}
            ColumnLayout {
                id: portColumn
                width: portScroll.width
                spacing: 6
                Repeater {
                    model: DevData.ports
                    Rectangle {
                        id: portRow
                        required property var modelData
                        Layout.fillWidth: true
                        implicitHeight: 48
                        radius: 16
                        color: IslandTheme.palette.card
                        RowLayout {
                            anchors.fill: parent; anchors.leftMargin: 14; anchors.rightMargin: 8; spacing: 10
                            IslandText { Layout.preferredWidth: 62; text: `:${portRow.modelData.port}`; font.pixelSize: 16; font.weight: Font.DemiBold; font.features: { "tnum": 1 } }
                            ColumnLayout {
                                Layout.fillWidth: true; spacing: 0
                                IslandText { Layout.fillWidth: true; text: portRow.modelData.name || qsTr("Another user or system"); font.pixelSize: 12; elide: Text.ElideRight }
                                IslandText { Layout.fillWidth: true; visible: text !== ""; text: portRow.modelData.project || portRow.modelData.cmd; font.pixelSize: 10; color: IslandTheme.palette.m3outline; elide: Text.ElideRight }
                            }
                            Rectangle {
                                implicitWidth: scopeLabel.implicitWidth + 12; implicitHeight: 18; radius: 9
                                color: portRow.modelData.scope === "all" ? Qt.alpha(IslandTheme.palette.orange, .2) : IslandTheme.palette.chip
                                IslandText { id: scopeLabel; anchors.centerIn: parent; text: portRow.modelData.scope === "all" ? qsTr("open to network") : qsTr("local"); font.pixelSize: 10; color: portRow.modelData.scope === "all" ? IslandTheme.palette.orange : IslandTheme.palette.m3onSurfaceVariant }
                            }
                            IslandButton {
                                visible: portRow.modelData.pid > 0
                                text: root.confirmPid === portRow.modelData.pid ? qsTr("Stop?") : ""
                                iconName: "stop_circle"
                                checked: root.confirmPid === portRow.modelData.pid
                                implicitHeight: 28; leftPadding: 7; rightPadding: 7
                                Accessible.name: qsTr("Stop the process on port %1").arg(portRow.modelData.port)
                                onClicked: {
                                    if (root.confirmPid === portRow.modelData.pid) { root.confirmPid = 0; DevData.killPort(portRow.modelData.pid); }
                                    else { root.confirmPid = portRow.modelData.pid; confirmReset.restart(); }
                                }
                            }
                        }
                    }
                }
                IslandText { visible: DevData.containers.length > 0; Layout.topMargin: 6; text: qsTr("Docker"); font.pixelSize: 11; font.weight: Font.DemiBold; color: IslandTheme.palette.m3onSurfaceVariant }
                Repeater {
                    model: DevData.containers
                    Rectangle {
                        id: boxRow
                        required property var modelData
                        Layout.fillWidth: true
                        implicitHeight: 48
                        radius: 16
                        color: IslandTheme.palette.card
                        RowLayout {
                            anchors.fill: parent; anchors.leftMargin: 14; anchors.rightMargin: 8; spacing: 10
                            MaterialIcon { text: "deployed_code"; color: IslandTheme.palette.blue; fontStyle: Tokens.font.icon.small }
                            ColumnLayout {
                                Layout.fillWidth: true; spacing: 0
                                IslandText { Layout.fillWidth: true; text: boxRow.modelData.name; font.pixelSize: 12; font.weight: Font.DemiBold; elide: Text.ElideRight }
                                IslandText { Layout.fillWidth: true; text: `${boxRow.modelData.image} · ${boxRow.modelData.status}`; font.pixelSize: 10; color: IslandTheme.palette.m3outline; elide: Text.ElideRight }
                            }
                            IslandButton {
                                text: root.confirmContainer === boxRow.modelData.name ? qsTr("Stop?") : ""
                                iconName: "stop_circle"
                                checked: root.confirmContainer === boxRow.modelData.name
                                implicitHeight: 28; leftPadding: 7; rightPadding: 7
                                Accessible.name: qsTr("Stop container %1").arg(boxRow.modelData.name)
                                onClicked: {
                                    if (root.confirmContainer === boxRow.modelData.name) { root.confirmContainer = ""; DevData.stopContainer(boxRow.modelData.name); }
                                    else { root.confirmContainer = boxRow.modelData.name; confirmReset.restart(); }
                                }
                            }
                        }
                    }
                }
                IslandText { visible: !DevData.ports.length && !DevData.containers.length; Layout.alignment: Qt.AlignHCenter; Layout.topMargin: 40; text: DevData.portError || qsTr("Nothing is listening"); font.pixelSize: 13; color: IslandTheme.palette.m3onSurfaceVariant }
            }
        }

        // Time per project and the standup draft
        ColumnLayout {
            id: timeColumn
            spacing: 8
            readonly property real todayTotal: DevData.time.reduce((n, r) => n + r.today, 0)
            readonly property real weekTotal: DevData.time.reduce((n, r) => n + r.week, 0)
            readonly property bool byWeek: todayTotal === 0
            readonly property real peak: Math.max(1, ...DevData.time.slice(0, 5).map(r => (byWeek ? r.week : r.today) || 0))
            RowLayout {
                Layout.fillWidth: true
                spacing: 18
                ColumnLayout {
                    spacing: 0
                    IslandText { text: Logic.duration(timeColumn.todayTotal); font.pixelSize: 26; font.weight: Font.DemiBold; font.features: { "tnum": 1 } }
                    IslandText { text: qsTr("with agents today"); font.pixelSize: 11; color: IslandTheme.palette.m3onSurfaceVariant }
                }
                ColumnLayout {
                    spacing: 0
                    IslandText { text: Logic.duration(timeColumn.weekTotal); font.pixelSize: 26; font.weight: Font.DemiBold; font.features: { "tnum": 1 }; color: IslandTheme.palette.m3onSurfaceVariant }
                    IslandText { text: qsTr("this week"); font.pixelSize: 11; color: IslandTheme.palette.m3onSurfaceVariant }
                }
                Item { Layout.fillWidth: true }
                IslandButton { objectName: "islandStandup"; text: qsTr("Draft standup"); iconName: "edit_note"; accent: true; accentColour: IslandTheme.palette.blue; implicitHeight: 32; onClicked: DevData.draftStandup() }
            }
            Repeater {
                model: DevData.time.slice(0, 5)
                RowLayout {
                    id: timeRow
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: 10
                    IslandText { Layout.preferredWidth: 130; text: timeRow.modelData.name; font.pixelSize: 12; elide: Text.ElideRight }
                    Rectangle {
                        Layout.fillWidth: true; implicitHeight: 6; radius: 3; color: IslandTheme.palette.track
                        Rectangle { width: parent.width * Math.min(1, (timeColumn.byWeek ? timeRow.modelData.week : timeRow.modelData.today) / timeColumn.peak); height: parent.height; radius: 3; color: IslandTheme.palette.teal }
                    }
                    IslandText { Layout.preferredWidth: 56; horizontalAlignment: Text.AlignRight; text: Logic.duration(timeColumn.byWeek ? timeRow.modelData.week : timeRow.modelData.today); font.pixelSize: 11; font.features: { "tnum": 1 }; color: IslandTheme.palette.m3onSurfaceVariant }
                }
            }
            IslandText { visible: !DevData.time.length; Layout.alignment: Qt.AlignHCenter; Layout.topMargin: 30; text: qsTr("No agent activity yet"); font.pixelSize: 13; color: IslandTheme.palette.m3onSurfaceVariant }
            Item { Layout.fillHeight: true }
        }
    }
}
