//@ pragma UseQApplication
import QtQuick
import QtQuick.Window
import Quickshell
import qs.Common
import qs.NowPlaying

/*  Offscreen render of the hanging-scroll mini-player with a mock model (nothing live is read or touched):
 *    APO_NP_CASE=landscape|portrait|spotify|hover|paused|fetching|live|nothing|narrow|thumb   APO_RENDER_OUT=<png>
 *      TikTok buttons (hovered, logged in): tt-off|tt-on|tt-busy|tt-unknown|tt-error|tt-min (portrait, smallest size)|tt-wide
 *      Several sources (hovered): src-chip (3 sources, Auto) | src-list (the list open, pinned to 1) | src-one (1 source: no chip) |
 *      src-min-chip / src-min-list (a TikTok portrait clip at the smallest size) | src-wide-list (a landscape clip at the smallest size)
 *      (a landscape clip at the smallest size; still from APO_NP_STILL169)
 *    APO_NP_STILL=<png> (a frame of a real cached video, the stand-in for the VideoOutput, which offscreen grabs cannot capture)
 *    APO_NP_THUMB=<img> (thumbnail; `thumb` = a 4:3 hqdefault.jpg-style picture, no still)  APO_NP_ART=<img> (music cover)
 *    APO_RENDER_BG=<wallpaper>
 *    HOME=<temp home with .config/apothecary/mode = light|dark and .local/share/fonts → the real fonts>
 *    QT_QPA_PLATFORM=offscreen qs -p quickshell/NowPlaying/preview/render.qml
 */
