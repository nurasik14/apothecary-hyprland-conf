//@ pragma UseQApplication
import QtQuick
import QtQuick.Window
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets
import qs.Widgets.Projects
import qs.Widgets.Services

/*  Offscreen render of the Projects card / dialog (no compositor, nothing live is touched).  See scripts/projects-harness.sh in the
 *  report; env: HYPR_PROJECTS_FILE=<temp json> APO_RENDER_OUT=/tmp/x.png APO_RENDER_WHAT=card|undo|dialog|edit|act|layout
 *  [APO_RENDER_PIN=<row>] [APO_RENDER_FOLD=1] [APO_RENDER_ALL=1] [APO_RENDER_BG=<image>] [APO_RENDER_EDIT=<row>]
 *  HOME=<temp home with .config/apothecary/{mode,config.json} and .local/share/fonts → the real fonts> QT_QPA_PLATFORM=offscreen
 *  qs -p quickshell/Widgets/preview/projects-render.qml
 */
ShellRoot {
    id: root
    readonly property string what: Quickshell.env("APO_RENDER_WHAT") || "card"
    readonly property bool cardShot: what === "card" || what === "undo" || what === "act"
    Window {
        id: win
        width: root.what === "layout" ? 1920 : (root.cardShot ? 460 : 680)
        height: root.what === "layout" ? 1080 : (root.cardShot ? 290 : 420)
        visible: true
        color: Theme.isDark ? "#1c1a17" : "#cfc4aa"
        Image {
            anchors.fill: parent
            source: Quickshell.env("APO_RENDER_BG") ? "file://" + Quickshell.env("APO_RENDER_BG") : ""
            fillMode: Image.PreserveAspectCrop
        }
        Item {
            id: stage
            anchors.fill: parent
            ProjectsCard {
                id: card
                visible: root.cardShot || root.what === "layout"
                cardId: "projects"
                x: root.what === "layout" ? 340 : 30; y: root.what === "layout" ? 812 : 20
                defaultX: x; defaultY: y
                pinHover: parseInt(Quickshell.env("APO_RENDER_PIN") || "-1")
                builtOpen: Quickshell.env("APO_RENDER_FOLD") !== "1"
                builtAll: Quickshell.env("APO_RENDER_ALL") === "1"
            }
            Rectangle {
                anchors.fill: parent
                visible: root.what === "dialog" || root.what === "edit"
                color: Theme.overlay
            }
            ProjectsForm {
                id: form
                visible: root.what === "dialog" || root.what === "edit" || root.what === "form"
                anchors.centerIn: parent
                active: visible
                editId: root.what === "edit" && ProjectsService.ordered.length > parseInt(Quickshell.env("APO_RENDER_EDIT") || "0") ? ProjectsService.ordered[parseInt(Quickshell.env("APO_RENDER_EDIT") || "0")].id : ""
            }
        }
        Timer {
            interval: 1500
            running: root.what !== "act" && root.what !== "form"
            onTriggered: {
                if (root.what === "undo") { ProjectsService.remove(ProjectsService.items[1].id); undoShot.start(); return; }
                win.shoot();
            }
        }
        Timer { id: undoShot; interval: 900; onTriggered: win.shoot() }
        // APO_RENDER_WHAT=act: no picture; drives the card's own handlers (what a click on the box / ✕ / Undo ends in) and checks the result
        property int actStep: 0
        function pass(n, ok, x) { console.warn((ok ? "PASS " : "FAIL ") + n + (x !== undefined ? "  [" + x + "]" : "")); }
        Timer {
            id: actTimer; interval: 1100; running: root.what === "act"; repeat: true
            onTriggered: {
                const P = ProjectsService;
                if (win.actStep === 0) { win.pass("card shows the list", P.items.length === 7 && card.svc.inProgress.length === 4); card.toggleItem(P.inProgress[0]); }
                else if (win.actStep === 1) { win.pass("click on the box (toggleItem) → built; the seal cue was asked for", P.built.length === 4 && P.inProgress.length === 3 && card.lastSound === "seal", P.built.length + "/" + P.inProgress.length + " " + card.lastSound); card.toggleItem(P.built[0]); }
                else if (win.actStep === 2) { win.pass("click again → back in progress, no cue", P.inProgress.length === 4 && card.lastSound === ""); card.removeItem(P.inProgress[0]); }
                else if (win.actStep === 3) { win.pass("✕ (removeItem) removes and offers undo", P.items.length === 6 && P.undo !== null && card.svc.undo.title.length > 0); P.undoRemove(); }
                else if (win.actStep === 4) { win.pass("Undo button (undoRemove) restores it", P.items.length === 7 && P.undo === null); card.builtAll = true; }
                else if (win.actStep === 5) {
                    win.pass("+N more row only with > 5 built", card.hiddenBuilt === 0 && card.builtShown === P.built.length);
                    card.svc.openDialog(""); win.pass("Add button path (openDialog) sets ShellState.projectsOpen", P.dialogOpen && P.editId === "");
                    card.svc.closeDialog(); win.pass("closeDialog", !P.dialogOpen);
                    card.svc.openDialog(P.items[0].id); win.pass("edit path sets editId", P.dialogOpen && P.editId === P.items[0].id); card.svc.closeDialog();
                    win.pass("sounds are off in this run (nothing audible)", SoundService.play("seal") === false);
                    Qt.quit();
                }
                win.actStep++;
            }
        }
        // APO_RENDER_WHAT=form: drives the add / edit form's own functions (what Enter, Tab and the buttons end in) against the temp list
        property int formStep: 0
        Timer {
            id: formTimer; interval: 900; running: root.what === "form"; repeat: true
            onTriggered: {
                const P = ProjectsService;
                if (win.formStep === 0) {
                    win.pass("form starts empty for a new project", form.active && !form.editing && form.titleField.text === "" && form.titleField.activeFocus);
                    form.accept(); win.pass("Enter on an empty title is refused and flags the field", form.flagged && P.items.length === 7);
                    form.titleField.text = "  New   thing "; form.noteField.text = " a  note "; form.builtChecked = true; form.accept();
                } else if (win.formStep === 1) {
                    const it = P.find("New thing").item;
                    win.pass("accept adds a built project (title + note collapsed)", P.items.length === 8 && !!it && it.status === "built" && it.note === "a note", P.items.length);
                    form.editId = it.id;
                } else if (win.formStep === 2) {
                    win.pass("editId loads the project into the fields", form.editing && form.titleField.text === "New thing" && form.noteField.text === "a note" && form.builtChecked);
                    form.nav(form.titleField, Qt.Key_Tab); win.pass("Tab moves to the note field", form.noteField.activeFocus);
                    form.nav(form.noteField, Qt.Key_Tab); win.pass("Tab again wraps to the title", form.titleField.activeFocus);
                    form.titleField.text = "Renamed"; form.noteField.text = ""; form.builtChecked = false; form.accept();
                } else if (win.formStep === 3) {
                    const it = P.byId(form.loadedId);
                    win.pass("save renames, drops the note and un-builds", !!it && it.title === "Renamed" && it.note === undefined && it.status === "progress", it && it.title + "/" + it.status);
                    const before = P.items.findIndex(i => i.id === it.id);
                    form.nav(form.titleField, Qt.Key_Up);
                    win.pass("↑ in the title moves the project up (editing)", true);
                    win.formBefore = before;
                } else if (win.formStep === 4) {
                    win.pass("…and it really moved (swapped with the last in-progress item, never into the built section)", P.items.findIndex(i => i.id === form.loadedId) === 3, win.formBefore + " → " + P.items.findIndex(i => i.id === form.loadedId));
                    Qt.quit();
                }
                win.formStep++;
            }
        }
        property int formBefore: 0
        function shoot() {
            win.contentItem.grabToImage(function (r) {
                const out = Quickshell.env("APO_RENDER_OUT") || "/tmp/apo-projects.png";
                console.warn("render: saved", r.saveToFile(out), out);
                Qt.quit();
            });
        }
    }
}
