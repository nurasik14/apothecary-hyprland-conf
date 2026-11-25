import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets.Services
import "CalendarPlace.js" as CalendarPlace

/*  CalendarEditor — 日程 · the layer you type a new event on (namespace apothecary-calendar), a full-screen overlay like the Notes editor and
 *  the Projects dialog (OverlayWindow: scrim, click outside closes, keyboard grabbed Exclusive), because the widget layer never takes focus.
 *  The panel opens right over the Calendar card; with the card hidden it opens in the middle of the screen.  ShellState.calendarOpen drives it
 *  (so it is one modal among the others): a double-click on a day, the + of the agenda, `apothecary calendar card newEvent`.
 *  The panel itself is Calendar/CalendarForm.qml.
 */
Variants {
    id: root
    model: Quickshell.screens
    property bool onlyFocusedScreen: true      // previews render on a headless output

    OverlayWindow {
        id: win
        required property var modelData
        screen: modelData
        namespace: "apothecary-calendar"
        onlyFocusedScreen: root.onlyFocusedScreen
        open: ShellState.calendarOpen
        onCloseRequested: CalendarService.closeAdd()

        readonly property var rect: CalendarService.cardRects[modelData.name] || null

        CalendarForm {
            readonly property var place: CalendarPlace.place(win.rect, parent.width, parent.height, width, height, 2, Theme.space.xl)
            x: place.x; y: place.y
            active: win.shown
            onCloseAsked: CalendarService.closeAdd()
        }
    }
}
