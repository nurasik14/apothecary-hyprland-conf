import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Bar
import qs.Launcher
import qs.Notifications
import qs.Network
import qs.Power
import qs.Wallpapers
import qs.Osd
import qs.Widgets

/*  Apothecary Hyprland — Quickshell entry.  `qs -c apothecary`
 *  Surfaces (layer namespaces): apothecary-bar · apothecary-launcher · apothecary-notif · apothecary-notifcenter ·
 *  apothecary-network · apothecary-power · apothecary-wallpapers · apothecary-osd · apothecary-widgets (qs-widgets)
 *  IPC: qs -c apothecary ipc call <target> <fn>   — see docs/QUICKSHELL.md
 */
ShellRoot {
    id: shell

    Bar {}
    Launcher {}
    Notifications {}
    NotificationCenter {}
    NetworkPanel {}
    PowerMenu {}
    WallpaperPicker {}
    Osd { id: osd }
    DesktopWidgets {}

    // ------------------------------------------------------------ IPC (BRIEF §4)
    IpcHandler {
        target: "launcher"
        function toggle(): void { ShellState.toggle("launcher"); }
        function open(): void { ShellState.open("launcher"); }
        function close(): void { ShellState.close("launcher"); }
        function search(q: string): void { ShellState.open("launcher"); ShellState.launcherSearch(q); }
    }
    IpcHandler {
        target: "network"
        function toggle(): void { ShellState.toggle("network"); }
        function open(): void { ShellState.open("network"); }
        function close(): void { ShellState.close("network"); }
        function expand(ssid: string): void { ShellState.open("network"); ShellState.networkExpand(ssid); }
        function connect(ssid: string): void { NetworkService.connect(ssid, ""); }
        function rescan(): void { NetworkService.rescan(); }
    }
    IpcHandler {
        target: "power"
        function toggle(): void { ShellState.toggle("power"); }
        function open(): void { ShellState.open("power"); }
        function close(): void { ShellState.close("power"); }
    }
    IpcHandler {
        target: "wallpapers"
        function toggle(): void { ShellState.toggle("wallpapers"); }
        function open(): void { ShellState.open("wallpapers"); }
        function close(): void { ShellState.close("wallpapers"); }
        function select(index: int): void { ShellState.open("wallpapers"); ShellState.wallpaperAction("select", index); }
        function apply(): void { ShellState.wallpaperAction("apply", 0); }
        function next(): void { ShellState.open("wallpapers"); ShellState.wallpaperAction("next", 0); }
        function prev(): void { ShellState.open("wallpapers"); ShellState.wallpaperAction("prev", 0); }
    }
    IpcHandler {
        target: "notifications"
        function toggle(): void { ShellState.toggle("notifCenter"); }
        function open(): void { ShellState.open("notifCenter"); }
        function close(): void { ShellState.close("notifCenter"); }
        function dnd(): void { NotificationService.toggleDnd(); }
        function clear(): void { NotificationService.dismissAll(); }
        function status(): string {
            return (NotificationService.dnd ? "dnd " : "") + NotificationService.count + " notes, " + NotificationService.unread + " unread";
        }
    }
    IpcHandler {
        target: "theme"
        function toggle(): void { Theme.toggleMode(); }
        function set(mode: string): void { Theme.setMode(mode); }
        function get(): string { return Theme.mode; }
    }
    IpcHandler {
        target: "osd"
        function volume(): void { osd.show("volume"); }
        function brightness(): void { osd.show("brightness"); }
    }
    IpcHandler {
        target: "shell"
        function closeAll(): void { ShellState.closeAll(); }
        function status(): string {
            return "mode=" + Theme.mode + " launcher=" + ShellState.launcherOpen + " network=" + ShellState.networkOpen
                 + " power=" + ShellState.powerOpen + " wallpapers=" + ShellState.wallpapersOpen
                 + " notifCenter=" + ShellState.notifCenterOpen + " dnd=" + NotificationService.dnd
                 + " wifi=" + NetworkService.activeSsid + " networks=" + NetworkService.networks.length;
        }
    }
}
