import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets.Services

/*  ProjectsDialog — 工程 · the add / edit screen of the Projects card (namespace apothecary-projects).  A full-screen overlay like
 *  the brew dialog (OverlayWindow: scrim, centred panel, keyboard grabbed Exclusive while it is open), so typing works even though
 *  the widget layer itself never takes focus.  Opened by the card's Add button, a double-click on a title, SUPER+SHIFT+P,
 *  `apothecary projects open|edit`, `ipc call projects open|edit`; ShellState.projectsOpen / ProjectsService.editId drive it.
 *  The form is Projects/ProjectsForm.qml.  Enter = add / save · Esc or a click outside = cancel.
 */
Variants {
    id: root
    model: Quickshell.screens
    property bool onlyFocusedScreen: true      // previews render on a headless output

    OverlayWindow {
        id: win
        required property var modelData
        screen: modelData
        namespace: "apothecary-projects"
        onlyFocusedScreen: root.onlyFocusedScreen
        open: ShellState.projectsOpen
        onCloseRequested: ProjectsService.closeDialog()

        ProjectsForm {
            anchors.centerIn: parent
            active: win.shown
            editId: ProjectsService.editId
            onDone: ProjectsService.closeDialog()
            onCancelled: ProjectsService.closeDialog()
        }
    }
}
