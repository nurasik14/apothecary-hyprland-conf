#!/usr/bin/env node
// Does the Notes card fit the default layout, and does its editor stay on the screen?  Reads the real slots out of DesktopWidgets.qml and the sizes out of
// each card's own file, so it follows the code.   node tests/notes-layout.test.js
const fs = require("fs"), path = require("path"), vm = require("vm");
const root = path.join(__dirname, "..", "quickshell");
const qml = fs.readFileSync(path.join(root, "Widgets/DesktopWidgets.qml"), "utf8");
let fails = 0;
const check = (name, ok, extra) => { console.log((ok ? "PASS " : "FAIL ") + name + (extra !== undefined ? "  [" + extra + "]" : "")); if (!ok) fails++; };

const dirs = { WeatherCard: "Weather", CalendarCard: "Calendar", MusicCard: "Music", SysInfoCard: "SysInfo", BrewTimerCard: "BrewTimer",
               CavaCard: "Cava", HerbCard: "HerbOfDay", QuoteCard: "Quote", ProjectsCard: "Projects", NotesCard: "Notes" };
function sizeOf(type) {
    const f = fs.readFileSync(path.join(root, "Widgets", dirs[type], type + ".qml"), "utf8");
    return { w: +f.match(/^ {4}width: (\d+)/m)[1], h: +f.match(/^ {4}height: (\d+)/m)[1] };
}
const slots = [...qml.matchAll(/^\s*(\w+Card)\s*\{ id: (\w+);.*?defaultX: ([^;]+); defaultY: ([^;}]+?)\s*[;}]/gm)]
    .map(m => ({ type: m[1], id: m[2], xe: m[3], ye: m[4], ...sizeOf(m[1]) }));
check("10 cards found in DesktopWidgets.qml", slots.length === 10, slots.length);

const rectsAt = (W, H) => slots.map(s => {
    const win = { width: W, height: H, rx: x => W - (1920 - x), by: y => H - (1080 - y) };
    const ev = e => Function("win", "Math", "return " + e)(win, Math);
    return { id: s.id, x: ev(s.xe), y: ev(s.ye), w: s.w, h: s.h };
});
const overlap = (a, b) => a.x < b.x + b.w && b.x < a.x + a.w && a.y < b.y + b.h && b.y < a.y + a.h;
for (const [W, H] of [[1920, 1080], [1920, 1200], [2560, 1440], [3840, 2160]]) {
    const r = rectsAt(W, H), n = r.find(c => c.id === "notes");
    const hit = r.filter(c => c.id !== "notes" && overlap(n, c)).map(c => c.id);
    check(`${W}x${H}: Notes overlaps no card`, hit.length === 0, hit.join(","));
    check(`${W}x${H}: Notes is on the screen, inside the bottom margin`, n.x >= 0 && n.x + n.w <= W && n.y + n.h <= H - 24, `${n.x},${n.y}`);
    const pairs = [];
    r.forEach((a, i) => r.slice(i + 1).forEach(b => { if (overlap(a, b)) pairs.push(a.id + "/" + b.id); }));
    check(`${W}x${H}: no two cards overlap`, pairs.length === 0, pairs.join(" "));
}
const n1080 = rectsAt(1920, 1080).find(c => c.id === "notes");
check("1920x1080: Notes keeps out of the art zone (x 520–1420, y 180–780)", n1080.y >= 780, n1080.y);
check("WidgetsState lists the card", /id: "notes",\s+cjk: "札记"/.test(fs.readFileSync(path.join(root, "Widgets/Services/WidgetsState.qml"), "utf8")));
check("the input mask has a Region for it", /Region \{ item: win\.shown && notes\.shown \? notes : null \}/.test(qml));

// ---- NotesPlace.js
const ctx = {};
vm.runInNewContext(fs.readFileSync(path.join(root, "Widgets/Notes/NotesPlace.js"), "utf8").replace(".pragma library", ""), ctx);
const W = 1920, H = 1080, w = 340, h = 310, grid = 2, m = 24;
const place = r => ctx.place(r, W, H, w, h, grid, m);
const onScreen = p => p.x >= m && p.y >= m && p.x + w <= W - m && p.y + h <= H - m;
const at = (x, y) => ({ x, y, w: 226, h: 148, shown: true });
let p = place(null);
check("no card: the middle of the screen", p.x === 790 && p.y === 385 + 1, JSON.stringify(p));
p = place({ ...at(1178, 854), shown: false });
check("card hidden: the middle of the screen", p.x === 790 && p.y === 385 + 1, JSON.stringify(p));
p = place(at(1178, 854));
check("default slot: over the slip, kept on the screen", onScreen(p) && p.x <= 1178 && p.x + w >= 1178 + 226, JSON.stringify(p));
check("…and it still covers the slip", p.y <= 854 && p.y + 240 >= 854, p.y);
p = place(at(300, 300));
check("middle of the desk: centred on the slip, a little above it", p.x === 244 && p.y === 292, JSON.stringify(p));
for (const [x, y] of [[0, 0], [1700, 0], [0, 930], [1700, 930]]) check(`dragged to a corner (${x},${y}): on the screen`, onScreen(place(at(x, y))), JSON.stringify(place(at(x, y))));
p = place(at(501, 303));
check("on the grid", p.x % grid === 0 && p.y % grid === 0, JSON.stringify(p));

console.log("notes-layout: " + fails + " failed");
process.exit(fails ? 1 : 0);
