pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

/*  ApoConfig — read-only view of ~/.config/apothecary/config.json for the widget layer.
 *    sounds (bool, default true) · reduced_motion (bool) · weather{lat,lon,name} · brew{work,break} (minutes)
 *  Paths: stateDir (~/.config/apothecary), cacheDir (~/.cache/apothecary), scriptDir (this directory).
 */
Singleton {
    id: root
    readonly property string home: Quickshell.env("HOME")
    readonly property string stateDir: home + "/.config/apothecary"
    readonly property string cacheDir: home + "/.cache/apothecary"
    readonly property string scriptDir: Qt.resolvedUrl(".").toString().replace(/^file:\/\//, "").replace(/\/$/, "")

    property var config: ({})
    FileView {
        id: file
        path: root.stateDir + "/config.json"
        blockLoading: true
        watchChanges: true
        printErrors: false
        onLoaded: root.parse(text())
        onFileChanged: reload()
    }
    function parse(t) {
        try { root.config = JSON.parse(t || "{}") || ({}) } catch (e) { console.warn("ApoConfig: config.json parse error:", e); root.config = ({}) }
    }
    function get(path, fallback) {
        let cur = root.config;
        for (const k of path.split(".")) {
            if (cur === null || typeof cur !== "object" || !(k in cur)) return fallback;
            cur = cur[k];
        }
        return cur === undefined || cur === null ? fallback : cur;
    }

    readonly property bool sounds: config.sounds !== false
    readonly property bool reducedMotion: config.reduced_motion === true
    readonly property int brewWorkMinutes: Math.max(1, parseInt(get("brew.work", 25)) || 25)
    readonly property int brewBreakMinutes: Math.max(1, parseInt(get("brew.break", 5)) || 5)

    // one-shot helpers used by the services
    Process { id: mkdirs; command: ["mkdir", "-p", root.stateDir, root.cacheDir]; running: true }
}
