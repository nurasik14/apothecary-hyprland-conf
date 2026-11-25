import QtQuick
import qs.Common
import qs.Widgets.Services

/*  TagChip — the small ink label for an event's tag ([class] [opp] [email] …): the tag's ink as a thin outline and a faint wash of the same ink,
 *  like a stamped label.  Unknown tags get plain muted ink.  Width follows the text (6 characters at most).
 */
Rectangle {
    id: chip
    property string tag: ""
    readonly property string shown: tag.length > 6 ? tag.slice(0, 6) : tag
    readonly property color ink: CalendarService.tagColor(tag)
    visible: tag.length > 0
    width: visible ? label.implicitWidth + 9 : 0
    height: 14
    radius: 3
    color: Theme.withAlpha(ink, Theme.isDark ? 0.18 : 0.13)
    border.width: 1
    border.color: Theme.withAlpha(ink, 0.7)
    Text {
        id: label
        anchors.centerIn: parent
        text: chip.shown
        color: Theme.isDark ? chip.ink : Qt.darker(chip.ink, 1.35)
        font.family: Theme.fontUi
        font.pixelSize: 10
        font.weight: 500
        renderType: Text.NativeRendering
        textFormat: Text.PlainText
    }
}