ShellRoot {
    id: shell
    readonly property string kase: Quickshell.env("APO_NP_CASE") || "landscape"
    readonly property bool tt: kase.indexOf("tt-") === 0
    readonly property bool src: kase.indexOf("src-") === 0
    readonly property bool srcPortrait: kase === "src-min-chip" || kase === "src-min-list"
    QtObject {
        id: mock
        property real aspect: shell.kase === "tt-wide" ? 16 / 9 : shell.tt || shell.srcPortrait || shell.kase === "portrait" ? 9 / 16 : shell.kase === "spotify" || shell.kase === "nothing" ? 1 : 16 / 9
        property bool hasMedia: shell.kase !== "nothing"
        property bool paused: shell.kase === "paused" || !hasMedia
        property string title: shell.tt ? "当你终于读懂了药方 🌿 #medicine #fyp" : ({ portrait: "当你终于读懂了药方 🌿 #medicine #fyp",
                                  spotify: "幾億光年", live: "Lofi beats to study and brew tea to · 24/7 radio",
                                  nothing: "幾億光年", thumb: "Как заварить идеальный улун — the long version" })[shell.kase] || "Me at the zoo"
        property string artist: shell.tt ? "herb.garden" : ({ portrait: "herb.garden", spotify: "Omoinotake", live: "Quiet Pavilion", nothing: "Omoinotake",
                                   thumb: "Чайная лавка" })[shell.kase] || "jawed"
        property string site: shell.tt || shell.srcPortrait ? "tiktok" : ({ portrait: "tiktok", spotify: "spotify", nothing: "spotify" })[shell.kase] || "youtube"
        property string sourceLabel: ({ youtube: "YouTube", tiktok: "TikTok", spotify: "Spotify" })[site]
        property string artUrl: shell.kase === "spotify" || shell.kase === "nothing"
                                ? (Quickshell.env("APO_NP_ART") ? "file://" + Quickshell.env("APO_NP_ART") : "")
                                : Quickshell.env("APO_NP_THUMB") ? "file://" + Quickshell.env("APO_NP_THUMB") : ""
        property string videoFile: ""
        property string videoStatus: shell.kase === "fetching" || shell.kase === "thumb" ? "fetching" : "ready"
        property bool isVideo: site !== "spotify"
        property bool live: shell.kase === "live"
        property bool ad: false
        property real duration: shell.kase === "live" ? 0 : shell.kase === "portrait" || shell.tt ? 34 : shell.kase === "spotify" ? 277 : 19
        property var clock: ({ valid: true, position: 7, ts: Date.now(), paused: paused, rate: 1, duration: duration })
        property bool canFocus: true
        property bool canToggle: true
        property bool canNext: site !== "tiktok"
        property bool canPrevious: site !== "tiktok"
        // several sources
        property var sources: shell.kase === "src-one" ? [{ id: "tab:a", kind: "bridge", site: "youtube", label: "YouTube", title: "Me at the zoo", artist: "jawed", paused: false }]
            : !shell.src ? [] : [
            { id: "tab:a", kind: "bridge", site: "youtube", label: "YouTube", title: "Me at the zoo", artist: "jawed", paused: false },
            { id: "tab:b", kind: "bridge", site: "tiktok", label: "TikTok", title: "当你终于读懂了药方 🌿 #medicine #fyp", artist: "herb.garden", paused: true },
            { id: "mpris:spotify", kind: "mpris", site: "spotify", label: "Spotify", title: "幾億光年", artist: "Omoinotake", paused: true }]
        property int sourceCount: sources.length
        property string pinnedId: shell.kase === "src-list" || shell.kase === "src-wide-list" ? "tab:a" : shell.srcPortrait ? "tab:b" : ""
        property bool auto: pinnedId === ""
        property string shownId: shell.srcPortrait ? "tab:b" : "tab:a"
        property int shownIndex: shell.srcPortrait ? 2 : 1
        property string route: "mpris"
        property string controlsNote: ""
        function choose(id) { console.warn("mock choose", id); return true }
        function pick(w) { console.warn("mock pick", w); return "" }
        function positionNow() { return shell.kase === "spotify" ? 96 : shell.kase === "portrait" || shell.tt ? 12 : 7 }
        // TikTok like / repost / save
        property bool canLike: shell.tt
        property var liked: ({ "tt-on": true, "tt-busy": true, "tt-unknown": null, "tt-error": true })[shell.kase] ?? false
        property var saved: ({ "tt-on": true, "tt-busy": false, "tt-unknown": null, "tt-error": true })[shell.kase] ?? false
        property var reposted: ({ "tt-on": true, "tt-off": false, "tt-busy": false, "tt-min": false, "tt-wide": true })[shell.kase] ?? null
        property string busy: shell.kase === "tt-busy" ? "save" : ""
        property string actionError: shell.kase === "tt-error" ? "saved to Favorites only: no collection named \"Edits\"" : ""
        property string actionErrorFor: actionError.length ? "save" : ""
        property bool actionErrorFresh: actionError.length > 0
        property string tiktokCollection: "Edits"
        function act(what) { console.warn("mock act", what) }
        function fmt(s) { s = Math.floor(s); return Math.floor(s / 60) + ":" + (s % 60 < 10 ? "0" : "") + (s % 60) }
        function focusSource() { console.warn("mock focus") }
        function togglePlaying() {} function next() {} function previous() {}
    }
    Window {
        id: win
        width: 500; height: shell.kase === "portrait" || shell.srcPortrait || (shell.tt && shell.kase !== "tt-wide") ? 480 : 380
        visible: true
        color: Theme.isDark ? "#1c1a17" : "#cfc4aa"
        Item {
            id: stage
            anchors.fill: parent
            Rectangle { anchors.fill: parent; color: Theme.isDark ? "#1c1a17" : "#cfc4aa" }   // a grab leaves out the window colour
            Image {
                anchors.fill: parent
                source: Quickshell.env("APO_RENDER_BG") ? "file://" + Quickshell.env("APO_RENDER_BG") : ""
                fillMode: Image.PreserveAspectCrop
            }
            NowPlayingView {
                id: view
                np: mock
                x: 40; y: 24
                boxW: shell.kase === "narrow" ? 220 : shell.kase === "tt-min" || shell.kase === "tt-wide" || shell.srcPortrait || shell.kase === "src-wide-list" ? 200 : 360
                mirrorEnabled: false
                frameStill: shell.kase === "tt-wide" || (shell.src && !shell.srcPortrait) ? (Quickshell.env("APO_NP_STILL169") || "") : ["fetching", "spotify", "nothing", "thumb"].indexOf(shell.kase) >= 0 ? "" : (Quickshell.env("APO_NP_STILL") || "")
                forceHover: shell.kase === "hover" || shell.tt || shell.src
                forceList: shell.kase === "src-list" || shell.kase === "src-min-list" || shell.kase === "src-wide-list"
            }
        }
        Timer {
            interval: 1800; running: true
            onTriggered: stage.grabToImage(r => {
                const out = Quickshell.env("APO_RENDER_OUT") || "/tmp/np-render.png";
                console.warn("render: saved", r.saveToFile(out), out, "view", view.width + "x" + view.height, "mode", Theme.mode);
                Qt.quit();
            })
        }
    }
}
