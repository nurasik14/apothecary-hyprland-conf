import QtQuick
import qs.Common
import qs.Services
import qs.Widgets.Services

/*  ProjectRow — one project on the card, a little paper note: checkbox · title (elided; the note under it in small muted type)
 *  · on built rows the vermilion seal 成 stamped at the right · ✕ at the far right on hover.
 *    item: the ProjectsService item        width: from the list
 *    click the box = toggle · double-click the title = edit (dialog) · ✕ = remove (the card then offers Undo for 5 s)
 *    signals toggled(item), removeRequested(item), editRequested(item)
 *  Height 26 (36 with a note).  The seal presses down (scale 1.7 → 1, a little spin) when a row appears because its project just became
 *  built (ProjectsService.justBuilt; the card rebuilds its rows from the file, so the stamp is played by the new row).
 */
Item {
    id: row
    property var item: null
    readonly property bool built: item ? item.status === "built" : false
    readonly property string note: item && item.note ? item.note : ""
    property bool hoverPin: false          // previews only: draw the hover state without a pointer
    readonly property bool hovered: hh.hovered || hoverPin
    signal toggled(var item)
    signal removeRequested(var item)
    signal editRequested(var item)

    height: note.length ? 36 : 26

    function dateOf(iso) { const d = new Date(iso); return isNaN(d.getTime()) ? "" : Qt.formatDate(d, "d MMM"); }
    readonly property string subline: {
        const parts = [];
        if (note.length) parts.push(note);
        if (built && item.built_at) parts.push("built " + dateOf(item.built_at));
        return parts.join("  ·  ");
    }

    HoverHandler { id: hh }
    Rectangle {   // the paper slip
        anchors.fill: parent
        radius: 4
        color: row.hovered ? Theme.withAlpha(Theme.surfaceAlt, 0.9) : Theme.withAlpha(Theme.surfaceAlt, 0.5)
        border.width: 1
        border.color: row.hovered ? Theme.withAlpha(Theme.accent, 0.8) : Theme.withAlpha(Theme.hairline, 0.8)
        Behavior on color { ColorAnimation { duration: Theme.durFast } }
        Behavior on border.color { ColorAnimation { duration: Theme.durFast } }
    }

    InkCheck {
        id: box
        x: 8; anchors.verticalCenter: parent.verticalCenter
        checked: row.built
        highlighted: row.hovered
        onClicked: row.toggled(row.item)
    }
    Column {
        id: texts
        x: 8 + 16 + 9
        width: row.width - x - (row.built ? 22 + 8 : 0) - 26
        anchors.verticalCenter: parent.verticalCenter
        spacing: 0
        InkText {
            width: parent.width
            text: row.item ? row.item.title : ""
            role: "body"
            color: row.built ? Theme.textMuted : Theme.text
            font.strikeout: row.built
            MouseArea {
                anchors.fill: parent
                onDoubleClicked: row.editRequested(row.item)
            }
        }
        InkText {
            visible: row.subline.length > 0
            width: parent.width
            text: row.subline
            role: "small"; muted: true
            font.pixelSize: 11
        }
    }
    Seal {   // the stamp: 成 = completed
        id: stamp
        size: 20
        glyph: "成"
        label: "Built"
        outline: false
        x: row.width - 26 - 8 - width
        anchors.verticalCenter: parent.verticalCenter
        opacity: row.built ? 0.92 * Math.min(1, row.press * 4) : 0
        scale: 1 + 0.7 * (1 - row.press)
        rotation: -7 - 15 * (1 - row.press)
        visible: opacity > 0.01
    }
    // the stamp comes down (overshoots a little) when this row is created because the project just became built
    property real press: 1
    NumberAnimation { id: stampDown; target: row; property: "press"; from: 0; to: 1; duration: 230; easing.type: Easing.OutBack; easing.overshoot: 2.2 }
    Component.onCompleted: if (built && item && item.id === ProjectsService.justBuilt && !ConfigService.reducedMotion) { press = 0; stampDown.start(); }
    Item {   // ✕
        id: cross
        anchors.right: parent.right; anchors.rightMargin: 6
        anchors.verticalCenter: parent.verticalCenter
        width: 20; height: 20
        opacity: row.hovered ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.durFast } }
        Text {
            anchors.centerIn: parent
            text: "✕"
            font.family: Theme.fontUi
            font.pixelSize: 12
            color: crossArea.containsMouse ? Theme.seal : Theme.textMuted
            renderType: Text.NativeRendering
        }
        MouseArea {
            id: crossArea
            anchors.fill: parent
            enabled: row.hovered
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: row.removeRequested(row.item)
        }
    }
}
