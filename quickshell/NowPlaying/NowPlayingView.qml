import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import qs.Common
import qs.Services
import qs.Widgets.Services
import qs.NowPlaying

/*  NowPlayingView — the mini-player itself: a small hanging scroll (掛軸) with the picture mounted on it.
 *
 *              ╱╲  silk cord + ring
 *    ◖━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━◗   top rod (wood, gold end caps)
 *     ┃ paper (surface + grain; lacquer at night) ┃
 *     ┃ ┌ silk band (wood + gold hairline) ────┐ ┃
 *     ┃ │ the picture: the silent mirror video  │ ┃  hover: ⏮ [⏯ seal] ⏭ at the bottom, 󰏌 ✕ top right; TikTok (logged in):
 *     ┃ │                                       │ ┃         ♥ ⟲ 🔖 (like / repost / save) above ⏮ ⏯ ⏭, a filled chip = on
 *     ┃ │ over the thumbnail (blurred letterbox)│ ┃  paused: ink wash + 停 seal · PAUSED  (nothing: 静 · STOPPED)
 *     ┃ └───────────────────────────────────────┘ ┃
 *     ┃ ─────────■────────────  ink progress, seal knob                ┃
 *     ┃ Title (LXGW WenKai, ink)                          [影] seal  ┃
 *     ┃ 󰗃 Channel / artist                       1:23 / 4:56   ⟋⟋ ┃  ⟋⟋ = resize grip (hover)
 *    ◖━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━◗   bottom rod (heavier, it weighs the scroll down)
 *
 *  Size: `boxW` (screen px) is the width of a 16:9 picture; 9:16 sources get a portrait picture 0.9 × boxW tall, square art
 *  (music) a 0.6 × boxW square.  Paper alpha = the desk cards' widgets.opacity with a floor of 0.88 (the panels' value: it floats over windows).
 *  Paused / stopped: the whole scroll dims to 72 % (full on hover).  Drag anywhere but the buttons; double-click the strip = reset.
 *    np: NowPlayingService or a mock with the same properties (renders)
 *    frameStill: an image shown as the "video" in offscreen renders (VideoOutput cannot be captured offscreen)
 *  API shared with the Overworld theme's view: np, boxW, forceHover, frameStill, mirrorEnabled, interacting, gripActive,
 *  dragFinished(), resizeFinished(int), resetRequested(), closeRequested(), clampBox().
 */
