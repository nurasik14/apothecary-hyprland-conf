pragma Singleton
import QtQuick
import Quickshell

/*  ShellState — which overlay surface is open.  Only one modal surface at a time.
 *  ShellState.toggle("launcher" | "network" | "power" | "wallpapers" | "notifCenter" | "brew" | "projects" | "notes") · open(name) · close(name) · closeAll()
 */
Singleton {
    id: root
    property bool launcherOpen: false
    property bool networkOpen: false
    property bool powerOpen: false
    property bool wallpapersOpen: false
    property bool notifCenterOpen: false
    property bool brewOpen: false            // brew timer settings (Brew/BrewDialog.qml)
    property bool projectsOpen: false        // add / edit a project (Widgets/Projects/ProjectsDialog.qml)
    property bool notesOpen: false           // write on a note (Widgets/Notes/NotesEditor.qml; NotesService saves its draft when this closes)
    readonly property bool anyOpen: launcherOpen || networkOpen || powerOpen || wallpapersOpen || notifCenterOpen || brewOpen || projectsOpen || notesOpen

    signal launcherSearch(string q)      // test/IPC hook: set the launcher query
    signal networkExpand(string ssid)    // test/IPC hook: expand a Wi-Fi row
    signal wallpaperAction(string action, int arg)   // "select" <index> | "apply" | "next" | "prev"
    readonly property var names: ["launcher", "network", "power", "wallpapers", "notifCenter", "brew", "projects", "notes"]

    function isOpen(name) { return root[name + "Open"] === true; }
    function closeAll() { for (let i = 0; i < names.length; i++) root[names[i] + "Open"] = false; }
    function open(name) { if (isOpen(name)) return; closeAll(); root[name + "Open"] = true; }
    function close(name) { root[name + "Open"] = false; }
    function toggle(name) {
        const was = isOpen(name);
        closeAll();
        root[name + "Open"] = !was;
    }
}
