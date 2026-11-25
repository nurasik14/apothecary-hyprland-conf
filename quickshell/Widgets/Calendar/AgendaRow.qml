import QtQuick
import qs.Common
import qs.Widgets.Services

/*  AgendaRow — one event of the selected day (a 20 px line): time, tag chip, title, place.  Past events are faded, the running one has a
 *  vermilion mark and time.  Hover = an ink wash and a paper slip with the full title, time, place and notes; click opens the event in the browser.
 *    event: var (a CalendarService event) · day: "YYYY-MM-DD" it is listed under · pinHover: previews only
 */
Item {
    id: row
    property var event: null
    property string day: ""
    property bool pinHover: false
    signal opened(string id)
    width: 356; height: 20

    readonly property bool hot: area.containsMouse || pinHover
    readonly property real nowMs: CalendarService.nowMs
    readonly property bool over: event ? (event.allDay ? event.lastDay < CalendarService.todayKey : event.endMs <= nowMs && event.startMs < nowMs) : false
    readonly property bool running: event ? (!event.allDay && event.startMs <= nowMs && event.endMs > nowMs) : false
    readonly property string when: event ? CalendarService.startLabel(event, day) : ""

    Rectangle {
        anchors.fill: parent
        radius: 4
        color: Theme.inkWash
        opacity: row.hot ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.durFast; easing.type: Easing.OutCubic } }
    }
    opacity: over ? 0.55 : 1
    Rectangle {          // the running event: a small vermilion tick on the left
        visible: row.running
        x: 2; anchors.verticalCenter: parent.verticalCenter
        width: 3; height: 12; radius: 1.5
        color: Theme.seal
    }
    Text {
        id: timeText
        x: 9; anchors.verticalCenter: parent.verticalCenter
        width: 56
        text: row.when
        elide: Text.ElideRight
        color: row.running ? Theme.seal : (row.event && row.event.allDay ? Theme.indigo : Theme.accent2)
        font.family: Theme.fontUi
        font.pixelSize: 12
        font.weight: row.running ? 600 : 400
        renderType: Text.NativeRendering
    }
    TagChip {
        id: chip
        x: 70; anchors.verticalCenter: parent.verticalCenter
        tag: row.event ? row.event.tag : ""
    }
    function esc(t) { return String(t).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;"); }
    Text {
        x: 70 + (chip.visible ? chip.width + 6 : 0)
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width - x - 6
        textFormat: Text.StyledText
        text: row.esc(row.event ? row.event.title : "") + (row.event && row.event.location ? "  <font color=\"" + Theme.textMuted + "\">@" + row.esc(row.event.location) + "</font>" : "")
        elide: Text.ElideRight
        color: Theme.text
        font.family: Theme.fontBody
        font.pixelSize: 13
        renderType: Text.NativeRendering
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: row.event && row.event.link ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: if (row.event && row.event.link) row.opened(row.event.id)
    }

    Loader {
        active: row.hot && row.event !== null
        sourceComponent: SlipTip {
            title: row.event.title
            body: {
                const e = row.event;
                const l = [CalendarService.fmtDay(row.day, "ddd d MMM") + ", " + (e.allDay ? "all day" : (e.day === e.lastDay ? e.startHM + "-" + e.endHM : e.startHM + " → " + CalendarService.fmtDay(e.lastDay, "d MMM") + " " + e.endHM))];
                if (e.location) l.push("@ " + e.location);
                if (e.description) l.push(e.description.split("\n").slice(0, 4).join(" · ").slice(0, 160));
                return l.join("\n");
            }
            hint: row.event.link ? "Click: open in the browser" : ""
            target: row
            targetX: area.containsMouse ? area.mouseX : row.width / 2
            targetY: area.containsMouse ? area.mouseY : row.height / 2
        }
    }
}