Item {
    id: root
    property var np: NowPlayingService
    property int boxW: 360
    property bool forceHover: false
    property string frameStill: ""
    property bool mirrorEnabled: true
    readonly property bool hovered: hover.hovered || forceHover || dragH.active || grip.active
    readonly property bool interacting: dragH.active || grip.active
    signal dragFinished()
    signal resizeFinished(int newBoxW)
    signal resetRequested()
    signal closeRequested()

    // ---------------------------------------------------------------- geometry
    readonly property real aspect: Math.max(0.5, Math.min(2.4, np.aspect || 1))
    readonly property string shape: aspect >= 1.2 ? "landscape" : aspect <= 0.85 ? "portrait" : "square"
    readonly property int portraitW: Math.max(120, Math.round(boxW * 0.9 * aspect))
    readonly property int vidW: shape === "landscape" ? Math.round(boxW) : shape === "portrait" ? portraitW : Math.round(boxW * 0.6)
    readonly property int vidH: shape === "landscape" ? Math.round(boxW / aspect) : shape === "portrait" ? Math.round(portraitW / aspect) : Math.round(boxW * 0.6)
    readonly property int knob: 5          // the rods stick out this far on each side of the paper
    readonly property int cordH: 16
    readonly property int rodT: 7
    readonly property int rodB: 9
    readonly property int side: 9          // paper margin beside / above the mount
    readonly property int mount: 4         // silk band around the picture
    readonly property int stripH: 6 + 10 + 3 + 20 + 17 + 6
    readonly property int paperW: vidW + 2 * mount + 2 * side
    readonly property int paperY: cordH + rodT - 2           // the paper starts under the top rod
    readonly property int paperH: 2 + side + 2 * mount + vidH + stripH + rodB - 2
    width: paperW + 2 * knob
    height: cordH + rodT + side + 2 * mount + vidH + stripH + rodB

    readonly property bool dim: (np.paused || !np.hasMedia) && !hovered
    readonly property bool still: ConfigService.reducedMotion     // config reduced_motion: no animations
    function dur(ms) { return still ? 0 : ms }
    property real contentOpacity: dim ? 0.72 : 1
    Behavior on contentOpacity { NumberAnimation { duration: root.dur(Theme.durBase); easing.type: Easing.OutCubic } }
    readonly property real paperAlpha: Math.max(0.88, Math.min(1, WidgetsState.cardOpacity))

    // position clock for the time / progress (the mirror steers itself)
    property real posNow: 0
    Timer {
        interval: 500; repeat: true; triggeredOnStart: true
        running: root.visible && root.np.hasMedia
        onTriggered: root.posNow = root.np.positionNow()
    }
    Connections { target: root.np; ignoreUnknownSignals: true; function onClockChanged() { root.posNow = root.np.positionNow() } }

    HoverHandler { id: hover }
    DragHandler {   // move it (anywhere but the buttons and the grip)
        id: dragH
        target: root
        dragThreshold: 3
        xAxis.minimum: 0
        xAxis.maximum: (root.parent ? root.parent.width : 1920) - root.width
        yAxis.minimum: 0
        yAxis.maximum: (root.parent ? root.parent.height : 1080) - root.height
        onActiveChanged: if (!active) root.dragFinished()
    }

    Item {
        anchors.fill: parent
        opacity: root.contentOpacity

        // ---------------------------------------------------------------- cord + ring (a silk cord, bronze by day, gold at night)
        Shape {
            id: cord
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            readonly property real cx: root.width / 2
            ShapePath {
                strokeColor: Theme.accent2
                strokeWidth: 1.5
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                startX: root.knob + root.paperW * 0.24; startY: root.cordH + 1
                PathLine { x: cord.cx - 2.2; y: 6.5 }
                PathMove { x: cord.cx + 2.2; y: 6.5 }
                PathLine { x: root.knob + root.paperW * 0.76; y: root.cordH + 1 }
            }
            ShapePath {   // the ring it hangs from
                strokeColor: Theme.accent2
                strokeWidth: 1.5
                fillColor: "transparent"
                PathAngleArc { centerX: cord.cx; centerY: 4.5; radiusX: 3; radiusY: 3; startAngle: 0; sweepAngle: 360 }
            }
        }

        // ---------------------------------------------------------------- the paper
        Rectangle {   // soft shadow source (hidden; drawn blurred below the paper)
            id: shadowSrc
            x: root.knob; y: root.paperY
            width: root.paperW; height: root.paperH
            color: Theme.shadow
            visible: false
            layer.enabled: true
        }
        MultiEffect {
            source: shadowSrc
            x: shadowSrc.x; y: shadowSrc.y + 3
            width: shadowSrc.width; height: shadowSrc.height
            blurEnabled: true; blur: 1.0; blurMax: 16; blurMultiplier: 0.5
            autoPaddingEnabled: true
        }
        Item {
            id: paper
            x: root.knob; y: root.paperY
            width: root.paperW; height: root.paperH
            Rectangle {
                anchors.fill: parent
                color: Theme.withAlpha(Theme.surface, root.paperAlpha)
            }
            Image {   // grain
                anchors.fill: parent
                source: Theme.texture("ground-tile")
                fillMode: Image.Tile
                opacity: Theme.textureOpacity * root.paperAlpha
                smooth: false
                asynchronous: true
            }
            Rectangle {   // paper edge: a faint ink line down both sides
                anchors.fill: parent
                color: "transparent"
                border.width: 1
                border.color: Theme.withAlpha(Theme.frame, Theme.isDark ? 0.30 : 0.38)
            }
        }

        // ---------------------------------------------------------------- the mount: silk band + the picture
        Item {
            id: frame
            x: root.knob + root.side
            y: root.cordH + root.rodT + root.side
            width: root.vidW + 2 * root.mount
            height: root.vidH + 2 * root.mount
            Rectangle {   // the silk band
                anchors.fill: parent
                color: Theme.wood
                border.width: 1
                border.color: Theme.withAlpha(Theme.frame, 0.45)
            }
            Rectangle {   // gold hairline just outside the picture
                anchors.fill: parent
                anchors.margins: root.mount - 1
                color: "transparent"
                border.width: 1
                border.color: Theme.gold
            }

            Item {
                id: picture
                x: root.mount; y: root.mount
                width: root.vidW; height: root.vidH
                clip: true
                Rectangle { anchors.fill: parent; color: Theme.isDark ? "#0f0c0a" : "#2a2622" }

                // no picture at all: a paper square with the brush glyph, like the Music card's empty cover
                Rectangle {
                    anchors.fill: parent
                    visible: thumb.status !== Image.Ready
                    color: Theme.surfaceAlt
                    Text {
                        anchors.centerIn: parent
                        text: root.np.isVideo ? "影" : "音"
                        color: Theme.textMuted
                        font.family: Theme.fontDisplay
                        font.pixelSize: Math.round(Math.min(parent.width, parent.height) * 0.36)
                        renderType: Text.NativeRendering
                    }
                }
                // thumbnail: a blurred, cropped copy fills the bars; the picture itself fits (or crops when it is a letterboxed 4:3)
                Image {
                    id: thumbBg
                    anchors.fill: parent
                    source: thumb.source
                    fillMode: Image.PreserveAspectCrop
                    sourceSize: Qt.size(96, 96)
                    asynchronous: true
                    visible: false
                }
                MultiEffect {
                    anchors.fill: parent
                    source: thumbBg
                    visible: thumb.status === Image.Ready && thumb.fillMode !== Image.PreserveAspectCrop
                    blurEnabled: true; blur: 1.0; blurMax: 40
                    brightness: -0.3; saturation: -0.2
                }
                Image {
                    id: thumb
                    anchors.fill: parent
                    source: root.frameStill.length ? "file://" + root.frameStill : (root.np.artUrl || "")
                    asynchronous: true
                    mipmap: true
                    smooth: true
                    sourceSize: Qt.size(Math.max(320, root.vidW * 2), Math.max(320, root.vidH * 2))
                    readonly property real ia: implicitHeight > 0 ? implicitWidth / implicitHeight : 0
                    // YouTube's hqdefault.jpg is 4:3 with the 16:9 picture letterboxed inside: crop that; else crop only near-matches
                    fillMode: root.frameStill.length || (ia > 0 && (Math.abs(ia - root.aspect) < 0.2
                              || (Math.abs(ia - 4 / 3) < 0.02 && root.aspect > 1.6 && root.np.site !== "ytmusic")))
                              ? Image.PreserveAspectCrop : Image.PreserveAspectFit
                }

                VideoMirror {
                    id: mirror
                    anchors.fill: parent
                    active: root.mirrorEnabled && root.visible && root.np.videoFile.length > 0 && !root.np.ad
                    source: active ? root.np.videoFile : ""
                    clock: root.np.clock
                    opacity: ready ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: root.dur(Theme.durBase); easing.type: Easing.OutCubic } }
                }

                // badges: LIVE is a small vermilion seal, an ad an ochre slip
                Rectangle {
                    visible: root.np.live || root.np.ad
                    x: 6; y: 6
                    width: badge.implicitWidth + 10; height: 17
                    radius: 2
                    color: root.np.ad ? "#7A510C" : Theme.seal
                    border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.35)
                    Text {
                        id: badge
                        anchors.centerIn: parent
                        text: root.np.ad ? "Ad" : "LIVE"
                        color: "#FBF7EE"
                        font.family: Theme.fontUi; font.pixelSize: 10; font.weight: Font.Bold; font.letterSpacing: 1
                        renderType: Text.NativeRendering
                    }
                }
                Rectangle {   // a TikTok like / repost / save just failed: say why for a few seconds (also in the chip's tooltip)
                    visible: root.np.actionErrorFresh === true && root.np.canLike === true
                    x: 6; width: parent.width - 12
                    anchors.bottom: parent.bottom; anchors.bottomMargin: 8 + 24 + 4 + 24 + 6
                    height: errText.implicitHeight + 6
                    radius: 3
                    color: "#C8151110"
                    border.width: 1; border.color: Theme.withAlpha(Theme.seal, 0.8)
                    z: 1
                    Text {
                        id: errText
                        x: 6; width: parent.width - 12
                        anchors.verticalCenter: parent.verticalCenter
                        text: String(root.np.actionError || "")
                        color: "#F2E9D4"
                        font.family: Theme.fontUi; font.pixelSize: 11
                        wrapMode: Text.WordWrap; maximumLineCount: 2; elide: Text.ElideRight
                        renderType: Text.NativeRendering
                    }
                }
                Rectangle {   // the mirror video is still on its way
                    visible: !root.hovered && !mirror.ready && root.np.videoStatus === "fetching" && root.np.hasMedia
                    x: 6; anchors.bottom: parent.bottom; anchors.bottomMargin: 6
                    width: fetchText.implicitWidth + 12; height: 18
                    radius: 3
                    color: "#99151110"
                    Text {
                        id: fetchText
                        anchors.centerIn: parent
                        text: "Fetching video…"
                        color: "#F2E9D4"
                        font.family: Theme.fontUi; font.pixelSize: 11; font.italic: true
                        renderType: Text.NativeRendering
                    }
                }
                Item {   // paused / stopped: an ink wash and a seal
                    anchors.fill: parent
                    visible: (root.np.paused || !root.np.hasMedia) && !root.hovered
                    Rectangle { anchors.fill: parent; color: "#55100c0a" }
                    Column {
                        anchors.centerIn: parent
                        spacing: 4
                        Seal {
                            anchors.horizontalCenter: parent.horizontalCenter
                            size: root.vidW >= 200 && root.vidH >= 110 ? 30 : 22
                            glyph: root.np.hasMedia ? "停" : "静"
                            label: root.np.hasMedia ? "Paused" : "Stopped"
                            outline: true
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root.np.hasMedia ? "PAUSED" : "STOPPED"
                            color: "#F2E9D4"
                            font.family: Theme.fontSerif; font.pixelSize: 13; font.weight: 600; font.letterSpacing: 2
                            style: Text.Raised; styleColor: "#80000000"
                            renderType: Text.NativeRendering
                        }
                    }
                }

                // ---------------------------------------------------------------- hover controls
                Item {
                    anchors.fill: parent
                    opacity: root.hovered ? 1 : 0
                    visible: opacity > 0.01
                    Behavior on opacity { NumberAnimation { duration: root.dur(Theme.durFast); easing.type: Easing.OutCubic } }
                    Rectangle {
                        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                        height: ttRow.visible ? Math.min(parent.height * 0.7, 84) : Math.min(parent.height * 0.45, 52)
                        gradient: Gradient { GradientStop { position: 0; color: "#00100c0a" } GradientStop { position: 1; color: "#B0100c0a" } }
                    }
                    Rectangle {
                        anchors { left: parent.left; right: parent.right; top: parent.top }
                        height: 36
                        gradient: Gradient { GradientStop { position: 0; color: "#90100c0a" } GradientStop { position: 1; color: "#00100c0a" } }
                    }
                    Row {
                        anchors.right: parent.right; anchors.top: parent.top
                        anchors.margins: 6
                        spacing: 4
                        Chip { glyph: "󰏌"; tip: "Show the source window"; tipBelow: true; enabled: root.np.canFocus; onClicked: root.np.focusSource() }
                        Chip { glyph: "󰅖"; tip: "Close (turn it off)"; tipBelow: true; onClicked: root.closeRequested() }
                    }
                    Row {   // TikTok, logged in: like / repost / save the clip on screen (the userscript clicks TikTok's own buttons)
                        id: ttRow
                        objectName: "tiktokRow"
                        visible: root.np.canLike === true
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: transport.top; anchors.bottomMargin: 4
                        spacing: transport.spacing
                        readonly property string busy: String(root.np.busy || "")
                        readonly property string coll: String(root.np.tiktokCollection || "Edits")
                        function tipFor(act, on, off, unknown, state) {
                            const err = String(root.np.actionErrorFor || "") === act ? String(root.np.actionError || "") : "";
                            return (state === true ? on : state === false ? off : unknown) + (err.length ? " — " + err : "");
                        }
                        Chip {
                            readonly property var st: root.np.liked
                            wide: true
                            glyph: ttRow.busy === "like" ? "󰔟" : st === true ? "󰋑" : "󰋕"
                            fill: st === true ? Theme.seal : "transparent"
                            enabled: ttRow.busy.length === 0
                            tip: ttRow.tipFor("like", "Liked · unlike", "Like", "Like (state unknown)", st)
                            onClicked: root.np.act("like")
                        }
                        Chip {
                            readonly property var st: root.np.reposted
                            wide: true
                            glyph: ttRow.busy === "repost" ? "󰔟" : "󰕇"
                            fill: st === true ? Theme.success : "transparent"
                            enabled: ttRow.busy.length === 0
                            tip: ttRow.tipFor("repost", "Reposted · remove repost", "Repost", "Repost (state unknown until you use it)", st)
                            onClicked: root.np.act("repost")
                        }
                        Chip {
                            readonly property var st: root.np.saved
                            wide: true
                            glyph: ttRow.busy === "save" ? "󰔟" : st === true ? "󰃀" : "󰃃"
                            fill: st === true ? Theme.gold : "transparent"
                            enabled: ttRow.busy.length === 0
                            tip: ttRow.tipFor("save", "Saved · un-save (leaves Favorites and every collection)", "Save to " + ttRow.coll, "Save (state unknown)", st)
                            onClicked: root.np.act("save")
                        }
                    }
                    Row {
                        id: transport
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom; anchors.bottomMargin: 8
                        spacing: root.vidW >= 180 ? 8 : 4
                        Chip { glyph: "󰒮"; tip: "Previous"; wide: true; enabled: root.np.canPrevious; onClicked: root.np.previous() }
                        Chip {
                            glyph: root.np.paused ? "󰐊" : "󰏤"
                            tip: root.np.paused ? "Play" : "Pause"
                            seal: true; wide: true
                            enabled: root.np.canToggle
                            onClicked: root.np.togglePlaying()
                        }
                        Chip { glyph: "󰒭"; tip: "Next"; wide: true; enabled: root.np.canNext; onClicked: root.np.next() }
                    }
                }
            }
        }

        // ---------------------------------------------------------------- the strip: progress, title + seal, source + artist + time
        Item {
            id: strip
            x: root.knob + root.side
            y: frame.y + frame.height + 6
            width: frame.width
            height: root.stripH - 6 - 6
            Item {   // ink progress line with a seal knob (like the Music card's, not seekable here)
                id: progress
                width: parent.width; height: 10
                readonly property bool known: root.np.duration > 0 && !root.np.live
                readonly property real frac: known ? Math.max(0, Math.min(1, root.posNow / root.np.duration)) : 0
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width; height: 2
                    color: Theme.hairline
                }
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: progress.known ? parent.width * progress.frac : (root.np.live ? parent.width : 0)
                    height: 2
                    color: Theme.text
                    opacity: progress.known ? 1 : 0.35
                    Behavior on width { NumberAnimation { duration: root.dur(500); easing.type: Easing.OutCubic } }
                }
                Rectangle {
                    visible: progress.known
                    x: parent.width * progress.frac - width / 2
                    anchors.verticalCenter: parent.verticalCenter
                    width: 8; height: 8; radius: 1
                    color: Theme.seal
                    border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.35)
                    Behavior on x { NumberAnimation { duration: root.dur(500); easing.type: Easing.OutCubic } }
                }
            }
            Item {   // title + seal
                y: progress.height + 3
                width: parent.width; height: 20
                Text {
                    anchors.left: parent.left
                    anchors.right: titleSeal.left; anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.np.title.length ? root.np.title : (root.np.hasMedia ? root.np.sourceLabel : "Nothing playing")
                    color: Theme.text
                    font.family: Theme.fontBody; font.pixelSize: 14; font.weight: Font.Medium
                    elide: Text.ElideRight
                    wrapMode: Text.NoWrap
                    maximumLineCount: 1
                    renderType: Text.NativeRendering
                }
                Seal {
                    id: titleSeal
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    size: 16
                    glyph: root.np.isVideo ? "影" : "音"
                    label: root.np.isVideo ? "Now playing (video)" : "Now playing (music)"
                }
            }
            Item {   // source glyph + artist + time
                y: progress.height + 3 + 20
                width: parent.width; height: 17
                Text {
                    id: glyphText
                    anchors.verticalCenter: parent.verticalCenter
                    text: ({ youtube: "󰗃", ytmusic: "󰗃", tiktok: "󰝚", spotify: "󰓇" })[root.np.site] || "󰝚"
                    color: ({ youtube: Theme.error, ytmusic: Theme.error, spotify: Theme.success, tiktok: Theme.plum })[root.np.site] || Theme.textMuted
                    font.family: Theme.fontMono; font.pixelSize: 13
                    renderType: Text.NativeRendering
                }
                Text {
                    x: glyphText.width + 6
                    width: parent.width - x - (timeText.visible ? timeText.implicitWidth + 8 : 0) - (gripArea.visible ? 14 : 0)
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.np.artist.length ? root.np.artist : root.np.sourceLabel
                    color: Theme.textMuted
                    font.family: Theme.fontBody; font.pixelSize: 12
                    elide: Text.ElideRight
                    wrapMode: Text.NoWrap
                    maximumLineCount: 1
                    renderType: Text.NativeRendering
                }
                Text {
                    id: timeText
                    anchors.right: parent.right; anchors.rightMargin: gripArea.visible ? 14 : 0
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.np.hasMedia && root.paperW >= 236
                    text: root.np.live ? "LIVE" : root.np.fmt(root.posNow) + (root.np.duration > 0 ? " / " + root.np.fmt(root.np.duration) : "")
                    color: Theme.textMuted
                    font.family: Theme.fontMono; font.pixelSize: 11
                    renderType: Text.NativeRendering
                }
            }
            TapHandler {   // double-click = reset: two taps within 400 ms (timed here rather than tapCount, which synthetic test events never raise)
                property real lastTap: 0
                onTapped: {
                    const t = Date.now();
                    if (t - lastTap < 400) { lastTap = 0; root.resetRequested(); } else lastTap = t;
                }
            }
        }

        // ---------------------------------------------------------------- the rods (drawn over the paper ends)
        Rod { y: root.cordH; height: root.rodT }
        Rod { y: root.height - root.rodB; height: root.rodB }
    }

    // ---------------------------------------------------------------- resize grip (bottom-right of the paper, keeps the aspect)
    Item {
        id: gripArea
        objectName: "grip"
        width: 14; height: 14
        x: root.knob + root.paperW - width - 3
        y: root.height - root.rodB - height - 2
        visible: root.hovered
        Shape {   // three brush strokes
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: Theme.textMuted; strokeWidth: 1.5; fillColor: "transparent"; capStyle: ShapePath.RoundCap
                startX: 13; startY: 3
                PathLine { x: 3; y: 13 }
                PathMove { x: 13; y: 7 }
                PathLine { x: 7; y: 13 }
                PathMove { x: 13; y: 11 }
                PathLine { x: 11; y: 13 }
            }
        }
        HoverHandler { cursorShape: Qt.SizeFDiagCursor }
        DragHandler {
            id: grip
            target: null
            // the scroll's own DragHandler (same type) would otherwise keep the grab and move the scroll instead of resizing it
            grabPermissions: PointerHandler.CanTakeOverFromAnything
            dragThreshold: 1
            property int startBox: 0
            property real startW: 1
            property real startH: 1
            onActiveChanged: {   // the picture is what grows (cord, rods, margins and the strip keep their size), so scale by it
                if (active) { startBox = root.boxW; startW = Math.max(1, root.vidW); startH = Math.max(1, root.vidH); }
                else root.resizeFinished(root.boxW);
            }
            onTranslationChanged: {
                if (!active) return;
                const fx = (startW + translation.x) / startW, fy = (startH + translation.y) / startH;
                const f = Math.abs(fx - 1) > Math.abs(fy - 1) ? fx : fy;
                root.boxW = Math.round(root.clampBox(startBox * f));
            }
        }
    }
    readonly property alias gripActive: grip.active
    // min 200, max 960, and never larger than the screen allows from the current corner. Only the picture scales with boxW
    // (vidW = boxW · rw, vidH = boxW · rh for the current shape); the rest of the scroll is a fixed frame around it.
    function clampBox(b) {
        const pw = root.parent ? root.parent.width : 1920, ph = root.parent ? root.parent.height : 1080;
        const bw = Math.max(1, root.boxW), rw = root.vidW / bw, rh = root.vidH / bw;
        const fixedW = root.width - root.vidW, fixedH = root.height - root.vidH;
        let hi = 960;
        if (rw > 0) hi = Math.min(hi, (pw - root.x - fixedW) / rw);
        if (rh > 0) hi = Math.min(hi, (ph - root.y - fixedH) / rh);
        return Math.max(200, Math.min(Math.max(200, hi), b));
    }

    // ---------------------------------------------------------------- parts
    // a scroll rod: rosewood with a highlight, gold end caps, a little wider than the paper
    component Rod: Item {
        x: 0
        width: root.width
        Rectangle {
            anchors.fill: parent
            anchors.leftMargin: 3; anchors.rightMargin: 3
            radius: height / 2
            gradient: Gradient {
                GradientStop { position: 0; color: Theme.isDark ? "#6a4c33" : "#8b6b45" }
                GradientStop { position: 0.45; color: Theme.isDark ? "#4a3322" : "#6b4a2b" }
                GradientStop { position: 1; color: Theme.isDark ? "#2a1c12" : "#3d2816" }
            }
        }
        Rectangle {   // end caps
            x: 0; width: 6; height: parent.height + 2; y: -1; radius: 2
            color: Theme.gold
            border.width: 1; border.color: Qt.darker(Theme.gold, 1.6)
        }
        Rectangle {
            x: parent.width - width; width: 6; height: parent.height + 2; y: -1; radius: 2
            color: Theme.gold
            border.width: 1; border.color: Qt.darker(Theme.gold, 1.6)
        }
    }

    // a control over the picture: a small paper chip (the play/pause one is a vermilion seal)
    component Chip: Item {
        id: chip
        property string glyph: ""
        property string tip: ""
        property bool seal: false
        property bool wide: false
        property bool tipBelow: false     // top-right chips: the tooltip hangs below, right-aligned; the others: above, centred
        property color fill: "transparent"   // a TikTok toggle that is on: filled in its colour, like the seal chip
        readonly property bool solid: seal || fill.a > 0
        signal clicked()
        width: wide ? (root.vidW >= 180 ? 34 : 28) : 24
        height: 24
        opacity: enabled ? 1 : 0.45
        Accessible.role: Accessible.Button
        Accessible.name: tip
        Rectangle {
            anchors.fill: parent
            radius: Theme.radius.sm
            color: chip.seal ? Theme.seal : chip.fill.a > 0 ? chip.fill : Theme.withAlpha(Theme.surface, 0.92)
            border.width: 1
            border.color: chip.solid ? Qt.rgba(1, 1, 1, 0.35) : Theme.withAlpha(Theme.frame, 0.5)
        }
        Rectangle {   // ink wash on hover / press
            anchors.fill: parent
            radius: Theme.radius.sm
            color: chip.solid ? Qt.rgba(1, 1, 1, 1) : Theme.inkWashStrong
            opacity: ma.pressed ? (chip.solid ? 0.22 : 1) : ma.containsMouse ? (chip.solid ? 0.12 : 0.6) : 0
            Behavior on opacity { NumberAnimation { duration: Theme.durFast } }
        }
        Text {
            anchors.centerIn: parent
            text: chip.glyph
            color: chip.solid ? Theme.textOnSeal : Theme.text
            font.family: Theme.fontMono; font.pixelSize: 14
            renderType: Text.NativeRendering
        }
        MouseArea {
            id: ma
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: chip.clicked()
        }
        Timer { id: tipDelay; interval: 450; running: ma.containsMouse && chip.tip.length > 0 }
        Rectangle {   // a small paper tooltip (Latin), after a short hover
            visible: ma.containsMouse && !tipDelay.running && chip.tip.length > 0
            z: 10
            width: tipText.implicitWidth + 10; height: 18
            radius: 2
            x: chip.tipBelow ? chip.width - width : (chip.width - width) / 2
            y: chip.tipBelow ? chip.height + 4 : -height - 4
            color: Theme.withAlpha(Theme.surface, 0.96)
            border.width: 1; border.color: Theme.withAlpha(Theme.frame, 0.6)
            Text {
                id: tipText
                anchors.centerIn: parent
                text: chip.tip
                color: Theme.text
                font.family: Theme.fontUi; font.pixelSize: 11
                renderType: Text.NativeRendering
            }
        }
    }
}
