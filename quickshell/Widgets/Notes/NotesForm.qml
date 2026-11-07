import QtQuick
import qs.Common
import qs.Services
import qs.Widgets.Services

/*  NotesForm — the slip you write on: the card's paper, somewhat larger, with a vermilion caret, the page in the corner and, on a strip under it, flip / new
 *  and the 记 seal button (Done).  Used by NotesEditor (inside the apothecary-notes layer) and by the offscreen renders.
 *    active: bool    true while open: takes the keyboard
 *  Keys: Enter = new line · Esc / Ctrl+Enter / Done / a click outside = save and close · Ctrl+N = new sheet · Ctrl+PgUp / PgDn = flip.
 *  Every keystroke goes to NotesService.typed(): saved 700 ms after the last one, an empty sheet is dropped on close.
 */
Item {
    id: form
    property bool active: false
    signal closeAsked()

    readonly property var svc: NotesService
    readonly property int sheetW: 340
    readonly property int sheetH: 240
    readonly property int stripH: 62
    readonly property alias textEdit: edit
    readonly property alias doneButton: doneArea
    readonly property alias prevButton: prevB
    readonly property alias nextButton: nextB
    readonly property alias newButton: newB
    width: sheetW
    height: sheetH + 8 + stripH

    property bool loading: false
    function load(text) {
        form.loading = true;
        edit.text = text;
        edit.cursorPosition = edit.length;
        form.loading = false;
        flick.contentY = Math.max(0, edit.contentHeight - flick.height);
        if (form.active) edit.forceActiveFocus();
    }
    Connections {
        target: form.svc
        function onDraftLoaded(text) { form.load(text); }
    }
    onActiveChanged: if (active) { paper.repaint(); load(svc.draftText); }
    Component.onCompleted: { hold(); if (active) load(svc.draftText); }
    Timer { interval: 30; running: form.active; onTriggered: { paper.repaint(); edit.forceActiveFocus(); } }   // once the layer has really mapped

    // the draft ends a moment before the layer has faded out: the slip keeps the torn edge and the page it had, it does not change under the closing frame
    property int slipSeed: 7
    property int page: 1
    property int pages: 1
    function hold() {
        const id = form.svc.draftId;
        if (!id.length) return;
        form.slipSeed = id.charCodeAt(id.length - 1) + id.charCodeAt(id.length - 2) * 31;
        form.page = form.svc.draftPage;
        form.pages = form.svc.draftPages;
    }
    Connections {
        target: form.svc
        function onDraftIdChanged() { form.hold(); }
        function onDraftPageChanged() { form.hold(); }
        function onDraftPagesChanged() { form.hold(); }
    }

    // On a Cyrillic layout Qt reports the Cyrillic letter, so Ctrl+N (and TextEdit's own Ctrl+A/C/V/X/Z) would never match: fall back to
    // the physical key.  nativeScanCode is the xkb keycode on Wayland (evdev + 8).
    function latinKey(e) {
        if (e.key < 0x400 || e.key > 0x52f) return 0;
        return ({ 57: Qt.Key_N, 38: Qt.Key_A, 54: Qt.Key_C, 55: Qt.Key_V, 53: Qt.Key_X, 52: Qt.Key_Z })[e.nativeScanCode] || 0;
    }
    function keyPressed(e) {
        const ctrl = e.modifiers & Qt.ControlModifier;
        const latin = ctrl ? form.latinKey(e) : 0;
        if (latin) {
            if (latin === Qt.Key_N) form.svc.newDraft();
            else if (latin === Qt.Key_A) edit.selectAll();
            else if (latin === Qt.Key_C) edit.copy();
            else if (latin === Qt.Key_V) edit.paste();
            else if (latin === Qt.Key_X) edit.cut();
            else if (e.modifiers & Qt.ShiftModifier) edit.redo();
            else edit.undo();
            e.accepted = true;
        }
        else if (e.key === Qt.Key_Escape || (ctrl && (e.key === Qt.Key_Return || e.key === Qt.Key_Enter))) { form.closeAsked(); e.accepted = true; }
        else if (ctrl && e.key === Qt.Key_N) { form.svc.newDraft(); e.accepted = true; }
        else if (ctrl && e.key === Qt.Key_PageUp) { form.svc.flipDraft(-1); e.accepted = true; }
        else if (ctrl && e.key === Qt.Key_PageDown) { form.svc.flipDraft(1); e.accepted = true; }
    }

    MouseArea { anchors.fill: parent; onClicked: edit.forceActiveFocus() }      // clicks on the slip don't reach the scrim behind it

    WashiSlip {
        id: paper
        width: form.sheetW; height: form.sheetH
        seed: form.slipSeed

        InkText {
            anchors.right: parent.right; anchors.rightMargin: 12
            y: 5
            role: "small"
            color: paper.inkMuted
            text: form.page + " / " + form.pages
        }
        Flickable {
            id: flick
            x: 14; y: paper.headroom + 6
            width: parent.width - 28
            height: parent.height - y - 12
            contentWidth: width
            contentHeight: edit.contentHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            function ensureVisible(r) {
                if (contentY >= r.y) contentY = r.y;
                else if (contentY + height <= r.y + r.height) contentY = r.y + r.height - height;
            }
            TextEdit {
                id: edit
                width: flick.width
                height: Math.max(implicitHeight, flick.height)
                color: paper.ink
                selectionColor: Theme.withAlpha(Theme.accent, 0.3)
                selectedTextColor: paper.ink
                font.family: Theme.fontFor("body").family
                font.pixelSize: 15
                renderType: TextEdit.NativeRendering
                textFormat: TextEdit.PlainText
                wrapMode: TextEdit.Wrap
                selectByMouse: true
                activeFocusOnTab: false
                cursorVisible: form.active
                cursorDelegate: Rectangle {
                    width: 2
                    color: "#b02f2a"              // vermilion on the paper in both modes (Theme.cursor turns gold at night, for dark surfaces)
                    visible: edit.cursorVisible
                    opacity: 1
                    SequentialAnimation on opacity {
                        running: edit.cursorVisible && !ConfigService.reducedMotion
                        loops: Animation.Infinite
                        alwaysRunToEnd: true
                        PropertyAction { value: 1 }
                        PauseAnimation { duration: 560 }
                        PropertyAction { value: 0 }
                        PauseAnimation { duration: 480 }
                    }
                }
                onCursorRectangleChanged: flick.ensureVisible(cursorRectangle)
                onTextChanged: {
                    if (form.loading) return;
                    if (length > form.svc.maxChars) {   // full: refuse what was just typed or pasted, not the end of the note
                        const over = [...text].length - form.svc.maxChars;
                        if (over > 0) {
                            const before = [...text.slice(0, cursorPosition)];
                            const cut = before.slice(Math.max(0, before.length - over)).join("").length;
                            if (cut > 0) remove(cursorPosition - cut, cursorPosition);
                            else remove([...text].slice(0, form.svc.maxChars).join("").length, length);     // nothing before the caret to refuse
                            return;
                        }
                    }
                    form.svc.typed(text);
                }
                Keys.onPressed: e => form.keyPressed(e)
            }
        }
        InkText {
            visible: edit.length === 0
            x: flick.x; y: flick.y
            role: "body"
            font.pixelSize: 15
            color: paper.inkMuted
            text: "Write something…"
        }
        Rectangle {   // scroll position
            visible: flick.contentHeight > flick.height
            x: parent.width - 7; width: 3; radius: 1.5
            y: flick.y + flick.height * flick.visibleArea.yPosition
            height: Math.max(16, flick.height * flick.visibleArea.heightRatio)
            color: paper.edgeColor
        }
    }

    // ---- under the slip, on a paper strip of its own so it reads over any wallpaper: flip, new, the seal, the keys
    MouseArea { y: strip.y; width: strip.width; height: strip.height; onClicked: edit.forceActiveFocus() }
    Rectangle {
        id: strip
        y: form.sheetH + 8
        width: parent.width; height: form.stripH
        radius: Theme.radius.md
        color: Theme.surface
        border.width: 1; border.color: Theme.hairline
        Behavior on color { ColorAnimation { duration: Theme.durTheme; easing.type: Easing.OutCubic } }

        Row {
            x: 6; y: 6
            spacing: 4
            InkButton {
                id: prevB
                width: 32; implicitHeight: 30; horizontalPadding: 0
                icon: "󰁍"
                tooltip: "Previous note (Ctrl+PgUp)"
                enabled: form.page > 1
                activeFocusOnTab: false
                onClicked: { form.svc.flipDraft(-1); edit.forceActiveFocus(); }
            }
            InkButton {
                id: nextB
                width: 32; implicitHeight: 30; horizontalPadding: 0
                icon: "󰁔"
                tooltip: "Next note (Ctrl+PgDn)"
                enabled: form.page < form.pages
                activeFocusOnTab: false
                onClicked: { form.svc.flipDraft(1); edit.forceActiveFocus(); }
            }
            InkButton {
                id: newB
                width: 32; implicitHeight: 30; horizontalPadding: 0
                icon: "󰐕"
                tooltip: "New sheet (Ctrl+N)"
                activeFocusOnTab: false
                onClicked: { form.svc.newDraft(); edit.forceActiveFocus(); }
            }
        }
        Rectangle {       // 记: stamping the note done
            id: done
            anchors.right: parent.right; anchors.rightMargin: 6
            y: 6
            width: doneRow.implicitWidth + 24; height: 30
            radius: Theme.radius.sm
            color: Theme.seal
            Accessible.role: Accessible.Button
            Accessible.name: "Done: save and close"
            Rectangle {
                anchors.fill: parent; radius: parent.radius
                color: "#ffffff"
                opacity: doneArea.pressed ? 0.18 : (doneArea.containsMouse ? 0.10 : 0)
                Behavior on opacity { NumberAnimation { duration: Theme.durFast; easing.type: Easing.OutCubic } }
            }
            Row {
                id: doneRow
                anchors.centerIn: parent
                spacing: Theme.space.sm
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "记"
                    color: Theme.textOnSeal
                    font.family: Theme.fontDisplay
                    font.pixelSize: 19
                    renderType: Text.NativeRendering
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Done"
                    color: Theme.textOnSeal
                    font.family: Theme.fontUi
                    font.pixelSize: Theme.fontFor("ui").pixelSize
                    font.weight: 600
                    renderType: Text.NativeRendering
                }
            }
            MouseArea {
                id: doneArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: form.closeAsked()
            }
        }
        InkText {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 40
            role: "small"; muted: true
            text: edit.length > form.svc.maxChars - 200 ? [...edit.text].length + " / " + form.svc.maxChars + " characters"
                                                         : "⏎ new line · esc done · ctrl+n new · ctrl+pgup/pgdn flip"
        }
    }
}
