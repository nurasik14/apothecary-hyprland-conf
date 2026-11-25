import QtQuick
import qs.Common
import qs.Services
import qs.Widgets.Services

/*  CalendarForm — the quick-add panel: one ink field, a preview of what the line will become (parsed by `hypr-gcal parse`, the same parser the CLI
 *  uses) and Add / Cancel.  Used by CalendarEditor (inside the apothecary-calendar layer) and by the offscreen renders.
 *    active: bool    true while open: takes the keyboard
 *  Natural input:  14:00 Meeting @MMW2450 · 9:30-11 Lab · 2pm for 90m Call · all day Exam    (the day is the one you opened it on).
 *  Enter = add · Esc / Cancel / a click outside = close.  "Saving…" while the CLI runs; an error stays in the panel under the field.
 */
Item {
    id: form
    property bool active: false
    signal closeAsked()
    readonly property var svc: CalendarService
    readonly property alias field: field
    readonly property alias panel: panel

    width: panel.width
    height: panel.height

    function submit() {
        if (svc.adding || !field.text.trim().length) return;
        svc.add(field.text, svc.addDay);
    }
    function reset() {
        field.text = "";
        svc.addError = "";
        svc.previewText = ""; svc.previewError = "";
        if (form.active) field.input.forceActiveFocus();
    }
    onActiveChanged: if (active) reset()
    Component.onCompleted: if (active) reset()
    Timer { interval: 30; running: form.active; onTriggered: field.input.forceActiveFocus() }   // once the layer has really mapped
    Connections {
        target: form.svc
        function onAdded(text) { form.closeAsked(); }
    }
    Timer { id: previewTimer; interval: 220; onTriggered: form.svc.parse(field.text, form.svc.addDay) }

    MouseArea { anchors.fill: panel }            // a click anywhere on the panel must not reach the scrim

    PaperPanel {
        id: panel
        width: 420; height: 226
        title: "日程"
        subtitle: "New event"
        sealGlyph: "印"
        radius: Theme.radius.lg
        padding: Theme.space.lg

        Column {
            anchors.fill: parent
            spacing: 6
            Text {
                text: form.svc.fmtDay(form.svc.addDay, "dddd d MMMM yyyy")
                color: Theme.text
                font.family: Theme.fontSerifBody
                font.pixelSize: 17
                font.weight: 600
                renderType: Text.NativeRendering
            }
            InkField {
                id: field
                width: parent.width
                icon: "󰃭"
                placeholder: "14:00 Meeting @MMW2450"
                error: form.svc.addError.length > 0 || form.svc.previewError.length > 0
                enabled: !form.svc.adding
                input.maximumLength: 200
                onAccepted: form.submit()
                onEscaped: form.closeAsked()
                onTextChanged: { form.svc.addError = ""; previewTimer.restart(); }
            }
            Text {      // what will be created / what is wrong
                width: parent.width
                height: 18
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
                textFormat: Text.PlainText
                font.family: Theme.fontBody
                font.pixelSize: 13
                renderType: Text.NativeRendering
                text: form.svc.adding ? "Saving…"
                    : form.svc.addError.length ? form.svc.cap(form.svc.addError)
                    : form.svc.previewError.length ? form.svc.cap(form.svc.previewError)
                    : form.svc.previewText.length ? "→ " + form.svc.previewText : " "
                color: form.svc.adding ? Theme.warning : (form.svc.addError.length || form.svc.previewError.length) ? Theme.seal : Theme.success
            }
            Text {
                width: parent.width
                wrapMode: Text.Wrap
                color: Theme.textMuted
                font.family: Theme.fontSerifBody
                font.pixelSize: 13
                font.italic: true
                renderType: Text.NativeRendering
                text: "14:00 Meeting @place · 9:30-11 Lab · 2pm for 90m Call · all day Exam"
            }
            Row {
                spacing: Theme.space.sm
                layoutDirection: Qt.RightToLeft
                width: parent.width
                InkButton {
                    text: "Cancel"
                    activeFocusOnTab: false
                    onClicked: form.closeAsked()
                }
                InkButton {
                    primary: true
                    text: form.svc.adding ? "Saving…" : "Add"
                    enabled: !form.svc.adding && field.text.trim().length > 0
                    activeFocusOnTab: false
                    onClicked: form.submit()
                }
            }
        }
    }
}
