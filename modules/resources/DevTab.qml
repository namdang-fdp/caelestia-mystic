import QtQuick
import QtQuick.Layouts
import qs.services

// The island's developer data in the drawer: listening ports, Docker containers and your pull
// requests. Read-only on DevData apart from its own stop actions; ports poll only while this
// tab exists.
ColumnLayout {
    id: root

    function ciTint(ci: string): color {
        return ci === "passing" ? ResourcesTheme.ok : ci === "failing" ? ResourcesTheme.hot : ci === "pending" ? ResourcesTheme.warm : ResourcesTheme.textTertiary;
    }
    function reviewText(pr): string {
        if (pr.draft)
            return "Draft";
        return ({
                "APPROVED": "Approved",
                "CHANGES_REQUESTED": "Changes",
                "REVIEW_REQUIRED": "Review"
            })[pr.review] ?? "";
    }

    spacing: 10

    Component.onCompleted: {
        DevData.portViewers++;
        DevData.refreshPorts();
    }
    Component.onDestruction: DevData.portViewers--

    Card {
        Layout.fillWidth: true
        title: "Ports"
        trailing: DevData.ports.length > 0 ? String(DevData.ports.length) : ""

        Text {
            visible: DevData.ports.length === 0
            text: DevData.portError !== "" ? DevData.portError : "No dev servers listening"
            color: ResourcesTheme.textDim
            font.family: ResourcesTheme.uiFont
            font.pixelSize: 13
        }

        Repeater {
            model: DevData.ports

            RowLayout {
                id: port

                required property var modelData

                Layout.fillWidth: true
                spacing: 10

                Text {
                    text: ":" + port.modelData.port
                    color: ResourcesTheme.text
                    font.family: ResourcesTheme.numFont
                    font.pixelSize: 15
                    font.weight: Font.DemiBold
                    font.features: ({"tnum": 1})
                    Layout.preferredWidth: 58
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    Text {
                        Layout.fillWidth: true
                        text: port.modelData.name || "Another user or system"
                        elide: Text.ElideRight
                        color: ResourcesTheme.text
                        font.family: ResourcesTheme.uiFont
                        font.pixelSize: 12
                    }
                    Text {
                        Layout.fillWidth: true
                        visible: text !== ""
                        text: port.modelData.project || port.modelData.cmd || ""
                        elide: Text.ElideRight
                        color: ResourcesTheme.textTertiary
                        font.family: ResourcesTheme.uiFont
                        font.pixelSize: 10
                    }
                }
                Text {
                    text: port.modelData.scope === "all" ? "open to network" : "local"
                    color: port.modelData.scope === "all" ? ResourcesTheme.warm : ResourcesTheme.textDim
                    font.family: ResourcesTheme.uiFont
                    font.pixelSize: 10
                }
                Item {
                    implicitWidth: 38
                    implicitHeight: 22
                    opacity: portHover.hovered || portStop.armed ? 1 : 0
                    visible: port.modelData.pid > 0
                    Behavior on opacity {
                        NumberAnimation {
                            duration: 120
                        }
                    }
                    StopButton {
                        id: portStop
                        anchors.right: parent.right
                        key: "port:" + port.modelData.pid
                        onConfirmed: DevData.killPort(port.modelData.pid)
                    }
                }
                HoverHandler {
                    id: portHover
                }
            }
        }
    }

    Card {
        visible: DevData.containers.length > 0
        Layout.fillWidth: true
        title: "Docker"
        trailing: String(DevData.containers.length)

        Repeater {
            model: DevData.containers

            RowLayout {
                id: box

                required property var modelData

                Layout.fillWidth: true
                spacing: 10

                IconTile {
                    icon: "deployed_code"
                    tint: ResourcesTheme.blue
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    Text {
                        Layout.fillWidth: true
                        text: box.modelData.name
                        elide: Text.ElideRight
                        color: ResourcesTheme.text
                        font.family: ResourcesTheme.uiFont
                        font.pixelSize: 12
                        font.weight: Font.Medium
                    }
                    Text {
                        Layout.fillWidth: true
                        text: box.modelData.image + " · " + box.modelData.status
                        elide: Text.ElideRight
                        color: ResourcesTheme.textTertiary
                        font.family: ResourcesTheme.uiFont
                        font.pixelSize: 10
                    }
                }
                Item {
                    implicitWidth: 38
                    implicitHeight: 22
                    opacity: boxHover.hovered || boxStop.armed ? 1 : 0
                    Behavior on opacity {
                        NumberAnimation {
                            duration: 120
                        }
                    }
                    StopButton {
                        id: boxStop
                        anchors.right: parent.right
                        key: "box:" + box.modelData.name
                        onConfirmed: DevData.stopContainer(box.modelData.name)
                    }
                }
                HoverHandler {
                    id: boxHover
                }
            }
        }
    }

    Card {
        Layout.fillWidth: true
        title: "Pull requests"
        trailing: DevData.pulls.prs.length > 0 ? String(DevData.pulls.prs.length) : ""

        Text {
            visible: DevData.pulls.prs.length === 0
            text: DevData.pulls.error ? "GitHub is not reachable" : "No open pull requests"
            color: ResourcesTheme.textDim
            font.family: ResourcesTheme.uiFont
            font.pixelSize: 13
        }

        Repeater {
            model: DevData.pulls.prs

            Rectangle {
                id: pr

                required property var modelData

                Layout.fillWidth: true
                implicitHeight: prRow.implicitHeight + 8
                radius: ResourcesTheme.radiusControl
                color: prArea.containsMouse ? ResourcesTheme.hover : "transparent"

                RowLayout {
                    id: prRow
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: 4
                    anchors.rightMargin: 4
                    spacing: 8

                    Rectangle {
                        implicitWidth: 8
                        implicitHeight: 8
                        radius: 4
                        color: root.ciTint(pr.modelData.ci)
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        Text {
                            Layout.fillWidth: true
                            text: pr.modelData.title
                            elide: Text.ElideRight
                            color: ResourcesTheme.text
                            font.family: ResourcesTheme.uiFont
                            font.pixelSize: 12
                            font.weight: Font.Medium
                        }
                        Text {
                            Layout.fillWidth: true
                            text: pr.modelData.name + " #" + pr.modelData.number + (pr.modelData.failing.length ? " · " + pr.modelData.failing[0] + " failed" : "")
                            elide: Text.ElideRight
                            color: pr.modelData.failing.length ? ResourcesTheme.hot : ResourcesTheme.textTertiary
                            font.family: ResourcesTheme.uiFont
                            font.pixelSize: 10
                        }
                    }
                    Text {
                        text: root.reviewText(pr.modelData)
                        color: ResourcesTheme.textDim
                        font.family: ResourcesTheme.uiFont
                        font.pixelSize: 11
                    }
                }
                MouseArea {
                    id: prArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: if (pr.modelData.url)
                        Qt.openUrlExternally(pr.modelData.url)
                }
            }
        }
    }
}
