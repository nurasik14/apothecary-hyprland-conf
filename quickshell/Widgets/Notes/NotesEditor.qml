import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets.Services
import "NotesPlace.js" as NotesPlace

/*  NotesEditor — 札记 · the layer you type on (namespace apothecary-notes), a full-screen overlay like the brew and Projects dialogs (OverlayWindow:
 *  scrim, click outside closes, keyboard grabbed Exclusive), because the widget layer never takes focus.  The slip opens right over the card's
 *  paper, somewhat larger, so it feels like writing on the note itself; with the card hidden it opens in the middle of the screen.
 *  Opened by a click on the card, its +, SUPER+ALT+N, `apothecary notes open|new`, `ipc call notes open|newSheet`; NotesService.editorOpen drives it.
 *  The slip itself is Notes/NotesForm.qml.
 */
Variants {
    id: root
    model: Quickshell.screens
    property bool onlyFocusedScreen: true      // previews render on a headless output
    Component.onDestruction: NotesService.flushNow()     // a shell reload or quit: nothing typed is lost (see NotesService)

    OverlayWindow {
        id: win
        required property var modelData
        screen: modelData
        namespace: "apothecary-notes"
        onlyFocusedScreen: root.onlyFocusedScreen
        open: NotesService.editorOpen
        onCloseRequested: NotesService.closeEditor()

        readonly property var rect: NotesService.cardRects[modelData.name] || null

        NotesForm {
            readonly property var place: NotesPlace.place(win.rect, parent.width, parent.height, width, height, 2, Theme.space.xl)
            x: place.x; y: place.y
            active: win.shown
            onCloseAsked: NotesService.closeEditor()
        }
    }
}
