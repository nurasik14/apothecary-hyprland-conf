#!/usr/bin/env node
// Calendar card: does it still fit its slot (it did not grow with the events), is everything registered, and does the quick-add panel stay on the
// screen?  Reads the real slot out of DesktopWidgets.qml and the size out of the card's own file, so it follows the code.   node tests/calendar-layout.test.js
const fs = require("fs"), path = require("path"), vm = require("vm");
const repo = path.join(__dirname, "..");
const root = path.join(repo, "quickshell");
const read = f => fs.readFileSync(path.join(root, f), "utf8");
let fails = 0;
const check = (name, ok, extra) => { console.log((ok ? "PASS " : "FAIL ") + name + (extra !== undefined ? "  [" + extra + "]" : "")); if (!ok) fails++; };

const desk = read("Widgets/DesktopWidgets.qml"), card = read("Widgets/Calendar/CalendarCard.qml");
const w = +card.match(/^ {4}width: (\d+)/m)[1], h = +card.match(/^ {4}height: (\d+)/m)[1];
check("the card is still 380 x 260 (its slot between Weather's column and SysInfo)", w === 380 && h === 260, w + "x" + h);
const slot = desk.match(/CalendarCard \{ id: calendar;.*?defaultX: ([^;]+); defaultY: ([^;}]+?)\s*[;}]/);
check("DesktopWidgets places it", !!slot);
for (const [W, H] of [[1920, 1080], [2560, 1440]]) {
    const win = { width: W, height: H, rx: x => W - (1920 - x), by: y => H - (1080 - y) };
    const x = Function("win", "return " + slot[1])(win), y = Function("win", "return " + slot[2])(win);
    check(`${W}x${H}: on the screen, right edge 24 px in, under the bar`, x + w === W - 24 && y === 60, `${x},${y}`);
    if (W === 1920) check("1920x1080: SysInfo (y 336) starts below it with the 16 px gutter", y + h + 16 === 336, y + h);
}
check("it publishes its rectangle per output (screenName)", /CalendarCard \{[^}]*screenName: win\.modelData\.name/.test(desk));
check("shell.qml loads the quick-add layer", /import qs\.Widgets\.Calendar/.test(read("shell.qml")) && /^\s*CalendarEditor \{\}/m.test(read("shell.qml")));
check("ShellState has the calendar modal", /property bool calendarOpen/.test(read("Services/ShellState.qml")) && /"notes", "calendar"\]/.test(read("Services/ShellState.qml")) && /\|\| calendarOpen/.test(read("Services/ShellState.qml")));
check("the layer has its rule in decorations.conf", /apothecary-calendar\)\$, blur on, ignore_alpha 0\.35, animation fade/.test(fs.readFileSync(path.join(repo, "hypr/decorations.conf"), "utf8")));
check("the layer namespace is apothecary-calendar", /namespace: "apothecary-calendar"/.test(read("Widgets/Calendar/CalendarEditor.qml")));
check("the shared CLI is byte-identical with Overworld's copy (when that checkout is there)", (() => {
    const o = path.join(process.env.HOME || "", "Projects/overworld-hyprland/scripts/hypr-gcal");
    return !fs.existsSync(o) || fs.readFileSync(o).equals(fs.readFileSync(path.join(repo, "scripts/hypr-gcal")));
})());

// ---- CalendarPlace.js
const ctx = {};
vm.runInNewContext(read("Widgets/Calendar/CalendarPlace.js").replace(".pragma library", ""), ctx);
const W = 1920, H = 1080, pw = 420, ph = 226, grid = 2, m = 24;
const place = r => ctx.place(r, W, H, pw, ph, grid, m);
const onScreen = p => p.x >= m && p.y >= m && p.x + pw <= W - m && p.y + ph <= H - m;
const at = (x, y) => ({ x, y, w: 380, h: 260, shown: true });
let p = place(null);
check("no card: the middle of the screen", p.x === 750 && p.y === 428, JSON.stringify(p));
p = place({ ...at(1516, 60), shown: false });
check("card hidden: the middle of the screen", p.x === 750 && p.y === 428, JSON.stringify(p));
p = place(at(1516, 60));
check("default slot: kept on the screen and over the card", onScreen(p) && p.x < 1516 + 380 && p.x + pw > 1516 && p.y < 60 + 260 && p.y + ph > 60, JSON.stringify(p));
p = place(at(700, 400));
check("middle of the desk: centred on the card", p.x === 680 && p.y === 418, JSON.stringify(p));
for (const [x, y] of [[0, 0], [1540, 0], [0, 820], [1540, 820]]) check(`dragged to a corner (${x},${y}): on the screen`, onScreen(place(at(x, y))), JSON.stringify(place(at(x, y))));
p = place(at(701, 403));
check("on the grid", p.x % grid === 0 && p.y % grid === 0, JSON.stringify(p));

console.log("calendar-layout: " + fails + " failed");
process.exit(fails ? 1 : 0);
