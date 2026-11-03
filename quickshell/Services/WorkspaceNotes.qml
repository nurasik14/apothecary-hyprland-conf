pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

/*  WorkspaceNotes — your own title + note per workspace 1–10, read from ~/.config/apothecary/workspaces.json
 *  (watched live: edit the file or run `apothecary ws …` and the next card shows the change).
 *
 *    { "1": { "title": "Browser", "note": "Research, mail, CityU portal" },
 *      "3": "Coding" }                      ← a bare string is a title with no note
 *
 *  WorkspaceNotes.title(id) / note(id) / has(id)        ("" when unset)
 *  Card settings live in config.json → "workspace_card": { enabled, duration, position, show_untitled }
 */
Singleton {
    id: root
    readonly property string path: Quickshell.env("HOME") + "/.config/apothecary/workspaces.json"
    property var notes: ({})
    property int revision: 0

    function entry(id) {
        const e = root.notes[String(id)];
        if (e === undefined || e === null) return { title: "", note: "" };
        if (typeof e === "string") return { title: e, note: "" };
        return { title: String(e.title || ""), note: String(e.note || "") };
    }
    function title(id) { return root.revision >= 0 ? entry(id).title : ""; }
    function note(id) { return root.revision >= 0 ? entry(id).note : ""; }
    function has(id) { return title(id).length > 0 || note(id).length > 0; }

    function parse(t) {
        try {
            const obj = JSON.parse(t || "{}");
            root.notes = (obj && typeof obj === "object") ? obj : {};
        } catch (e) {
            console.warn("WorkspaceNotes: workspaces.json parse error:", e);   // keep the last good copy
        }
        root.revision++;
    }

    FileView {
        id: file
        path: root.path
        blockLoading: true
        watchChanges: true
        printErrors: false
        onLoaded: { poll.running = false; root.parse(text()); }
        onFileChanged: reload()
        onLoadFailed: error => { root.notes = {}; root.revision++; poll.running = true }
    }
    Timer {   // file missing: look again every 5 s so the first `apothecary ws` is picked up
        id: poll
        interval: 5000; repeat: true; running: false
        onTriggered: file.reload()
    }
    Component.onCompleted: parse(file.text())
}
