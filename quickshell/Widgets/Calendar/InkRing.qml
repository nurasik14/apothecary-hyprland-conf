import QtQuick
import qs.Common

/*  InkRing — a brushed ink ring around a day (the selected one): an ellipse drawn in two quick strokes that do not quite meet, the line swelling
 *  and thinning like a brush, each ring a little different (`seed`).  Drawn on a Canvas, repainted when the size, the colour or the seed change.
 */
Canvas {
    id: ring
    property int seed: 1
    property color ink: Theme.text
    property real strength: 0.8
    antialiasing: true
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onSeedChanged: requestPaint()
    onInkChanged: requestPaint()
    onVisibleChanged: if (visible) requestPaint()

    function rnd(n) {                       // a small deterministic noise in [0, 1) for stroke n of this seed
        const x = Math.sin(ring.seed * 12.9898 + n * 78.233) * 43758.5453;
        return x - Math.floor(x);
    }
    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        if (width < 8 || height < 8) return;
        const cx = width / 2, cy = height / 2;
        const rx = width / 2 - 2.5, ry = height / 2 - 2.5;
        const c = Qt.color(ring.ink);
        ctx.lineCap = "round";
        ctx.lineJoin = "round";
        for (let pass = 0; pass < 2; pass++) {
            const a0 = -Math.PI * (0.62 + 0.25 * ring.rnd(pass * 3));     // where the stroke starts
            const sweep = Math.PI * (pass === 0 ? 1.55 : 0.55) + ring.rnd(pass * 3 + 1) * 0.2;
            const wob = 0.6 + ring.rnd(pass * 3 + 2) * 0.6;
            const n = 36;
            let px = 0, py = 0;
            for (let i = 0; i <= n; i++) {
                const t = i / n;
                const a = a0 + sweep * t;
                const k = 1 + 0.035 * Math.sin(a * 2 + ring.seed) * wob + (pass === 1 ? 0.045 : 0) * t;   // the second stroke drifts a little outside
                const x = cx + rx * k * Math.cos(a), y = cy + ry * k * Math.sin(a);
                if (i > 0) {
                    const w = (pass === 0 ? 1.7 : 1.1) * Math.sin(Math.PI * Math.pow(t, 0.75)) + 0.35;   // the swell: thin at both ends
                    ctx.strokeStyle = Qt.rgba(c.r, c.g, c.b, ring.strength * (pass === 0 ? 1 : 0.7));
                    ctx.lineWidth = w;
                    ctx.beginPath();
                    ctx.moveTo(px, py);
                    ctx.lineTo(x, y);
                    ctx.stroke();
                }
                px = x; py = y;
            }
        }
    }
}
