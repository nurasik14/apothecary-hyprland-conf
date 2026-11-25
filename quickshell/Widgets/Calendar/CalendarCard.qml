import QtQuick
import qs.Common
import qs.Services
import qs.Widgets
import qs.Widgets.Services

/*  CalendarCard — 日历 · CALENDAR (380 × 260): the month on paper with the user's Google Calendar events.
 *  Header: "November 2026 · 十一月" and the arrows.  Under it, while no day is selected, one line: what is next ("Next: 14:00 Lab", the
 *  vermilion seal-red when it starts within 15 min, and how many are left today).  Then the month: weekends in `accent2`, today = the seal
 *  stamped behind the number, and a few ink drops under every day that has events (tag ink, hollow = all day).
 *    hover a day            an ink wash and a paper slip listing that day's events
 *    click a day            select it (a brushed ink ring): the month folds into its week and the agenda of that day opens below (the wheel
 *                           scrolls it); click an event to open it in the browser; ▲ shows the month again
 *    double-click a day / + quick-add on that day (Calendar/CalendarEditor.qml, a layer that takes the keyboard)
 *    arrows / wheel over the grid   change month  ·  in the week view: the week  ·  click the month name: back to today
 *  Footer: when the events were last synced (click = sync now); offline keeps showing the saved events; "Not connected" until Google is set up.
 *  State (month, selected day, adding) lives in CalendarService, so IPC `calendar …` drives the same card on every screen.  Week starts Monday.
 */
