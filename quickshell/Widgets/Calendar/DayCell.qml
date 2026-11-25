import QtQuick
import qs.Common
import qs.Widgets.Services

/*  DayCell — one day of the month / week: the number (LXGW WenKai), weekends in `accent2`, and the day's events as ink drops under it (up to
 *  three, in the tag's ink; a hollow drop is an all-day event; "+" when there are more).  Today = the vermilion seal stamped behind the number,
 *  the selected day = a brushed ink ring, hover = an ink wash and a paper-slip tooltip listing the day's events.
 *    key "YYYY-MM-DD" · day (number) · inMonth · weekend · selected · isToday
 *    signals clicked(key), doubleClicked(key)
 *    pinHover: previews only — draw the hover state and its tooltip
 */
Item {
    id: cell
    property string key: ""
    property int day: 1
    property bool inMonth: true
    property bool weekend: false
    property bool selected: false
    property bool isToday: false
    property bool pinHover: false
    signal clicked(string key)
    signal doubleClicked(string key)

    width: 50; height: 20
    z: isToday ? 3 : (selected || hot ? 2 : 0)

    readonly property bool hot: area.containsMouse || pinHover
    readonly property var evs: CalendarService.eventsOn(key)
    readonly property int count: evs.length
    readonly property real dim: inMonth ? 1 : 0.4
    readonly property int seed: { const m = /(\d+)-(\d+)-(\d+)/.exec(key); return m ? +m[1] + +m[2] * 31 + +m[3] * 7 : 1; }

    Rectangle {          // hover: a wash of ink
        anchors.fill: parent
        anchors.margins: 1
        radius: 4
        color: Theme.inkWash
        opacity: cell.hot ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.durFast; easing.type: Easing.OutCubic } }
    }
    InkRing {            // the selected day: a brushed ring round the number
        anchors.horizontalCenter: parent.horizontalCenter
        y: 0
        width: 34; height: 17
        visible: cell.selected && !cell.isToday
        seed: cell.seed
    }
    Rectangle {          // the selected day when it is today: a thin ink frame round the seal, like the border of a stamp
        visible: cell.selected && cell.isToday
        anchors.horizontalCenter: parent.horizontalCenter
        y: -3.5
        width: 29; height: 24
        radius: 4
        color: "transparent"
        border.width: 1.2
        border.color: Theme.withAlpha(Theme.text, 0.8)
    }
    Rectangle {          // today: the seal stamped on the paper
        visible: cell.isToday
        anchors.horizontalCenter: parent.horizontalCenter
        y: -1
        width: 22; height: 17
        radius: 2
        rotation: -2
        color: Theme.seal
        Rectangle { anchors.fill: parent; anchors.margins: 1.5; radius: 1; color: "transparent"; border.width: 1; border.color: Theme.withAlpha(Theme.textOnSeal, 0.35) }
    }
    Text {
        id: num
        anchors.horizontalCenter: parent.horizontalCenter
        y: 0
        height: 15
        verticalAlignment: Text.AlignVCenter
        text: cell.day
        font.family: Theme.fontBody
        font.pixelSize: 13
        font.weight: cell.isToday || cell.selected ? 600 : 400
        renderType: Text.NativeRendering
        color: cell.isToday ? Theme.textOnSeal : (cell.weekend ? Theme.accent2 : Theme.text)
        opacity: cell.dim
        Behavior on color { ColorAnimation { duration: Theme.durTheme } }
    }
    Row {                // the ink drops
        visible: cell.count > 0
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height - 4.5
        spacing: 2
        opacity: cell.dim
        Repeater {
            model: Math.min(3, cell.count)
            Rectangle {
                required property int index
                readonly property var ev: cell.evs[index]
                width: 4; height: 4; radius: 2
                color: ev.allDay ? "transparent" : CalendarService.tagColor(ev.tag)
                border.width: ev.allDay ? 1 : 0
                border.color: CalendarService.tagColor(ev.tag)
            }
        }
        Text {
            visible: cell.count > 3
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: -1
            text: "+"
            color: Theme.textMuted
            font.family: Theme.fontUi
            font.pixelSize: 9
            font.weight: 600
            renderType: Text.NativeRendering
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        onClicked: cell.clicked(cell.key)
        onDoubleClicked: cell.doubleClicked(cell.key)
    }

    // the slip: the date, then up to 5 events (time, tag, title) and "+N more"
    function tipLines() {
        const out = [], list = cell.evs, n = Math.min(5, list.length);
        for (let i = 0; i < n; i++) {
            const e = list[i];
            out.push({ when: CalendarService.startLabel(e, cell.key), tag: e.tag, text: e.title, color: e.allDay ? Theme.indigo : Theme.accent2 });
        }
        if (list.length > n) out.push({ when: "", tag: "", text: "+" + (list.length - n) + " more", dim: true });
        return out;
    }
    Loader {
        active: cell.hot && cell.count > 0
        sourceComponent: SlipTip {
            title: CalendarService.fmtDay(cell.key, "dddd d MMMM")
            lines: cell.tipLines()
            target: cell
            targetX: area.containsMouse ? area.mouseX : cell.width / 2
            targetY: area.containsMouse ? area.mouseY : cell.height / 2
        }
    }
}
