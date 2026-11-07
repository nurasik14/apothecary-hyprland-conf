//@ pragma UseQApplication
import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets
import qs.Widgets.Notes
import qs.Widgets.Services

/*  Offscreen render of the Notes card or its editor, and a driver of the real handlers (no compositor, nothing live is touched).  env:
 *      HYPR_NOTES_FILE=<temp json> HYPR_NOTES_QUIET=1 APO_RENDER_OUT=/tmp/x.png APO_RENDER_WHAT=card|undo|edit|act [APO_RENDER_PIN=1] [APO_RENDER_FLIP=n]
 *      [APO_RENDER_NEW=1] [APO_RENDER_LATE=ms] [APO_RENDER_BG=<image>] [APO_RENDER_SCROLL=1]
 *      HOME=<temp home with .config/apothecary/{mode,config.json} and .local/share/fonts → the real fonts> QT_QPA_PLATFORM=offscreen
 *      qs -p quickshell/Widgets/preview/notes-render.qml
 *  card/undo = the card; edit = the form as it sits over the card, on the scrim; act = no picture, real key and mouse events (QtTest's TestEvent, delivered
 *  to this offscreen window only) through the form and the card, PASS / FAIL lines, then "notes-render act done: N failed".  The pad must hold 3 sheets.
 */
