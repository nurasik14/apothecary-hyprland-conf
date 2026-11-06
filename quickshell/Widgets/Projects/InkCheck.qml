import QtQuick
import QtQuick.Shapes
import qs.Common
import qs.Services

/*  InkCheck — a checkbox drawn in ink: a small paper square with a hairline frame and, when checked, one brush-stroke tick.
 *    checked: bool · highlighted: bool (the row is hovered) · signal clicked()
 *  The tick draws itself in (stroke grows over ~160 ms; none with reduced_motion).  Size 16.
 */
Item {
    id: box
    property bool checked: false
    property bool highlighted: false
    property real progress: checked ? 1 : 0
    signal clicked()

    width: 16; height: 16
    Accessible.role: Accessible.CheckBox
    Accessible.checked: checked
    Behavior on progress { NumberAnimation { duration: ConfigService.reducedMotion ? 0 : 170; easing.type: Easing.OutCubic } }

    Rectangle {
        anchors.fill: parent
        radius: 3
        color: Theme.withAlpha(Theme.surface, 0.9)
        border.width: 1.5
        border.color: mouse.containsMouse || box.highlighted ? Theme.accent : Theme.text
        Behavior on border.color { ColorAnimation { duration: Theme.durFast } }
    }
    Shape {
        anchors.fill: parent
        antialiasing: true
        layer.enabled: true; layer.samples: 4
        visible: box.progress > 0.001
        ShapePath {
            strokeColor: Theme.text
            strokeWidth: 2.4
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            startX: 3.2; startY: 8.4
            PathLine { x: 3.2 + (6.4 - 3.2) * Math.min(1, box.progress * 2); y: 8.4 + (12.2 - 8.4) * Math.min(1, box.progress * 2) }
            PathLine {
                x: 6.4 + (13.4 - 6.4) * Math.max(0, box.progress * 2 - 1)
                y: 12.2 + (3.2 - 12.2) * Math.max(0, box.progress * 2 - 1)
            }
        }
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        anchors.margins: -3
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: box.clicked()
    }
}
