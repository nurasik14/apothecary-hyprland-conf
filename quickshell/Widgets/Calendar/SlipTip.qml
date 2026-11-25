import QtQuick
import QtQuick.Window
import qs.Common

/*  SlipTip — the Calendar card's tooltip: a small slip of paper (cream in the day, lacquer-brown at night) with a thin ink frame, a hairline rule
 *  inside it and a vermilion edge on the left, like a label pasted on a drawer.  Soft, no bounce: it just appears (a 140 ms fade).
 *    title: string       first line (Cormorant / EB Garamond, the date or the event)
 *    lines: var          rows [{when, tag, text, color}] : the time (muted, or `color`), an optional tag chip, the text
 *    body: string        wrapped plain lines (notes, a place), "\n" separated
 *    hint: string        last line, small and muted
 *    maxWidth: int       wrap width of the text, px (default 280)
 *    target: Item        follow the pointer over this item: the mouse at (targetX, targetY) in target coordinates.  The slip reparents itself to the
 *                        window's content item, sits above everything and flips at the window edge (right and below the pointer by default).
 */
Item {
    id: root
    property string title: ""
    property var lines: []
    property string body: ""
    property string hint: ""
    property int maxWidth: 280
    property Item target: null
    property real targetX: 0
    property real targetY: 0
    readonly property int pad: 10

    implicitWidth: col.width + pad * 2 + 4
    implicitHeight: col.height + pad * 2 - 2
    width: implicitWidth
    height: implicitHeight
    z: 100000
    opacity: 0
    NumberAnimation on opacity { to: 1; duration: Theme.durFast; easing.type: Easing.OutCubic; running: true }

    function _place() {
        if (!target || !parent) return;
        const p = target.mapToItem(parent, targetX, targetY);
        const w = parent.width, h = parent.height;
        let nx = p.x + 14;
        if (nx + width > w - 4) nx = p.x - 14 - width;
        let ny = p.y + 16;
        if (ny + height > h - 4) ny = p.y - 12 - height;
        x = Math.max(4, nx);
        y = Math.max(4, ny);
    }
    onTargetXChanged: _place()
    onTargetYChanged: _place()
    onWidthChanged: _place()
    onHeightChanged: _place()
    readonly property real _boundsW: parent ? parent.width : 0
    readonly property real _boundsH: parent ? parent.height : 0
    on_BoundsWChanged: Qt.callLater(_place)
    on_BoundsHChanged: Qt.callLater(_place)
    onVisibleChanged: if (visible) _place()
    readonly property var _window: target ? target.Window.window : null
    on_WindowChanged: _attach()
    onTargetChanged: _attach()
    Component.onCompleted: _attach()
    function _attach() {
        if (target && target.Window.window) parent = target.Window.contentItem;
        _place();
    }

    Rectangle {   // the paper's soft drop, a plain offset (no blur: this appears and disappears with the pointer)
        x: 1; y: 3; width: parent.width; height: parent.height
        radius: 3
        color: Theme.shadow
    }
    Rectangle {
        id: paper
        anchors.fill: parent
        radius: 3
        color: Theme.bg2
        border.width: 1
        border.color: Theme.frame
    }
    Rectangle {   // the hairline rule inside, like the card's double rule
        anchors.fill: parent
        anchors.margins: 3
        radius: 1
        color: "transparent"
        border.width: 1
        border.color: Theme.hairline
        opacity: 0.8
    }
    Rectangle {   // the vermilion edge
        x: 1; y: 1; width: 3; height: parent.height - 2
        color: Theme.seal
    }

    Column {
        id: col
        x: root.pad + 4
        y: root.pad - 2
        spacing: 2
        width: Math.min(Math.max(titleText.implicitWidth, rowsWidth, bodyCol.width, hintText.implicitWidth), root.maxWidth)
        property real rowsWidth: 0

        Text {
            id: titleText
            visible: root.title.length > 0
            width: col.width
            text: root.title
            elide: Text.ElideRight
            color: Theme.text
            font.family: Theme.fontSerifBody
            font.pixelSize: 16
            font.weight: 600
            renderType: Text.NativeRendering
            textFormat: Text.PlainText
            bottomPadding: 3
        }
        Repeater {
            model: root.lines
            delegate: Row {
                id: row
                required property var modelData
                spacing: 6
                height: 18
                Text {
                    id: whenText
                    anchors.verticalCenter: parent.verticalCenter
                    width: 54
                    text: row.modelData.when
                    color: row.modelData.color !== undefined ? row.modelData.color : Theme.textMuted
                    font.family: Theme.fontUi
                    font.pixelSize: 12
                    renderType: Text.NativeRendering
            textFormat: Text.PlainText
                    elide: Text.ElideRight
                }
                TagChip {
                    id: chip
                    anchors.verticalCenter: parent.verticalCenter
                    tag: row.modelData.tag || ""
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(implicitWidth, root.maxWidth - 54 - 6 - (chip.visible ? chip.width + 6 : 0))
                    text: row.modelData.text
                    elide: Text.ElideRight
                    color: row.modelData.dim ? Theme.textMuted : Theme.text
                    font.family: Theme.fontBody
                    font.pixelSize: 13
                    renderType: Text.NativeRendering
            textFormat: Text.PlainText
                }
                Component.onCompleted: col.rowsWidth = Math.max(col.rowsWidth, implicitWidth)
            }
        }
        Column {
            id: bodyCol
            spacing: 1
            Repeater {
                model: root.body.length ? root.body.split("\n") : []
                Text {
                    required property string modelData
                    width: Math.min(implicitWidth, root.maxWidth)
                    text: modelData
                    wrapMode: Text.Wrap
                    color: Theme.text
                    font.family: Theme.fontBody
                    font.pixelSize: 13
                    renderType: Text.NativeRendering
            textFormat: Text.PlainText
                }
            }
        }
        Text {
            id: hintText
            visible: root.hint.length > 0
            topPadding: 3
            width: Math.min(implicitWidth, root.maxWidth)
            text: root.hint
            elide: Text.ElideRight
            color: Theme.textMuted
            font.family: Theme.fontSerifBody
            font.pixelSize: 13
            font.italic: true
            renderType: Text.NativeRendering
            textFormat: Text.PlainText
        }
    }
}