WidgetCard {
    id: card
    title: "日历"
    subtitle: "Calendar"
    sealGlyph: "印"
    width: 380
    height: 260
    padding: 12

    property string screenName: ""             // DesktopWidgets: which output's rectangle this card publishes (the quick-add layer opens over it)
    property string pinDay: ""                 // previews only: draw this day / the nth agenda row as hovered
    property int pinRow: -1
    readonly property var svc: CalendarService
    readonly property alias monthGrid: grid         // for the render harness' real-event tests
    readonly property alias weekRow: week
    readonly property alias agendaList: list
    readonly property alias agendaFlick: flick
    readonly property alias nextStrip: strip
    readonly property alias addButton: addBtn
    readonly property alias monthButton: monthBtn
    readonly property alias monthTitle: monthText
    readonly property alias prevButton: prevBtn
    readonly property alias nextButton: nextBtn

    property date today: new Date()
    readonly property int year: svc.year
    readonly property int month: svc.month        // 0-based
    readonly property bool agenda: svc.expanded
    readonly property var cjkMonths: ["一月", "二月", "三月", "四月", "五月", "六月", "七月", "八月", "九月", "十月", "十一月", "十二月"]
    readonly property var dow: ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    readonly property string todayKey: svc.dayKey(today)
    readonly property bool isCurrentMonth: year === today.getFullYear() && month === today.getMonth()
    readonly property real cellW: 356 / 7
    readonly property int rowH: 20

    Timer { interval: 10000; running: card.visible; repeat: true; triggeredOnStart: true; onTriggered: card.today = new Date() }

    // where the card is on the output: the quick-add layer opens right over it
    readonly property var cardRect: ({ x: card.x, y: card.y, w: card.width, h: card.height, shown: card.shown })
    onCardRectChanged: svc.setCardRect(screenName, cardRect)
    onScreenNameChanged: svc.setCardRect(screenName, cardRect)

    property real wheelRest: 0
    function wheelBy(dy, step) {               // a notch is 120; a touchpad's small steps add up to one
        wheelRest += dy;
        if (Math.abs(wheelRest) < 120) return;
        const d = wheelRest > 0 ? -1 : 1;
        wheelRest = 0;
        step(d);
    }
    function pick(key) { svc.selectDay(key); }
    function addOn(key) { svc.openAdd(key); }
    // A click in the month folds the grid into the week, so the second click of a double-click would land on something else: for one double-click
    // interval an invisible catcher sits over the slot that was clicked, and a click on it is the double-click (quick-add for that day).
    property var dbl: null                      // {key, x, y, w, h} in card coordinates
    function pickGrid(key, cell) {
        const p = cell.mapToItem(card, 0, 0);
        card.dbl = { key: key, x: p.x, y: p.y, w: cell.width, h: cell.height };
        dblTimer.restart();
        svc.selectDay(key);
    }
    Timer { id: dblTimer; interval: Qt.styleHints.mouseDoubleClickInterval; onTriggered: card.dbl = null }
    MouseArea {
        parent: card
        z: 1000
        enabled: card.dbl !== null
        x: card.dbl ? card.dbl.x : 0; y: card.dbl ? card.dbl.y : 0
        width: card.dbl ? card.dbl.w : 0; height: card.dbl ? card.dbl.h : 0
        onClicked: { const k = card.dbl.key; card.dbl = null; dblTimer.stop(); card.addOn(k); }
    }

    readonly property var cells: {   // 42 cells, Monday first
        const first = new Date(year, month, 1);
        const lead = (first.getDay() + 6) % 7;
        const daysIn = new Date(year, month + 1, 0).getDate();
        const out = [];
        for (let i = 0; i < 42; i++) {
            const n = i - lead + 1;
            const d = new Date(year, month, n);
            out.push({ d: d.getDate(), inMonth: n >= 1 && n <= daysIn, key: svc.dayKey(d) });
        }
        return out;
    }
    readonly property var weekCells: {   // the week of the selected day
        if (!svc.expanded) return [];
        const s = svc.keyDate(svc.selectedDay);
        const mon = new Date(s.getFullYear(), s.getMonth(), s.getDate() - ((s.getDay() + 6) % 7));
        const out = [];
        for (let i = 0; i < 7; i++) {
            const d = new Date(mon.getFullYear(), mon.getMonth(), mon.getDate() + i);
            out.push({ d: d.getDate(), inMonth: d.getMonth() === month, key: svc.dayKey(d) });
        }
        return out;
    }
    readonly property var dayEvents: svc.expanded ? svc.eventsOn(svc.selectedDay) : []

    // a hover slip for a small button
    component ButtonTip: Loader {
        id: bt
        property Item host
        property string label: ""
        property string hint: ""
        active: host !== null && host.hovered
        sourceComponent: SlipTip { title: label; hint: bt.hint; maxWidth: 220; target: host; targetX: host.width / 2; targetY: host.height }
    }

    // ---- header: month · CJK month, arrows
    Item {
        id: header
        anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
        height: 24
        Row {
            anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.space.sm
            InkText {
                id: monthText
                role: "title"
                text: new Date(card.year, card.month, 1).toLocaleDateString(Qt.locale("en_GB"), "MMMM yyyy")
                color: monthHover.containsMouse && !card.isCurrentMonth ? Theme.seal : Theme.text
                anchors.verticalCenter: parent.verticalCenter
                MouseArea { id: monthHover; anchors.fill: parent; hoverEnabled: true; cursorShape: card.isCurrentMonth ? Qt.ArrowCursor : Qt.PointingHandCursor; onClicked: card.svc.goToday() }
            }
            Rectangle { width: 1; height: 12; color: Theme.hairline; anchors.verticalCenter: parent.verticalCenter }
            Text {
                text: card.cjkMonths[card.month]
                color: Theme.seal
                font.family: Theme.fontDisplay
                font.pixelSize: 20
                renderType: Text.NativeRendering
                anchors.verticalCenter: parent.verticalCenter
                Behavior on color { ColorAnimation { duration: Theme.durTheme } }
            }
        }
        Row {
            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
            spacing: 2
            InkButton {
                id: prevBtn
                quiet: true; icon: "󰅁"; implicitHeight: 24; implicitWidth: 26
                onClicked: card.agenda ? card.svc.shiftSelected(-7) : card.svc.shiftMonth(-1)
                ButtonTip { host: prevBtn; label: card.agenda ? "Previous week" : "Previous month" }
            }
            InkButton {
                id: todayBtn
                quiet: true; icon: "󰋜"; implicitHeight: 24; implicitWidth: 26
                visible: !card.isCurrentMonth
                onClicked: card.svc.goToday()
                ButtonTip { host: todayBtn; label: "Today" }
            }
            InkButton {
                id: nextBtn
                quiet: true; icon: "󰅂"; implicitHeight: 24; implicitWidth: 26
                onClicked: card.agenda ? card.svc.shiftSelected(7) : card.svc.shiftMonth(1)
                ButtonTip { host: nextBtn; label: card.agenda ? "Next week" : "Next month" }
            }
        }
    }

    // ---- under the title: what is next (no day selected)
    Item {
        id: strip
        visible: !card.agenda
        y: 26; width: parent.width; height: 16
        readonly property var info: card.svc.nextInfo
        readonly property string st: card.svc.state
        readonly property bool notConfigured: st === "not-configured"
        readonly property string text: notConfigured ? "Connect Google Calendar"
                                     : info.event ? info.text
                                     : (st === "loading" ? "Loading events…" : "Nothing planned")
        Rectangle {      // the mark before the line: a vermilion drop when it is soon, ink when it is next, hollow when there is nothing
            id: mark
            x: 1; anchors.verticalCenter: parent.verticalCenter
            width: 6; height: 6; radius: 3
            color: strip.info.soon || strip.info.now ? Theme.seal : (strip.info.event ? Theme.textMuted : "transparent")
            border.width: strip.info.event ? 0 : 1
            border.color: Theme.hairline
        }
        Text {
            id: stripText
            x: 14
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 14 - (leftText.visible ? leftText.width + 8 : 0)
            text: strip.text
            elide: Text.ElideRight
            textFormat: Text.PlainText
            color: strip.notConfigured ? Theme.warning : strip.info.soon ? Theme.seal : strip.info.event && !strip.info.now ? Theme.text : Theme.textMuted
            font.family: Theme.fontBody
            font.pixelSize: 13
            font.weight: strip.info.soon ? 600 : 400
            renderType: Text.NativeRendering
        }
        Text {
            id: leftText
            visible: strip.info.left > 0 && !strip.notConfigured
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: strip.info.left + " left today"
            color: Theme.textMuted
            font.family: Theme.fontUi
            font.pixelSize: 11
            renderType: Text.NativeRendering
        }
        MouseArea {
            id: stripArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: strip.info.event ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: if (strip.info.event) card.pick(strip.info.event.day <= card.todayKey ? card.todayKey : strip.info.event.day)
        }
        Loader {
            active: stripArea.containsMouse && (strip.notConfigured || strip.info.event)
            sourceComponent: SlipTip {
                title: strip.notConfigured ? "Connect Google Calendar" : strip.info.event.title
                body: strip.notConfigured ? "Run: apothecary help calendar" : card.svc.lineOf(strip.info.event, strip.info.event.day)
                hint: strip.notConfigured ? "" : "Click: open that day"
                target: stripArea; targetX: stripArea.mouseX; targetY: stripArea.mouseY
            }
        }
    }

    // ---- weekday header
    Row {
        id: dowRow
        y: card.agenda ? 26 : 44
        width: parent.width
        Repeater {
            model: card.dow
            delegate: Item {
                required property string modelData
                required property int index
                width: card.cellW; height: 14
                InkText {
                    anchors.centerIn: parent
                    role: "small"; font.pixelSize: 11
                    color: index >= 5 ? Theme.accent2 : Theme.textMuted
                    text: modelData
                }
            }
        }
    }
    InkDivider { anchors.left: parent.left; anchors.right: parent.right; y: dowRow.y + 15 }

    // ---- the month: 42 days
    MouseArea {
        x: 0; y: grid.y; width: grid.width; height: grid.height
        visible: !card.agenda
        acceptedButtons: Qt.NoButton
        onWheel: wheel => card.wheelBy(wheel.angleDelta.y, d => card.svc.shiftMonth(d))
    }
    Grid {
        id: grid
        visible: !card.agenda
        y: 61
        columns: 7
        Repeater {
            model: card.agenda ? [] : card.cells
            delegate: DayCell {
                id: monthCell
                required property var modelData
                required property int index
                width: card.cellW; height: card.rowH
                key: modelData.key
                day: modelData.d
                inMonth: modelData.inMonth
                weekend: index % 7 >= 5
                isToday: modelData.key === card.todayKey
                selected: modelData.key === card.svc.selectedDay
                pinHover: card.pinDay === modelData.key
                onClicked: key => card.pickGrid(key, monthCell)
                onDoubleClicked: key => card.addOn(key)
            }
        }
    }

    // ---- the week of the selected day
    MouseArea {
        x: 0; y: week.y; width: week.width; height: week.height
        visible: card.agenda
        acceptedButtons: Qt.NoButton
        onWheel: wheel => card.wheelBy(wheel.angleDelta.y, d => card.svc.shiftSelected(7 * d))
    }
    Row {
        id: week
        visible: card.agenda
        y: 43
        Repeater {
            model: card.weekCells
            delegate: DayCell {
                required property var modelData
                required property int index
                width: card.cellW; height: card.rowH
                key: modelData.key
                day: modelData.d
                inMonth: modelData.inMonth
                weekend: index >= 5
                isToday: modelData.key === card.todayKey
                selected: modelData.key === card.svc.selectedDay
                pinHover: card.pinDay === modelData.key
                onClicked: key => card.pick(key)
                onDoubleClicked: key => card.addOn(key)
            }
        }
    }

    // ---- the agenda of the selected day
    Item {
        id: head
        visible: card.agenda
        y: 64; width: parent.width; height: 20
        Text {
            id: headDay
            anchors.verticalCenter: parent.verticalCenter
            text: card.agenda ? card.svc.fmtDay(card.svc.selectedDay, "dddd d MMM") : ""
            color: Theme.text
            font.family: Theme.fontSerifBody
            font.pixelSize: 15
            font.weight: 600
            renderType: Text.NativeRendering
        }
        Text {
            anchors.left: headDay.right; anchors.leftMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            text: card.dayEvents.length === 0 ? "no events" : card.dayEvents.length + (card.dayEvents.length === 1 ? " event" : " events")
            color: Theme.textMuted
            font.family: Theme.fontUi
            font.pixelSize: 11
            renderType: Text.NativeRendering
        }
        Row {
            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
            spacing: 2
            InkButton {
                id: monthBtn
                quiet: true; icon: "󰅃"; implicitHeight: 20; implicitWidth: 26
                onClicked: card.svc.deselect()
                ButtonTip { host: monthBtn; label: "Show the month" }
            }
            InkButton {
                id: addBtn
                quiet: true; icon: "󰐕"; implicitHeight: 20; implicitWidth: 26
                onClicked: card.addOn(card.svc.selectedDay)
                ButtonTip { host: addBtn; label: "Add an event"; hint: "Double-click a day too" }
            }
        }
    }
    Flickable {
        id: flick
        visible: card.agenda
        y: 86; width: parent.width; height: 100      // five rows of 20
        contentWidth: width
        contentHeight: list.height
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        readonly property bool scrollable: contentHeight > height
        Column {
            id: list
            Repeater {
                model: card.dayEvents
                delegate: AgendaRow {
                    required property var modelData
                    required property int index
                    event: modelData
                    day: card.svc.selectedDay
                    width: flick.scrollable ? flick.width - 8 : flick.width
                    pinHover: card.pinRow === index
                    onOpened: id => card.svc.openEvent(id)
                }
            }
        }
    }
    Rectangle {      // the scroll mark: a thin ink bar
        visible: card.agenda && flick.scrollable
        x: parent.width - 4; width: 3; radius: 1.5
        y: flick.y + 2 + (flick.height - 4 - height) * (flick.contentHeight > flick.height ? flick.contentY / (flick.contentHeight - flick.height) : 0)
        height: Math.max(14, (flick.height - 4) * flick.height / Math.max(1, flick.contentHeight))
        color: Theme.hairline
    }
    Text {      // an empty day, or why there is nothing
        visible: card.agenda && card.dayEvents.length === 0
        x: 0; y: flick.y + 20; width: parent.width
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.Wrap
        color: Theme.textMuted
        font.family: Theme.fontBody
        font.pixelSize: 13
        renderType: Text.NativeRendering
        text: card.svc.state === "not-configured" ? "Connect Google Calendar:\napothecary help calendar"
            : card.svc.state === "loading" ? "Loading events…"
            : "Nothing planned.\nDouble-click a day or press + to add."
    }

    // ---- footer: when it was synced (click = sync now)
    InkDivider { anchors.left: parent.left; anchors.right: parent.right; y: foot.y - 2 }
    Item {
        id: foot
        y: 189; width: parent.width; height: 17
        Rectangle {      // sync state: herb green = fresh, muted = old, vermilion = offline, hollow = not connected
            id: dot
            x: 1; anchors.verticalCenter: parent.verticalCenter
            width: 6; height: 6; radius: 3
            readonly property string st: card.svc.state
            color: st === "ok" ? Theme.herb : st === "offline" ? Theme.seal : st === "stale" ? Theme.gold : "transparent"
            border.width: st === "ok" || st === "offline" || st === "stale" ? 0 : 1
            border.color: Theme.hairline
        }
        Text {
            x: 14
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 14
            text: card.svc.statusText
            elide: Text.ElideRight
            color: footArea.containsMouse ? Theme.text : Theme.textMuted
            font.family: Theme.fontUi
            font.pixelSize: 11
            renderType: Text.NativeRendering
        }
        MouseArea {
            id: footArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: card.svc.sync()
        }
        Loader {
            active: footArea.containsMouse
            sourceComponent: SlipTip {
                title: "Google Calendar"
                body: card.svc.state === "not-configured" ? "Not connected. Run: apothecary help calendar"
                    : card.svc.state === "offline" ? "Offline: showing the saved events.\n" + card.svc.error
                    : "Click to sync now"
                maxWidth: 240
                target: footArea; targetX: footArea.mouseX; targetY: footArea.mouseY
            }
        }
    }
}
