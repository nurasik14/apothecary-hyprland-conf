pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Widgets.Services

/*  BrewTimer — "Brewing medicine" focus timer (pomodoro).
 *    work 25 min / break 5 min (config.json brew.work / brew.break), state idle | working | breaking | paused.
 *    On finish: assets/sounds/brew-done.wav via pw-play (unless config.json sounds=false) and a notification;
 *    a finished work phase rolls into the break phase, a finished break returns to idle.
 *  IPC: qs -c apothecary ipc call brew start <minutes> | toggle | reset | status
 */
Singleton {
    id: root
    property string state: "idle"            // idle | working | breaking | paused
    property string pausedPhase: "working"    // phase to resume when paused
    property int remaining: 0                 // seconds
    property int total: 0                     // seconds of the current phase
    property int workMinutes: ApoConfig.brewWorkMinutes
    property int breakMinutes: ApoConfig.brewBreakMinutes
    property int sessions: 0                  // completed work phases since startup

    readonly property bool running: state === "working" || state === "breaking"
    readonly property bool active: state !== "idle"
    readonly property real progress: total > 0 ? 1 - remaining / total : 0
    readonly property string phase: state === "paused" ? pausedPhase : state
    readonly property string mmss: fmt(remaining > 0 ? remaining : (state === "idle" ? workMinutes * 60 : 0))
    readonly property string label: state === "idle" ? "Ready" : state === "paused" ? "Paused" : state === "working" ? "Brewing" : "Resting"

    function fmt(s) { s = Math.max(0, Math.floor(s)); const m = Math.floor(s / 60), r = s % 60; return (m < 10 ? "0" : "") + m + ":" + (r < 10 ? "0" : "") + r }

    Timer {
        id: tick
        interval: 1000; repeat: true
        running: root.running
        onTriggered: {
            if (root.remaining > 1) { root.remaining -= 1; return }
            root.remaining = 0;
            root.finishPhase();
        }
    }

    function start(minutes) {
        const m = Math.max(1, parseInt(minutes) || workMinutes);
        root.total = m * 60; root.remaining = root.total;
        root.state = "working";
    }
    function startBreak() {
        root.total = breakMinutes * 60; root.remaining = root.total;
        root.state = "breaking";
    }
    function pause() { if (running) { root.pausedPhase = root.state; root.state = "paused" } }
    function resume() { if (state === "paused") root.state = pausedPhase }
    function toggle() {
        if (state === "idle") start(workMinutes);
        else if (state === "paused") resume();
        else pause();
    }
    function reset() { root.state = "idle"; root.remaining = 0; root.total = 0 }
    function finishPhase() {
        if (state === "working") {
            root.sessions += 1;
            notify("Medicine is ready", workMinutes + " minutes brewed. Rest for " + breakMinutes + ".");
            startBreak();
        } else {
            notify("Back to the workbench", "Break over.");
            reset();
        }
    }

    function notify(title, body) {
        notifier.command = ["notify-send", "-a", "Apothecary", "-i", "alarm", title, body];
        notifier.running = true;
        if (ApoConfig.sounds) {
            player.command = ["sh", "-c", "f=\"$1\"; [ -f \"$f\" ] && command -v pw-play >/dev/null && exec pw-play \"$f\"", "brew-sound", Theme.repoDir + "/assets/sounds/brew-done.wav"];
            player.running = true;
        }
    }
    Process { id: notifier }
    Process { id: player }

    IpcHandler {
        target: "brew"
        function start(minutes: string): void { root.start(minutes) }
        function toggle(): void { root.toggle() }
        function reset(): void { root.reset() }
        function status(): string { return root.state + " " + root.mmss + " (" + root.phase + ")" }
    }
}
