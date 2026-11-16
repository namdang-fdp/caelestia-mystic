import QtQuick
import qs.services

// Circular progress ring, value 0..1, starting at 12 o'clock.
Canvas {
    id: root

    property real value
    property color tint: ResourcesTheme.ok
    property real thickness: 8

    implicitWidth: 76
    implicitHeight: 76

    Behavior on value {
        NumberAnimation {
            duration: 400
            easing.type: Easing.OutCubic
        }
    }

    onValueChanged: requestPaint()
    onTintChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        const cx = width / 2;
        const cy = height / 2;
        const r = Math.min(width, height) / 2 - thickness / 2;
        ctx.lineWidth = thickness;
        ctx.lineCap = "round";
        ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.10);
        ctx.beginPath();
        ctx.arc(cx, cy, r, 0, 2 * Math.PI);
        ctx.stroke();
        const v = Math.max(0, Math.min(1, value));
        if (v <= 0)
            return;
        ctx.strokeStyle = tint;
        ctx.beginPath();
        ctx.arc(cx, cy, r, -Math.PI / 2, -Math.PI / 2 + v * 2 * Math.PI);
        ctx.stroke();
    }
}