ShellRoot {
    id: root
    readonly property string what: Quickshell.env("APO_RENDER_WHAT") || "card"
    readonly property bool cardView: what === "card" || what === "undo"
    Window {
        id: win
        width: root.cardView ? 330 : 520
        height: root.cardView ? 300 : 460
        visible: true
        Rectangle { anchors.fill: parent; color: Theme.isDark ? "#1c1a17" : "#cfc4aa" }    // a grab leaves out the window's own colour
        Image {
            anchors.fill: parent
            source: Quickshell.env("APO_RENDER_BG") ? "file://" + Quickshell.env("APO_RENDER_BG") : ""
            fillMode: Image.PreserveAspectCrop
        }
        Item {
            id: stage
            anchors.fill: parent
            NotesCard {
                id: card
                cardId: "notes"
                x: 30; y: 20
                defaultX: 30; defaultY: 20
                pinHover: Quickshell.env("APO_RENDER_PIN") === "1"
                screenName: "render"
            }
            Rectangle { anchors.fill: parent; visible: NotesService.editorOpen; color: Theme.overlay }
            MouseArea {        // the layer's "click outside"
                anchors.fill: parent
                enabled: NotesService.editorOpen
                onClicked: NotesService.closeEditor()
            }
            NotesForm {
                id: form
                visible: NotesService.editorOpen
                x: 90; y: 40
                active: NotesService.editorOpen
                onCloseAsked: NotesService.closeEditor()
            }
        }
        Timer {
            interval: 1200
            running: root.what !== "act"
            onTriggered: {
                const flip = parseInt(Quickshell.env("APO_RENDER_FLIP") || "0");
                if (flip) NotesService.goTo(NotesService.sheets[flip - 1].id);
                if (root.what === "undo") { card.tearOff(); late.start(); return; }
                if (root.what === "edit") { NotesService.openEditor(Quickshell.env("APO_RENDER_NEW") === "1" ? "new" : "current"); late.start(); return; }
                late.interval = 200; late.start();
            }
        }
        Timer { id: late; interval: parseInt(Quickshell.env("APO_RENDER_LATE") || "800"); onTriggered: win.shoot() }
        function shoot() {
            win.contentItem.grabToImage(function (r) {
                const out = Quickshell.env("APO_RENDER_OUT") || "/tmp/apo-notes.png";
                console.warn("render: saved", r.saveToFile(out), out);
                Qt.quit();
            });
        }

        // ---------------------------------------------------------------- APO_RENDER_WHAT=act
        TestEvent { id: ev }
        property int fails: 0
        function pass(n, ok, x) { console.warn((ok ? "PASS " : "FAIL ") + n + (x !== undefined ? "  [" + x + "]" : "")); if (!ok) win.fails++; }
        function typeText(s) {
            for (let i = 0; i < s.length; i++) ev.keyClickChar(s[i], Qt.NoModifier, -1);
        }
        function clickOn(item, xx, yy) {
            const p = item.mapToItem(null, xx === undefined ? item.width / 2 : xx, yy === undefined ? item.height / 2 : yy);
            ev.mouseClick(win.contentItem, p.x, p.y, Qt.LeftButton, Qt.NoModifier, -1);
        }
        function hoverOn(item) {
            const p = item.mapToItem(null, item.width / 2, item.height / 2);
            ev.mouseMove(win.contentItem, p.x, p.y, -1, Qt.NoButton, Qt.NoModifier);
        }
        function wheelOn(item, xx, yy, dy) {
            const p = item.mapToItem(null, xx, yy);
            ev.mouseWheel(win.contentItem, p.x, p.y, Qt.NoButton, Qt.NoModifier, 0, dy, -1);
        }
        function textOf() { return form.textEdit.text; }
        property int actStep: 0
        property int flipFrom: 0
        property int keptCount: 0
        property int seedOpen: 0
        property string pageOpen: ""
        Timer { id: secondTear; interval: 250; onTriggered: card.tearOff() }
        readonly property var svc: NotesService
        readonly property var acts: [
            () => { win.pass("harness: 3 sheets", win.svc.count === 3, win.svc.count); win.clickOn(card.slipItem, 60, 70); },
            () => {
                win.pass("a click on the slip opens the editor on the current sheet", win.svc.editorOpen && win.svc.draftText === win.svc.current.text, win.svc.draftText);
                win.pass("ShellState knows the modal", ShellState.notesOpen && ShellState.anyOpen);
                win.pass("the text has the keyboard", form.textEdit.activeFocus);
                win.pass("cursor at the end", form.textEdit.cursorPosition === form.textEdit.length);
                win.typeText("ab");
                ev.keyClick(Qt.Key_Return, Qt.NoModifier, -1);
                win.typeText("cd");
            },
            () => {
                win.pass("typing reaches the slip; Enter is a newline", win.svc.draftText.endsWith("ab\ncd"), JSON.stringify(win.svc.draftText));
                win.pass("not closed by Enter", win.svc.editorOpen);
                ev.keyClick(Qt.Key_N, Qt.ControlModifier, -1);
            },
            () => {
                win.pass("Ctrl+N: a blank sheet", win.svc.draftText === "" && textOf() === "" && !win.svc.draftInFile);
                win.pass("…the sheet before it was saved", win.svc.sheets.some(s => s.text.endsWith("ab\ncd")));
                win.pass("…page 4 of 4", win.svc.draftPage === 4 && win.svc.draftPages === 4, win.svc.draftPage + "/" + win.svc.draftPages);
                win.typeText("newest");
            },
            () => {
                ev.keyClick(Qt.Key_PageUp, Qt.ControlModifier, -1);
            },
            () => {
                win.pass("Ctrl+PgUp flips back and saves", win.svc.draftPage === 3 && textOf() === win.svc.sheets[2].text && win.svc.sheets[3].text === "newest", win.svc.draftPage);
                ev.keyClick(Qt.Key_PageDown, Qt.ControlModifier, -1);
            },
            () => {
                win.pass("Ctrl+PgDn flips forward", win.svc.draftPage === 4 && textOf() === "newest", win.svc.draftPage);
                ev.keyClick(Qt.Key_Return, Qt.ControlModifier, -1);
            },
            () => {
                win.pass("Ctrl+Enter closes", !win.svc.editorOpen && !ShellState.notesOpen);
                win.clickOn(card.slipItem, 60, 70);
            },
            () => {
                win.pass("open again", win.svc.editorOpen);
                ev.keyClick(Qt.Key_Escape, Qt.NoModifier, -1);
            },
            () => {
                win.pass("Esc closes", !win.svc.editorOpen);
                win.clickOn(card.slipItem, 60, 70);
            },
            () => {
                ev.mouseClick(win.contentItem, win.width - 4, 4, Qt.LeftButton, Qt.NoModifier, -1);
            },
            () => {
                win.pass("a click outside closes", !win.svc.editorOpen);
                win.clickOn(card.slipItem, 60, 70);
            },
            () => {
                win.clickOn(form, form.width / 2, 120);
                win.pass("a click on the slip does not close it", win.svc.editorOpen);
                win.clickOn(form.doneButton);
            },
            () => {
                win.pass("the 记 Done seal closes", !win.svc.editorOpen);
                win.clickOn(card.slipItem, 60, 70);
            },
            () => {
                win.clickOn(form.prevButton);
            },
            () => {
                win.pass("◀ under the slip flips the draft", win.svc.draftPage === 3 && textOf() === win.svc.sheets[2].text, win.svc.draftPage);
                win.clickOn(form.nextButton);
            },
            () => {
                win.pass("▶ under the slip flips back", win.svc.draftPage === 4, win.svc.draftPage);
                win.clickOn(form.newButton);
            },
            () => {
                win.pass("+ under the slip gives a blank sheet", win.svc.draftText === "" && !win.svc.draftInFile);
                win.pass("…the keyboard is back on the slip", form.textEdit.activeFocus);
                ev.keyClick(Qt.Key_PageUp, Qt.ControlModifier, -1);
            },
            () => {
                form.textEdit.selectAll();
                ev.keyClick(Qt.Key_Delete, Qt.NoModifier, -1);
                win.pass("select all + Delete empties it", textOf() === "" && win.svc.draftText === "");
                ev.keyClick(Qt.Key_Escape, Qt.NoModifier, -1);
            },
            () => {
                win.pass("an emptied sheet is dropped on close, undo offered", win.svc.count === 3 && win.svc.undo !== null, win.svc.count);
                win.svc.undoRemove();
            },
            () => {
                win.pass("undo restores", win.svc.count === 4, win.svc.count);
                win.svc.goTo(win.svc.sheets[3].id);
                win.pass("flipBy off the end does nothing", (card.flipBy(1), win.svc.currentIndex === win.svc.count - 1));
                card.wheelBy(60); card.wheelBy(60);
            },
            () => {
                win.pass("two half notches of wheel flip one sheet back", win.svc.currentIndex === win.svc.count - 2, win.svc.currentIndex);
                card.wheelBy(-120);
            },
            () => {
                win.pass("a notch the other way flips forward", win.svc.currentIndex === win.svc.count - 1, win.svc.currentIndex);
                win.wheelOn(card.slipItem, 60, 70, 120);
            },
            () => {
                win.pass("a real wheel event over the slip flips", win.svc.currentIndex === win.svc.count - 2, win.svc.currentIndex);
                win.wheelOn(card, 8, 100, -120);
            },
            () => {
                win.pass("…and over the card's padding too", win.svc.currentIndex === win.svc.count - 1, win.svc.currentIndex);
                win.hoverOn(card.slipItem);
            },
            () => {
                win.pass("hover on the card shows the ✕", card.hot);
                win.clickOn(card.tearButton);
            },
            () => {
                win.pass("a click on the ✕ tears the sheet off, without opening the editor", win.svc.count === 3 && win.svc.undo !== null && !win.svc.editorOpen, win.svc.count);
                win.pass("…the seal cue was asked for; nothing audible in this run", card.lastSound === "seal" && SoundService.play("seal") === false);
                win.clickOn(card.undoButton);
            },
            () => {
                win.pass("the Undo slip's button brings it back", win.svc.count === 4 && win.svc.undo === null, win.svc.count);
                win.clickOn(card.newButton);
            },
            () => {
                win.pass("the + button opens a blank sheet", win.svc.editorOpen && win.svc.draftText === "" && !win.svc.draftInFile);
                ev.keyClick(Qt.Key_Escape, Qt.NoModifier, -1);
            },
            () => {
                win.pass("nothing typed: nothing added", win.svc.count === 4 && !win.svc.editorOpen);
                win.flipFrom = win.svc.currentIndex;
                win.clickOn(card.prevButton);
            },
            () => {
                win.pass("◀ flips back", win.svc.currentIndex === win.flipFrom - 1, win.svc.currentIndex);
                win.clickOn(card.nextButton);
            },
            () => {
                win.pass("▶ flips forward", win.svc.currentIndex === win.flipFrom, win.svc.currentIndex);
                win.svc.removeCurrent();
            },
            () => {
                win.flipFrom = win.svc.currentIndex;
                const p = card.prevButton.mapToItem(null, card.prevButton.width / 2, card.prevButton.height / 2);
                ev.mouseClick(win.contentItem, p.x, p.y, Qt.LeftButton, Qt.NoModifier, -1);     // ◀ is under the Undo slip
            },
            () => {
                win.pass("a click on the Undo slip does not reach the pager under it", win.svc.currentIndex === win.flipFrom, win.svc.currentIndex);
                win.svc.undoRemove();
            },
            () => {
                win.keptCount = win.svc.count;
                card.tearOff();
                secondTear.start();                                               // the next sheet is on the card by then: a slow double click
            },
            () => {
                win.pass("a double click on the ✕ tears off one sheet", win.svc.count === win.keptCount - 1 && win.svc.undo !== null && win.svc.undo.count === 1, win.svc.count + "/" + win.keptCount);
                win.svc.undoRemove();
            },
            () => {
                const seed = form.slipSeed;
                win.svc.openEditor("current");
                win.seedOpen = form.slipSeed;
                win.pageOpen = form.page + "/" + form.pages;
                win.pass("the slip takes the sheet's own torn edge", seed !== undefined && form.slipSeed === win.svc.draftId.charCodeAt(win.svc.draftId.length - 1) + win.svc.draftId.charCodeAt(win.svc.draftId.length - 2) * 31);
                win.svc.closeEditor();
                win.pass("closing does not re-tear the slip or change its page under the fade", form.slipSeed === win.seedOpen && form.page + "/" + form.pages === win.pageOpen, form.slipSeed + " " + form.page + "/" + form.pages);
            },
            () => {
                win.svc.openEditor("new");
            },
            () => {
                const e = form.textEdit;
                e.text = "A" + "m".repeat(3996) + "END";                           // full, 4000
                e.cursorPosition = 1;
                e.insert(1, "PASTED-IN");
                win.pass("full: a paste is refused, the end of the note stays", e.text.length === 4000 && e.text.endsWith("END") && e.text.indexOf("PASTED") < 0, e.text.length + " " + e.text.slice(-3));
                win.pass("…the draft has the same", win.svc.draftText === e.text);
                e.text = "🦊".repeat(3999);
                e.insert(e.length, "🦊🦊🦊");
                win.pass("full counts characters: emoji are not cut in half", [...e.text].length === 4000 && e.length === 8000, e.length);
                ev.keyClick(Qt.Key_Escape, Qt.NoModifier, -1);
                console.warn("notes-render act done: " + win.fails + " failed");
                Qt.quit();
            }
        ]
        Timer {
            interval: 450; repeat: true; running: root.what === "act"
            onTriggered: {
                if (win.actStep >= win.acts.length) return;
                const f = win.acts[win.actStep++];
                f();
            }
        }
    }
}
