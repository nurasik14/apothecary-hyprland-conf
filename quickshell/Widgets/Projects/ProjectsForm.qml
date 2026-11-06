import QtQuick
import qs.Common
import qs.Services
import qs.Widgets.Services

/*  ProjectsForm — the add / edit panel of the Projects card: Title (autofocus), Note (optional), "Already built" ink checkbox,
 *  Add / Save (Enter) and Cancel (Esc).  Used by ProjectsDialog (inside the apothecary-projects layer) and by the offscreen renders.
 *    active: bool        true while visible: resets the fields from the service (editId = "" → a new project) and focuses the title
 *    editId: string      the project being edited ("" = adding); edit mode adds the move up / down buttons
 *    signals done() (saved or added: the dialog closes)  cancelled()
 *  Keys: Enter (in a field) accepts · Tab next field · ↑/↓ in the title (editing) move the project · Esc cancels.
 */
Item {
    id: form
    property bool active: false
    property string editId: ""
    signal done()
    signal cancelled()

    readonly property var svc: ProjectsService
    property string loadedId: ""
    readonly property var editItem: loadedId.length ? svc.byId(loadedId) : null
    readonly property bool editing: editItem !== null
    property bool flagged: false
    property bool builtChecked: false
    readonly property alias titleField: titleField
    readonly property alias noteField: noteField

    width: panel.width
    height: panel.height + 40

    function load() {
        const it = form.editId.length ? svc.byId(form.editId) : null;
        form.loadedId = it ? it.id : "";
        titleField.text = it ? it.title : "";
        noteField.text = it ? (it.note || "") : "";
        form.builtChecked = it ? it.status === "built" : false;
        form.flagged = false;
        titleField.forceActiveFocus();
        titleField.input.selectAll();
    }
    onActiveChanged: if (active) load()
    onEditIdChanged: if (active) load()
    Connections {      // the list may arrive after the form (first load of the file): pick the project up then
        target: form.svc
        function onItemsChanged() {
            if (!form.active || !form.editId.length || form.editing) return;
            if (form.loadedId.length) form.cancelled();      // it was loaded and is gone now (removed by the CLI / the other theme): never turn Enter into an add
            else form.load();
        }
    }
    Component.onCompleted: if (active) load()

    function accept() {
        const t = svc.clean(titleField.text);
        if (!t.length) { form.flagged = true; flagReset.restart(); titleField.forceActiveFocus(); return; }
        if (form.editing) {
            const it = form.editItem;
            svc.rename(it.id, t, noteField.text);
            if ((it.status === "built") !== form.builtChecked) svc.setBuilt(it.id, form.builtChecked);
        } else {
            svc.add(t, noteField.text, form.builtChecked);
        }
        form.done();
    }
    function nav(from, key) {
        if (key === Qt.Key_Tab || (key === Qt.Key_Down && !form.editing)) {
            if (from === titleField) { noteField.forceActiveFocus(); noteField.input.selectAll(); }
            else { titleField.forceActiveFocus(); titleField.input.selectAll(); }
        } else if (key === Qt.Key_Up || key === Qt.Key_Down) {
            if (form.editing && form.editItem.status !== "built") form.svc.move(form.loadedId, key === Qt.Key_Up ? -1 : 1);
        }
    }
    Timer { id: flagReset; interval: 900; onTriggered: form.flagged = false }

    MouseArea { anchors.fill: panel }            // a click anywhere on the panel (title bar, padding, frame) must not reach the scrim

    PaperPanel {
        id: panel
        width: 460; height: 236
        title: "工程"
        subtitle: form.editing ? "Edit project" : "New project"
        sealGlyph: "印"
        radius: Theme.radius.lg
        padding: Theme.space.lg

        Column {
            anchors.fill: parent
            spacing: Theme.space.sm

            Row {
                width: parent.width
                spacing: Theme.space.md
                InkText { text: "Title"; role: "subtitle"; width: 48; anchors.verticalCenter: parent.verticalCenter }
                InkField {
                    id: titleField
                    width: parent.width - 48 - parent.spacing
                    icon: "󰏫"
                    error: form.flagged
                    placeholder: form.flagged ? "Give it a name" : "What are you building?"
                    onAccepted: form.accept()
                    onEscaped: form.cancelled()
                    onNavigate: key => form.nav(titleField, key)
                    input.maximumLength: 120
                }
            }
            Row {
                width: parent.width
                spacing: Theme.space.md
                InkText { text: "Note"; role: "subtitle"; width: 48; anchors.verticalCenter: parent.verticalCenter }
                InkField {
                    id: noteField
                    width: parent.width - 48 - parent.spacing
                    icon: "󰎞"
                    placeholder: "optional"
                    onAccepted: form.accept()
                    onEscaped: form.cancelled()
                    onNavigate: key => form.nav(noteField, key)
                    input.maximumLength: 240
                }
            }
            Row {
                x: 48 + Theme.space.md
                spacing: Theme.space.sm
                height: 28
                InkCheck {
                    id: builtBox
                    anchors.verticalCenter: parent.verticalCenter
                    checked: form.builtChecked
                    onClicked: { form.builtChecked = !form.builtChecked; titleField.forceActiveFocus(); }
                }
                InkText {
                    anchors.verticalCenter: parent.verticalCenter
                    role: "body"
                    text: form.editing ? "Built" : "Already built"
                    MouseArea { anchors.fill: parent; onClicked: { form.builtChecked = !form.builtChecked; titleField.forceActiveFocus(); } }
                }
                Item { width: Theme.space.lg; height: 1 }
                Row {   // reorder (editing, in-progress projects only: built ones are ordered by when they were built)
                    visible: form.editing && form.editItem.status !== "built"
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6
                    InkButton {
                        text: "Up"; icon: "󰁝"; quiet: true; implicitHeight: 24; horizontalPadding: 8
                        activeFocusOnTab: false
                        onClicked: form.svc.move(form.loadedId, -1)
                    }
                    InkButton {
                        text: "Down"; icon: "󰁅"; quiet: true; implicitHeight: 24; horizontalPadding: 8
                        activeFocusOnTab: false
                        onClicked: form.svc.move(form.loadedId, 1)
                    }
                }
            }

            InkDivider { width: parent.width; brush: true; height: 10 }

            Row {
                anchors.right: parent.right
                spacing: Theme.space.sm
                InkButton { text: "Cancel"; quiet: true; activeFocusOnTab: false; onClicked: form.cancelled() }
                InkButton {
                    text: form.editing ? "Save" : "Add"; icon: "󰆓"
                    primary: true
                    activeFocusOnTab: false
                    enabled: form.svc.clean(titleField.text).length > 0
                    onClicked: form.accept()
                }
            }
        }
    }
    InkText {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: panel.bottom; anchors.topMargin: Theme.space.lg
        role: "small"; muted: true
        text: "⏎ " + (form.editing ? "save" : "add") + " · tab next field" + (form.editing && form.editItem.status !== "built" ? " · ↑↓ move" : "") + " · esc close"
    }
}
