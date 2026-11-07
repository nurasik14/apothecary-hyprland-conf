import QtQuick
import qs.Common

/*  WashiSlip — one of Maomao's memo slips: a strip of herb-paper with deckled (hand-torn) edges, long faint kozo fibres, a few flecks of dried
 *  leaf, stitched to the desk with a silver needle trailing a vermilion thread.  The Notes card and the editor layer both draw it, so typing happens
 *  on the same slip.  Night is the same paper by lamplight (ink stays dark ink), and the mode change cross-fades like every Theme colour.
 *  Children go on top of the paper; keep clear of the top `headroom` px, where the needle sits.
 *    fillAlpha: real    translucency of the paper (the card follows the widget opacity, with a floor so ink stays readable)
 *    behind: int        slips of the pad peeking out behind this one, 0–2 (drawn outside width/height, up to 5 px)
 *    pinned: bool       draw the needle
 *    seed: int          where the edge is torn and the fibres fall (the same for the same sheet)
 *  Read-only for what is written on it: ink, inkMuted, faceColor, edgeColor.
 */
Item {
    id: slip
    property real fillAlpha: 1
    property int behind: 0
    property bool pinned: true
    property int seed: 7
    readonly property int headroom: 18

    property real night: Theme.isDark ? 1 : 0
    Behavior on night { NumberAnimation { duration: Theme.durTheme; easing.type: Easing.OutCubic } }
    function tone(day, lamp) {
        const a = Qt.color(day), b = Qt.color(lamp), t = slip.night;
        return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, 1);
    }
    readonly property color faceColor: tone("#fbf6e8", "#cdbf9f")
    readonly property color shadeColor: tone("#e6dcc6", "#b0a283")
    readonly property color edgeColor: tone("#b8ab92", "#83765f")
    readonly property color fibreColor: tone("#a8987a", "#857960")
    readonly property color fleckColor: tone("#7a8c5a", "#59633f")
    readonly property color ink: tone("#2a2622", "#15110e")
    readonly property color inkMuted: tone("#5c554b", "#33291f")

    // a window that goes away takes the Canvas's picture with it and nothing repaints it by itself (the editor's layer unmaps on close): its form calls this
    function repaint() { paper.requestPaint(); needle.requestPaint(); }
    onNightChanged: paper.requestPaint()
    onSeedChanged: paper.requestPaint()
    onBehindChanged: paper.requestPaint()
    onFillAlphaChanged: paper.requestPaint()

    function rng(s) {                     // the same torn edge every time for the same sheet
        let r = (s * 2654435761 >>> 0) || 1;
        return () => { r = (r ^ (r << 13)) >>> 0; r = (r ^ (r >>> 17)) >>> 0; r = (r ^ (r << 5)) >>> 0; return r / 4294967296; };
    }
    function outline(w, h, rnd) {         // clockwise points of the torn edge; the top was torn off a pad, so it is the roughest
        const pts = [];
        const run = (x0, y0, x1, y1, rough) => {
            const len = Math.hypot(x1 - x0, y1 - y0), nx = (y1 - y0) / len, ny = (x0 - x1) / len;
            for (let d = 0; d < len; d += 5 + rnd() * 7) {
                const j = (rnd() - 0.2) * rough;
                pts.push([x0 + (x1 - x0) * d / len - nx * j, y0 + (y1 - y0) * d / len - ny * j]);
            }
        };
        run(0, 0, w, 0, 2.2);
        run(w, 0, w, h, 1.3);
        run(w, h, 0, h, 1.3);
        run(0, h, 0, 0, 1.3);
        return pts;
    }
    function trace(ctx, pts) {
        ctx.beginPath();
        pts.forEach((p, k) => { if (k === 0) ctx.moveTo(p[0], p[1]); else ctx.lineTo(p[0], p[1]); });
        ctx.closePath();
    }

    Canvas {
        id: paper
        readonly property int margin: 10
        x: -margin; y: -margin
        width: slip.width + 2 * margin; height: slip.height + 2 * margin
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d"), w = slip.width, h = slip.height;
            ctx.reset();
            if (w <= 0 || h <= 0) return;
            ctx.translate(margin, margin);
            const rnd = slip.rng(slip.seed);
            const pts = slip.outline(w, h, rnd);

            // ---- the pad: slips behind, each a little askew
            for (let k = slip.behind; k > 0; k--) {
                ctx.save();
                ctx.translate(w / 2 + k * 2, h / 2 + k * 2);
                ctx.rotate((k % 2 ? 1.1 : -0.9) * Math.PI / 180);
                ctx.translate(-w / 2, -h / 2);
                slip.trace(ctx, pts);
                ctx.fillStyle = slip.shadeColor;
                ctx.fill();
                ctx.strokeStyle = slip.edgeColor;
                ctx.lineWidth = 1;
                ctx.stroke();
                ctx.restore();
            }

            // ---- the slip, with a soft shadow on the desk
            ctx.save();
            ctx.shadowColor = Qt.rgba(0, 0, 0, 0.32);
            ctx.shadowBlur = 5;
            ctx.shadowOffsetY = 2;
            slip.trace(ctx, pts);
            ctx.fillStyle = Theme.withAlpha(slip.faceColor, slip.fillAlpha);
            ctx.fill();
            ctx.restore();

            // ---- inside the slip only: a little age towards the edges, fibres, flecks
            ctx.save();
            slip.trace(ctx, pts);
            ctx.clip();
            const g = ctx.createLinearGradient(0, 0, 0, h);
            g.addColorStop(0, Theme.withAlpha(slip.shadeColor, 0.28));
            g.addColorStop(0.16, Theme.withAlpha(slip.shadeColor, 0));
            g.addColorStop(0.82, Theme.withAlpha(slip.shadeColor, 0));
            g.addColorStop(1, Theme.withAlpha(slip.shadeColor, 0.36));
            ctx.fillStyle = g;
            ctx.fillRect(0, 0, w, h);

            ctx.lineCap = "round";
            const fibres = Math.floor(w * h / 1300);
            for (let i = 0; i < fibres; i++) {        // long kozo fibres, mostly along the sheet
                const x = rnd() * w, y = rnd() * h, len = 14 + rnd() * 34, a = (rnd() - 0.5) * 1.1;
                const ex = x + Math.cos(a) * len, ey = y + Math.sin(a) * len;
                ctx.beginPath();
                ctx.moveTo(x, y);
                ctx.quadraticCurveTo((x + ex) / 2 + (rnd() - 0.5) * 8, (y + ey) / 2 + (rnd() - 0.5) * 8, ex, ey);
                ctx.lineWidth = 0.5 + rnd() * 0.5;
                ctx.strokeStyle = Theme.withAlpha(slip.fibreColor, 0.10 + rnd() * 0.14);
                ctx.stroke();
            }
            const flecks = Math.floor(w * h / 6000);
            for (let i = 0; i < flecks; i++) {        // herb-paper: bits of dried leaf
                const x = 8 + rnd() * (w - 16), y = 8 + rnd() * (h - 16), a = rnd() * Math.PI, len = 1.5 + rnd() * 2.5;
                ctx.beginPath();
                ctx.moveTo(x, y);
                ctx.lineTo(x + Math.cos(a) * len, y + Math.sin(a) * len);
                ctx.lineWidth = 1 + rnd() * 0.6;
                ctx.strokeStyle = Theme.withAlpha(slip.fleckColor, 0.34);
                ctx.stroke();
            }
            ctx.restore();

            // ---- the torn edge itself, drawn over the fill
            slip.trace(ctx, pts);
            ctx.lineWidth = 1;
            ctx.strokeStyle = slip.edgeColor;
            ctx.stroke();
        }
    }

    // ---- the silver needle: eye end, in through the paper, out again, the point resting on the slip; the thread hangs from its eye
    Canvas {
        id: needle
        visible: slip.pinned
        z: 5
        x: Math.round(slip.width / 2 - 46); y: 1
        width: 92; height: 17
        readonly property color threadColor: Theme.seal
        onThreadColorChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            ctx.lineCap = "round";
            // thread: out of the eye, a loose curl on the paper
            ctx.beginPath();
            ctx.moveTo(14, 11);
            ctx.bezierCurveTo(10, 17, 5, 17, 3, 12);
            ctx.bezierCurveTo(1, 7, 4, 4, 7, 7);
            ctx.lineWidth = 1.3;
            ctx.strokeStyle = threadColor;
            ctx.stroke();
            // the two holes
            ctx.fillStyle = Qt.rgba(0.08, 0.06, 0.05, 0.7);
            ctx.beginPath(); ctx.arc(38, 8.3, 1.5, 0, 2 * Math.PI); ctx.fill();
            ctx.beginPath(); ctx.arc(60, 6.1, 1.5, 0, 2 * Math.PI); ctx.fill();
            // the two visible stretches of steel: a dark body and a highlight
            const part = (x0, y0, x1, y1) => {
                ctx.beginPath(); ctx.moveTo(x0, y0 + 0.6); ctx.lineTo(x1, y1 + 0.6);
                ctx.lineWidth = 2.2; ctx.strokeStyle = "#5c6064"; ctx.stroke();
                ctx.beginPath(); ctx.moveTo(x0, y0); ctx.lineTo(x1, y1);
                ctx.lineWidth = 0.9; ctx.strokeStyle = "#f2f4f5"; ctx.stroke();
            };
            part(19, 10.2, 38, 8.3);
            part(60, 6.1, 88, 3.3);
            // the eye
            ctx.beginPath();
            ctx.ellipse(11, 8.8, 8, 3.4);
            ctx.lineWidth = 1.5;
            ctx.strokeStyle = "#5c6064";
            ctx.stroke();
        }
    }
}
