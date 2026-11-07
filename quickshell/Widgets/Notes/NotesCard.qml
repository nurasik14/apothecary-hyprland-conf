import QtQuick
import qs.Common
import qs.Services
import qs.Widgets
import qs.Widgets.Services

/*  NotesCard — 札记 · NOTES (254 × 244): Maomao's scribbled memos, a pad of herb-paper slips stitched to the desk for raw, stray thoughts.  No titles,
 *  no structure.  The slip shows the current note (wrapped, fading out at the bottom when long); click it to write (NotesEditor, the same slip on
 *  a layer that takes the keyboard, because this widget layer never does).  Footer: ◀ 2/5 ▶ (also the mouse wheel over the card), when it was last
 *  touched, + for a new sheet.  Hover the slip: ✕ tears it off, with torn scraps, the seal cue and "Undo" for 5 s.  Empty: a vermilion 札 and "Click to
 *  scribble a thought"; it never invents notes.  Every other way in (`hypr-notes`, `apothecary notes`, IPC target notes): NotesService.
 *  The pad is shared with Overworld: a note written there is on this slip.
 */
WidgetCard {
    id: card
    title: "札记"
    subtitle: "Notes"
    sealGlyph: "记"
    width: 254
    height: 244
    padding: 12

    property string screenName: ""             // DesktopWidgets: which output's rectangle this card publishes
    property bool pinHover: false              // previews only: draw the ✕ as if hovered
    property string lastSound: ""              // which cue the last tear-off asked for (tests)
    readonly property var svc: NotesService
    readonly property var note: svc.current
    readonly property bool hot: hoverer.hovered || pinHover
    readonly property string age: note ? svc.relTime(note.updated, svc.nowTick) : ""
    readonly property alias slipItem: slip     // tests
    readonly property alias tearButton: tearArea
    readonly property alias prevButton: prevB
    readonly property alias nextButton: nextB
    readonly property alias newButton: newB
    readonly property alias undoButton: undoB

    property double lastTear: 0
    function tearOff() {
        if (!note || Date.now() - lastTear < 400) return;      // a double click must not take the next sheet too: it is under the pointer by the second click
        lastTear = Date.now();
        card.lastSound = "seal";
        SoundService.play("seal");             // the soft thud of a stamp: the nearest thing to paper this theme has
        svc.remove(note.id);
    }
    function flipBy(delta) { svc.flip(delta); }
    function openSheet() { svc.openEditor("current"); }
    function newSheet() { svc.openEditor("new"); }
    property real wheelRest: 0
    function wheelBy(dy) {                     // a notch is 120; a touchpad's small steps add up to one
        wheelRest += dy;
        if (Math.abs(wheelRest) < 120) return;
        const d = wheelRest > 0 ? -1 : 1;
        wheelRest = 0;
        flipBy(d);
    }

    // where the slip is on the output: the editor opens right over it
    readonly property var paperRect: ({ x: card.x + card.contentItem.x + slip.x, y: card.y + card.contentItem.y + slip.y, w: slip.width, h: slip.height, shown: card.shown })
    onPaperRectChanged: svc.setCardRect(screenName, paperRect)
    onScreenNameChanged: svc.setCardRect(screenName, paperRect)

    HoverHandler { id: hoverer }
    MouseArea {                                // the wheel anywhere on the card flips; clicks go to what is on top of it
        parent: card
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        onWheel: wheel => card.wheelBy(wheel.angleDelta.y)
    }

    // ---- the slip
    WashiSlip {
        id: slip
        x: 0; y: 0
        width: parent.width - 4; height: 148
        fillAlpha: Math.max(0.9, WidgetsState.cardOpacity)
        behind: Math.min(2, Math.max(0, card.svc.count - 1))
        seed: card.note ? (card.note.id.charCodeAt(card.note.id.length - 1) + card.note.id.charCodeAt(card.note.id.length - 2) * 31) : 7

        Item {
            id: writing
            x: 12; y: slip.headroom
            width: parent.width - 24
            height: parent.height - slip.headroom - 9
            clip: true
            readonly property bool overflows: card.note !== null && body.contentHeight > height
            readonly property int bandHeight: 3
            readonly property var bands: [0.82, 0.68, 0.54, 0.41, 0.29, 0.18, 0.09, 0.03]
            Item {
                id: bodyClip
                width: parent.width
                height: parent.height - (writing.overflows ? writing.bands.length * writing.bandHeight : 0)
                clip: true
                SlipText { id: body; visible: card.note !== null; width: writing.width; color: slip.ink; text: card.note ? card.note.text : "" }
            }
            // a long note fades out: the same text again, in thin strips of falling opacity (an overlay would show on the translucent paper)
            Repeater {
                model: writing.overflows ? writing.bands : []
                Item {
                    required property real modelData
                    required property int index
                    y: bodyClip.height + index * height
                    width: writing.width; height: writing.bandHeight
                    clip: true
                    opacity: modelData
                    SlipText { y: -parent.y; width: writing.width; color: slip.ink; text: body.text }
                }
            }
            // empty: never an invented note, just where to start
            Column {
                visible: card.note === null
                anchors.centerIn: parent
                spacing: 2
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "札"
                    color: Theme.seal
                    opacity: 0.85
                    font.family: Theme.fontDisplay
                    font.pixelSize: 40
                    renderType: Text.NativeRendering
                }
                InkText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    role: "body"
                    color: slip.ink
                    text: "Click to scribble a thought"
                }
                InkText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    role: "small"
                    color: slip.inkMuted
                    text: "or Super+Alt+N"
                }
            }
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.IBeamCursor
            onClicked: card.openSheet()
            Accessible.role: Accessible.Button
            Accessible.name: card.note ? "Edit this note" : "Write a note"
        }
        // ✕ on hover: tear the slip off
        Item {
            visible: card.hot && card.note !== null
            x: parent.width - 24; y: 2
            width: 20; height: 20
            Text {
                anchors.centerIn: parent
                text: "✕"
                font.family: Theme.fontUi
                font.pixelSize: 12
                color: tearArea.containsMouse ? Theme.seal : slip.inkMuted
                renderType: Text.NativeRendering
            }
            MouseArea {
                id: tearArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: card.tearOff()
                Accessible.role: Accessible.Button
                Accessible.name: "Tear off this note"
            }
        }
        PaperScraps {
            id: scraps
            anchors.fill: parent
            z: 20
            colorA: slip.faceColor
            colorB: slip.edgeColor
        }
    }
    Connections {
        target: card.svc
        function onSheetTorn() { if (card.shown) scraps.burst(); }
    }

    // ---- the footer: ◀ 2/5 ▶  3 min ago  +
    Item {
        x: 0; y: 162
        width: parent.width; height: 24
        InkButton {
            id: prevB
            visible: card.svc.count > 1
            x: 0
            implicitHeight: 24; width: 26; horizontalPadding: 0
            icon: "󰁍"; quiet: true
            tooltip: "Previous note"
            enabled: card.svc.currentIndex > 0
            activeFocusOnTab: false
            onClicked: card.flipBy(-1)
        }
        InkText {
            id: pager
            visible: card.svc.count > 0
            x: card.svc.count > 1 ? 26 : 0
            width: 34; height: parent.height
            role: "small"
            horizontalAlignment: card.svc.count > 1 ? Text.AlignHCenter : Text.AlignLeft
            text: (card.svc.currentIndex + 1) + "/" + card.svc.count
        }
        InkButton {
            id: nextB
            visible: card.svc.count > 1
            x: 60
            implicitHeight: 24; width: 26; horizontalPadding: 0
            icon: "󰁔"; quiet: true
            tooltip: "Next note"
            enabled: card.svc.currentIndex < card.svc.count - 1
            activeFocusOnTab: false
            onClicked: card.flipBy(1)
        }
        InkText {
            x: card.svc.count > 1 ? 90 : 38
            width: parent.width - x - 30; height: parent.height
            role: "small"; muted: true
            horizontalAlignment: Text.AlignRight
            text: card.age
        }
        InkButton {
            id: newB
            anchors.right: parent.right
            implicitHeight: 24; width: 26; horizontalPadding: 0
            icon: "󰐕"; quiet: true
            tooltip: "New sheet (Super+Alt+N)"
            activeFocusOnTab: false
            onClicked: card.newSheet()
        }
    }

    // ---- undo slip (5 s after a tear-off)
    Rectangle {
        visible: card.svc.undo !== null
        anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
        height: 32
        radius: 6
        color: Theme.titlebar
        border.width: 1; border.color: Theme.withAlpha(Theme.titlebarText, 0.3)
        MouseArea { anchors.fill: parent }     // clicks on the slip don't reach the pager under it
        InkText {
            x: 10
            width: parent.width - 10 - 72
            height: parent.height
            role: "small"
            color: Theme.titlebarText
            text: card.svc.undo ? (card.svc.undo.count > 1 ? "Tore off " + card.svc.undo.count + " notes" : "Tore off “" + (card.svc.undo.preview || "a note") + "”") : ""
        }
        InkButton {
            id: undoB
            anchors.right: parent.right; anchors.rightMargin: 4; anchors.verticalCenter: parent.verticalCenter
            text: "Undo"; icon: "󰕌"; primary: true
            implicitHeight: 24; horizontalPadding: 6
            activeFocusOnTab: false
            onClicked: card.svc.undoRemove()
        }
    }

    component SlipText: Text {                 // the note: readable Kai ink (covers Latin, Cyrillic and Kazakh, CJK), never the brush font
        font.family: Theme.fontFor("body").family
        font.pixelSize: Theme.fontFor("body").pixelSize
        wrapMode: Text.Wrap
        textFormat: Text.PlainText
        renderType: Text.NativeRendering
    }
}
