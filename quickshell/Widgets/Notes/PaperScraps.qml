import QtQuick
import qs.Common
import qs.Services

/*  PaperScraps — what a tear-off leaves: a few torn bits of washi thrown from the slip, drifting down and fading (650 ms, soft, no bounce).
 *  burst() does nothing with reduced motion.
 */
Item {
    id: root
    property color colorA: "#fbf6e8"
    property color colorB: "#b8ab92"
    property var scraps: []
    property real t: 0

    function burst() {
        if (ConfigService.reducedMotion) return;
        const out = [];
        for (let i = 0; i < 12; i++)
            out.push({ x: Math.random() * root.width, y: Math.random() * root.height * 0.7,
                       vx: (Math.random() - 0.5) * 46, vy: -8 - Math.random() * 26, spin: (Math.random() - 0.5) * 300,
                       w: 2 + Math.random() * 4, h: 1.5 + Math.random() * 2.5, b: i % 3 === 0 });
        root.scraps = out;
        fall.restart();
    }
    NumberAnimation {
        id: fall
        target: root; property: "t"
        from: 0; to: 1; duration: 650; easing.type: Easing.Linear
        onFinished: root.scraps = []
    }
    Repeater {
        model: root.scraps
        Rectangle {
            required property var modelData
            x: modelData.x + modelData.vx * root.t
            y: modelData.y + modelData.vy * root.t + 90 * root.t * root.t
            width: modelData.w; height: modelData.h
            radius: 0.5
            rotation: modelData.spin * root.t
            color: modelData.b ? root.colorB : root.colorA
            opacity: 1 - root.t * root.t
        }
    }
}
