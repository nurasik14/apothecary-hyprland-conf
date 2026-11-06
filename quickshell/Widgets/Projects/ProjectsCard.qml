import QtQuick
import qs.Common
import qs.Services
import qs.Widgets
import qs.Widgets.Services

/*  ProjectsCard — 工程 · PROJECTS (400 × 244): a to-do list on a paper card, what is built and what is still in progress.
 *  Two sections: 在制 In progress (unchecked, file order) and 已成 Built (checked, struck through, the vermilion seal 成 on the note,
 *  newest first, the latest 5 then "+N more"; click the Built header to fold it).  Each row: ink checkbox (click = toggle; the seal
 *  cue plays when a project becomes built), the title (elided; the note under it), a ✕ on hover.  Remove asks no question: the card
 *  offers "Undo" for 5 s instead.  Double-click a title = edit in the dialog, "+ Add" = add.  Empty at first: it never invents projects.
 *  Data and every other way in (`apothecary projects`, `hypr-projects`, the rofi menu on the stock desktop, IPC target projects):
 *  ProjectsService.  Typing happens in Projects/ProjectsDialog.qml, a layer that takes the keyboard (this widget layer never does).
 *  The list is shared with Overworld: a tick in one theme shows in the other.
 */
WidgetCard {
    id: card
    title: "工程"
    subtitle: "Projects"
    sealGlyph: "印"
    width: 400
    height: 244
    padding: 12

    readonly property var svc: ProjectsService
    property bool builtOpen: true          // the Built section is unfolded
    property bool builtAll: false          // …and shows more than the latest 5
    property int pinHover: -1              // previews only: row number (0-based, in list order) drawn as hovered
    property string lastSound: ""          // which cue the last toggle asked for (tests)
    readonly property int builtShown: builtAll ? svc.built.length : Math.min(5, svc.built.length)
    readonly property int hiddenBuilt: svc.built.length - builtShown

    function toggleItem(it) {
        if (it.status !== "built") { card.lastSound = "seal"; SoundService.play("seal"); }
        else card.lastSound = "";
        svc.toggle(it.id);
    }
    function removeItem(it) { svc.remove(it.id) }

    // ---- empty state
    Item {
        anchors.fill: parent
        visible: card.svc.count === 0
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 8
            text: "工"
            color: Theme.seal
            opacity: 0.85
            font.family: Theme.fontDisplay
            font.pixelSize: 54
            renderType: Text.NativeRendering
        }
        InkText {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 82
            role: "subtitle"
            text: "No projects yet"
        }
        InkText {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 106
            width: parent.width - 16
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            maximumLineCount: 2
            role: "small"; muted: true
            text: "Press Add, or Super+Shift+P,\nor type  apothecary projects add \"…\""
        }
        InkButton {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 150
            text: "Add a project"; icon: "󰐕"; primary: true
            implicitHeight: 28
            activeFocusOnTab: false
            onClicked: card.svc.openDialog("")
        }
    }

    // ---- the list
    Flickable {
        id: flick
        visible: card.svc.count > 0
        anchors.fill: parent
        contentWidth: width
        contentHeight: col.height
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height

        Column {
            id: col
            width: flick.width - (flick.interactive ? 8 : 0)
            spacing: 4

            // 在制 · In progress
            Item {
                width: parent.width; height: 24
                Row {
                    spacing: Theme.space.sm
                    anchors.verticalCenter: parent.verticalCenter
                    Text {
                        text: "在制"
                        color: Theme.text
                        font.family: Theme.fontTitle; font.pixelSize: 16
                        renderType: Text.NativeRendering
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    InkText {
                        role: "subtitle"; muted: true
                        text: "In progress"
                        font.capitalization: Font.AllUppercase
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    InkText { text: card.svc.inProgress.length; role: "small"; muted: true; anchors.verticalCenter: parent.verticalCenter }
                }
                InkButton {
                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                    text: "Add"; icon: "󰐕"; quiet: true
                    implicitHeight: 24; horizontalPadding: 8
                    activeFocusOnTab: false
                    tooltip: "Add a project (Super+Shift+P)"
                    onClicked: card.svc.openDialog("")
                }
            }
            Repeater {
                model: card.svc.inProgress
                ProjectRow {
                    required property var modelData
                    required property int index
                    hoverPin: card.pinHover === index
                    width: col.width
                    item: modelData
                    onToggled: it => card.toggleItem(it)
                    onRemoveRequested: it => card.removeItem(it)
                    onEditRequested: it => card.svc.openDialog(it.id)
                }
            }
            InkText {
                visible: card.svc.inProgress.length === 0
                width: parent.width; height: 26
                role: "small"; muted: true
                text: "Nothing in progress — start one with Add."
            }

            // 已成 · Built
            Item {
                visible: card.svc.built.length > 0
                width: parent.width; height: 26
                Row {
                    spacing: Theme.space.sm
                    anchors.verticalCenter: parent.verticalCenter
                    Text {
                        text: card.builtOpen ? "▾" : "▸"
                        color: Theme.textMuted
                        font.family: Theme.fontUi; font.pixelSize: 12
                        renderType: Text.NativeRendering
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: "已成"
                        color: Theme.text
                        font.family: Theme.fontTitle; font.pixelSize: 16
                        renderType: Text.NativeRendering
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    InkText {
                        role: "subtitle"; muted: true
                        text: "Built"
                        font.capitalization: Font.AllUppercase
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    InkText { text: card.svc.built.length; role: "small"; muted: true; anchors.verticalCenter: parent.verticalCenter }
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: card.builtOpen = !card.builtOpen
                }
            }
            Repeater {
                model: card.builtOpen ? card.svc.built.slice(0, card.builtShown) : []
                ProjectRow {
                    required property var modelData
                    required property int index
                    hoverPin: card.pinHover === card.svc.inProgress.length + index
                    width: col.width
                    item: modelData
                    onToggled: it => card.toggleItem(it)
                    onRemoveRequested: it => card.removeItem(it)
                    onEditRequested: it => card.svc.openDialog(it.id)
                }
            }
            Item {
                visible: card.builtOpen && card.svc.built.length > 5
                width: parent.width; height: 22
                InkText {
                    anchors.verticalCenter: parent.verticalCenter
                    x: 8
                    role: "small"
                    color: Theme.link
                    text: card.builtAll ? "Show less" : "+" + card.hiddenBuilt + " more"
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: card.builtAll = !card.builtAll
                }
            }
        }
    }
    Rectangle {   // scroll position
        visible: flick.visible && flick.interactive
        x: flick.width - 4; width: 3; radius: 1.5
        y: flick.height * flick.visibleArea.yPosition
        height: Math.max(16, flick.height * flick.visibleArea.heightRatio)
        color: Theme.hairline
    }

    // ---- undo slip (5 s after a remove)
    Rectangle {
        visible: card.svc.undo !== null
        anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
        height: 32
        radius: 6
        color: Theme.titlebar
        border.width: 1; border.color: Theme.withAlpha(Theme.titlebarText, 0.3)
        InkText {
            x: 12
            width: parent.width - 12 - 80
            height: parent.height
            role: "small"
            color: Theme.titlebarText
            text: card.svc.undo ? (card.svc.undo.count > 1 ? "Removed " + card.svc.undo.count + " projects" : "Removed “" + card.svc.undo.title + "”") : ""
        }
        InkButton {
            anchors.right: parent.right; anchors.rightMargin: 6; anchors.verticalCenter: parent.verticalCenter
            text: "Undo"; icon: "󰕌"; primary: true
            implicitHeight: 24; horizontalPadding: 8
            activeFocusOnTab: false
            onClicked: card.svc.undoRemove()
        }
    }
}
