pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import qs.services
import "helpers/ActivityLogic.js" as Logic

// Idle companion for the resting pill. Blinks at irregular intervals, glances
// around, dozes off while the session is idle and smiles on greet().
//
// Every frame redraws the whole fullscreen shell window, and starting a QML
// animation wakes every shell window. So motion here is stepped keyframes on a
// ~30 fps Timer instead: a blink costs four frames, a glance five, and nothing
// ever runs open-ended. Off-screen or unfocused, the eyes cost nothing.
Item {
    id: root
    property bool running
    // Blinks and glances only while live (the focused screen); otherwise the
    // eyes stay open and still.
    property bool live: true
    property bool dozing
    property real motionScale: 1
    // 1 open, 0 shut.
    property real lid: 0
    // Horizontal glance, -1 (left) .. 1 (right).
    property real look
    property real hop
    // 0..1 blend from round open eyes to smiling ^ ^ arcs.
    property real smile
    // 0..1 blend to closed, sleeping eyes.
    property real sleep
    // Pending keyframes: each is an object of property values for one tick;
    // an empty object is a pause.
    property var frames: []
    property var after: null
    implicitWidth: 64
    implicitHeight: 22

    function play(steps: var, done: var): void {
        if (motionScale <= 0) {
            // Reduced motion: jump straight to the final values.
            for (const step of steps) for (const key in step) root[key] = step[key];
            frames = [];
            if (done) done();
            return;
        }
        frames = steps;
        after = done ?? null;
        stepper.restart();
    }
    function greet(): void {
        if (!running || dozing) return;
        blinkTimer.stop();
        const pause = Array(12).fill({});
        play([{ smile: .35 }, { smile: .75 }, { smile: 1, hop: 1.2 }, { hop: 2 }, { hop: 1.2 }, { hop: 0 }, { hop: 1 }, { hop: 0 }, ...pause, { smile: .66 }, { smile: .33 }, { smile: 0 }], () => blinkTimer.schedule());
    }
    function glanceTo(target: real): void {
        const from = look;
        play([.12, .4, .72, .93, 1].map(t => ({ look: from + (target - from) * t })), null);
    }
    onRunningChanged: {
        if (running) play([{ lid: .35 }, { lid: .75 }, { lid: 1.05 }, { lid: 1 }], () => blinkTimer.schedule());
        else { stepper.stop(); blinkTimer.stop(); frames = []; lid = 0; look = 0; hop = 0; smile = 0; sleep = 0; }
    }
    onLiveChanged: if (live) blinkTimer.schedule()
    onDozingChanged: {
        if (!running) return;
        blinkTimer.stop();
        if (dozing) play([{ look: 0, smile: 0, hop: 0, sleep: .2 }, { sleep: .45 }, {}, { sleep: .7 }, {}, { sleep: .9 }, { sleep: 1 }], null);
        else play([{ sleep: .6 }, { sleep: .2 }, { sleep: 0, lid: 1 }], () => greet());
    }

    Timer {
        id: stepper
        interval: 33
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!root.frames.length) {
                stop();
                const done = root.after;
                root.after = null;
                if (done) done();
                return;
            }
            const step = root.frames[0];
            root.frames = root.frames.slice(1);
            for (const key in step) root[key] = step[key];
        }
    }
    Timer {
        id: blinkTimer
        function schedule(): void {
            if (!root.running || !root.live || root.dozing || root.motionScale <= 0) return;
            interval = Logic.blinkDelay(Math.random());
            restart();
        }
        onTriggered: {
            if (!root.running || !root.live || root.dozing) return;
            // Never cut a glance or greeting short; try again a moment later.
            if (stepper.running) { interval = 400; restart(); return; }
            const once = [{ lid: .5 }, { lid: .1 }, { lid: .5 }, { lid: 1 }];
            root.play(Logic.isDoubleBlink(Math.random()) ? [...once, {}, {}, ...once] : once, () => blinkTimer.schedule());
        }
    }
    Timer {
        interval: 6000
        repeat: true
        running: root.running && root.live && !root.dozing && root.motionScale > 0
        onTriggered: {
            interval = 5000 + Math.floor(Math.random() * 6000);
            if (stepper.running) return;
            // Mostly look straight ahead; wander gently now and then.
            root.glanceTo(root.look !== 0 && Math.random() < .7 ? 0 : Logic.nextGlance(root.look, Math.random()) * .7);
        }
    }

    Row {
        anchors.centerIn: parent
        anchors.horizontalCenterOffset: root.look * 2.5
        anchors.verticalCenterOffset: -root.hop
        spacing: 12
        Repeater {
            model: 2
            Item {
                id: eye
                required property int index
                width: 9; height: 12
                anchors.verticalCenter: parent.verticalCenter
                // Round, slightly tall eye; lids squash it from both sides.
                Rectangle {
                    id: dot
                    anchors.centerIn: parent
                    width: 9
                    height: Math.max(1.5, 11 * Math.min(1.15, root.lid))
                    radius: Math.min(width, height) / 2
                    color: IslandTheme.palette.eyes
                    opacity: (1 - root.sleep) * (1 - root.smile)
                    RectangularShadow {
                        anchors.fill: parent
                        z: -1
                        radius: parent.radius
                        blur: 9
                        color: Qt.alpha(IslandTheme.palette.eyesGlow, .38)
                    }
                }
                // Smiling ^ while greeting, a closed ‿ while dozing.
                Shape {
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer
                    opacity: Math.max(root.sleep * .7, root.smile)
                    ShapePath {
                        strokeColor: IslandTheme.palette.eyes
                        strokeWidth: 2.2
                        capStyle: ShapePath.RoundCap
                        fillColor: "transparent"
                        PathAngleArc {
                            centerX: 4.5; centerY: root.dozing ? 3 : 9
                            radiusX: 4.6; radiusY: 4.2
                            startAngle: root.dozing ? 25 : 205
                            sweepAngle: 130
                        }
                    }
                }
            }
        }
    }
    // A still "z" while dozing; dozing draws no frames at all.
    Text {
        x: parent.width / 2 + 18
        y: 1
        text: "z"
        color: IslandTheme.palette.eyes
        font.family: IslandTheme.fontFamily
        font.pixelSize: 9
        font.weight: Font.DemiBold
        opacity: root.sleep * .55
        visible: opacity > 0
    }
}
