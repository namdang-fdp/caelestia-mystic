import QtQuick
import "../dashboard/helpers/ResourceLogic.js" as Logic

// Filled line chart of values over a fixed ceiling.
Canvas {
    id: root

    property var values: []
    property color tint: "#30D158"
    property real ceiling: 100

    implicitHeight: 36

    onValuesChanged: requestPaint()
    onTintChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        const inset = 2;
        const raw = Logic.sparkPoints(root.values, width, height - inset * 2, root.ceiling);
        if (raw.length < 2)
            return;
        const pts = raw.map(p => ({ x: p.x, y: p.y + inset }));
        const last = pts[pts.length - 1];
        const fill = ctx.createLinearGradient(0, 0, 0, height);
        fill.addColorStop(0, Qt.rgba(tint.r, tint.g, tint.b, 0.35));
        fill.addColorStop(1, Qt.rgba(tint.r, tint.g, tint.b, 0));
        ctx.beginPath();
        ctx.moveTo(pts[0].x, height);
        for (const p of pts)
            ctx.lineTo(p.x, p.y);
        ctx.lineTo(last.x, height);
        ctx.closePath();
        ctx.fillStyle = fill;
        ctx.fill();
        ctx.beginPath();
        ctx.moveTo(pts[0].x, pts[0].y);
        for (const p of pts)
            ctx.lineTo(p.x, p.y);
        ctx.strokeStyle = tint;
        ctx.lineWidth = 1.5;
        ctx.lineJoin = "round";
        ctx.stroke();
    }
}
