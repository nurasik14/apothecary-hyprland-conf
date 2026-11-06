pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services

/*  ProjectsService — 工程 · the to-do list behind the Projects card (Widgets/Projects/): what is built, what is still in progress.
 *    File       ~/.local/share/hypr-projects/projects.json, ONE list shared with Overworld and the stock desktop (`hypr-projects`);
 *               env HYPR_PROJECTS_FILE overrides it (tests).
 *               {"items": [{"id", "title", "note"?, "status": "progress"|"built", "created": ISO, "built_at"?: ISO}]}
 *               Created by the first add (an empty list is never invented).
 *    Reading    FileView with watchChanges, so `hypr-projects …`, the other theme and hand edits show up at once.
 *    Writing    every change is a read-modify-write run by <repo>/scripts/hypr-projects (`raw <op>`) under flock and IN PLACE
 *               (`cat tmp > file`, never mv): the card, the CLI and the other theme cannot disagree or lose each other's writes.
 *               The list on screen is whatever the file says: no optimistic copy.
 *    items / inProgress / built / ordered     file order · unchecked (file order) · checked, newest first · both, numbered like
 *               `apothecary projects list`
 *    add(title, note, built) · remove(id) · toggle(id) · setBuilt(id, bool) · rename(id, title, note) · move(id, ±1) · clearBuilt()
 *    undoRemove()    brings back the last remove / clearBuilt for 5 s (property `undo` = {title, count, entries} while possible)
 *    find(query)     {item} | {error}: number from the list, id, title (exact, then prefix, then contains)
 *    Dialog      ShellState.projectsOpen (one modal surface at a time) + editId: Widgets/Projects/ProjectsDialog.qml
 *    IPC         qs -c apothecary ipc call projects open | add <title> | toggle <n|id|title> | remove … | done … | undone … | rm … |
 *                undo | edit <n|title> | list | status
 */
Singleton {
    id: root
    readonly property string path: Quickshell.env("HYPR_PROJECTS_FILE")
        || ((Quickshell.env("XDG_DATA_HOME") || (Quickshell.env("HOME") + "/.local/share")) + "/hypr-projects/projects.json")
    readonly property string script: Theme.repoDir + "/scripts/hypr-projects"

    property var items: []
    property bool loaded: false
    readonly property var inProgress: items.filter(i => i.status !== "built")
    readonly property var built: items.map((it, k) => ({ it: it, k: k })).filter(e => e.it.status === "built")
        .sort((a, b) => { const x = a.it.built_at || "", y = b.it.built_at || ""; return x < y ? 1 : x > y ? -1 : b.k - a.k; })
        .map(e => e.it)
    readonly property var ordered: inProgress.concat(built)
    readonly property int count: items.length

    signal projectAdded(var item)
    signal projectBuilt(var item)
    signal projectRemoved(var item)

    // ---------------------------------------------------------------- reading
    FileView {
        id: file
        path: root.path
        blockLoading: true
        watchChanges: true
        printErrors: false
        onLoaded: root.apply(text())
        onLoadFailed: root.apply("")
        onFileChanged: reread.restart()
    }
    // a write that is in flight truncates the file first: read again a moment later instead of believing an empty / half-written file
    Timer { id: reread; interval: 60; onTriggered: { root.rereads = 0; file.reload(); } }
    Timer {
        id: settle; interval: 120
        onTriggered: { root.rereads++; file.reload(); }
    }
    property int rereads: 0
    // a missing file is not watched until it exists: look again shortly after our own writes (apply() finds it)
    Timer { id: afterWrite; interval: 250; onTriggered: file.reload() }
    // an old ~/.config/overworld/projects.json is moved over once (scripts/hypr-projects migrate), then the list is read again
    Process { id: migrator; command: ["bash", root.script, "-f", root.path, "migrate"]; onExited: file.reload() }
    Component.onCompleted: migrator.running = true
    // the other theme / the CLI may create the file while this shell runs: a missing file is polled slowly
    Timer { interval: 4000; repeat: true; running: !root.loaded || root.count === 0; onTriggered: file.reload() }

    function apply(t) {
        let list = null;
        const s = String(t || "").trim();
        if (s.length) {
            try {
                const o = JSON.parse(s);
                if (o && Array.isArray(o.items)) list = o.items.filter(i => i && typeof i === "object" && typeof i.id === "string" && typeof i.title === "string");
            } catch (e) { list = null; }
            if (list === null) {                         // unreadable now: keep what is shown, try again (an external edit mid-save)
                if (root.rereads < 4) settle.restart();
                else console.warn("ProjectsService:", root.path, "is not valid JSON; keeping the list on screen");
                return;
            }
        } else {                                         // empty or missing: a real "no projects" unless we are mid-write
            if (root.loaded && root.items.length > 0 && root.rereads < 1) { settle.restart(); return; }
            list = [];
        }
        root.rereads = 0;
        const old = root.items, first = !root.loaded;
        const key = JSON.stringify(list);
        if (!first && key === root.lastKey) return;        // same list (our own write coming back, the slow poll): keep the rows, hover and animations
        root.lastKey = key;
        root.loaded = true;
        if (first) { root.items = list; return; }
        const ch = root.changes(old, list);
        if (ch.built.length) { root.justBuilt = ch.built[ch.built.length - 1].id; justBuiltTimer.restart(); }   // set before the rows are rebuilt: the new row stamps itself
        root.items = list;
        ch.added.forEach(i => root.projectAdded(i));
        ch.built.forEach(i => root.projectBuilt(i));
        ch.removed.forEach(i => root.projectRemoved(i));
    }
    property string lastKey: ""
    property string justBuilt: ""                      // id of the project that became built a moment ago (the row presses its seal 成)
    Timer { id: justBuiltTimer; interval: 2000; onTriggered: root.justBuilt = "" }
    function changes(oldList, newList) {              // what a reload changed: {added, built, removed} (an add as built counts in both)
        const before = {}, now = {}, out = { added: [], built: [], removed: [] };
        oldList.forEach(i => { before[i.id] = i; });
        newList.forEach(i => { now[i.id] = i; });
        newList.forEach(i => {
            const o = before[i.id];
            if (!o) { out.added.push(i); if (i.status === "built") out.built.push(i); }
            else if (o.status !== "built" && i.status === "built") out.built.push(i);
        });
        oldList.forEach(o => { if (!now[o.id]) out.removed.push(o); });
        return out;
    }

    // ---------------------------------------------------------------- writing (one script run at a time, in order)
    property var queue: []
    function run(args) {
        root.queue = root.queue.concat([args]);
        if (!runner.running) root.next();
    }
    function next() {
        if (root.queue.length === 0) return;
        runner.command = ["bash", root.script, "-f", root.path, "raw"].concat(root.queue[0]);
        runner.running = true;
    }
    Process {
        id: runner
        stderr: StdioCollector { id: errOut }
        onExited: code => {
            if (code !== 0) console.warn("ProjectsService:", String(errOut.text).trim() || ("hypr-projects exited " + code));
            root.queue = root.queue.slice(1);
            afterWrite.restart();
            if (root.queue.length > 0) root.next();
        }
    }

    function clean(s) { return String(s || "").replace(/\s+/g, " ").trim(); }
    function add(title, note, built) {
        const t = clean(title);
        if (!t.length) return false;
        run(["add", t, clean(note), built ? "built" : "progress"]);
        return true;
    }
    function toggle(id) { run(["toggle", id]); }
    function setBuilt(id, on) { run(["set", id, on ? "built" : "progress"]); }
    function rename(id, title, note) {
        const t = clean(title);
        if (!t.length) return false;
        run(["edit", id, t, clean(note)]);
        return true;
    }
    function move(id, delta) { run(["move", id, String(delta > 0 ? 1 : -1)]); }
    function byId(id) { for (let i = 0; i < items.length; i++) if (items[i].id === id) return items[i]; return null; }

    // ---- undo of remove / clearBuilt
    property var undo: null
    function rememberRemoved(entries) {                      // removes within the 5 s window pile up: Undo brings back all, last first
        if (entries.length === 0) return;
        const batches = (root.undo ? root.undo.batches : []).concat([entries]);
        const count = batches.reduce((n, b) => n + b.length, 0);
        root.undo = { title: count === 1 ? entries[0].item.title : "", count: count, batches: batches, entries: entries };
        undoTimer.restart();
    }
    Timer { id: undoTimer; interval: 5000; onTriggered: root.undo = null }
    function remove(id) {
        const k = items.findIndex(i => i.id === id);
        if (k < 0) return false;
        rememberRemoved([{ item: items[k], index: k }]);
        run(["remove", id]);
        return true;
    }
    function clearBuilt() {
        const entries = [];
        items.forEach((it, k) => { if (it.status === "built") entries.push({ item: it, index: k }); });
        if (entries.length === 0) return 0;
        rememberRemoved(entries);
        run(["clearbuilt"]);
        return entries.length;
    }
    function undoRemove() {
        const u = root.undo;
        if (!u) return false;
        root.undo = null;
        undoTimer.stop();
        u.batches.slice().reverse().forEach(b => b.slice().sort((a, c) => a.index - c.index).forEach(e => run(["insert", JSON.stringify(e.item), String(e.index)])));
        return true;
    }

    // ---------------------------------------------------------------- lookup (same rules as `resolve` in scripts/hypr-projects)
    function find(query) {
        const q = String(query || "").trim();
        if (!q.length) return { error: "no project given" };
        const list = root.ordered;
        if (/^\d+$/.test(q)) {
            const n = parseInt(q);
            if (n >= 1 && n <= list.length) return { item: list[n - 1], number: n };
        }
        const byId = list.filter(i => i.id === q);
        if (byId.length) return { item: byId[0] };
        const l = q.toLowerCase();
        const ex = list.filter(i => i.title.toLowerCase() === l);
        if (ex.length === 1) return { item: ex[0] };
        let m = list.filter(i => i.title.toLowerCase().startsWith(l));
        if (m.length === 0) m = list.filter(i => i.title.toLowerCase().indexOf(l) >= 0);
        if (m.length === 1) return { item: m[0] };
        return { error: m.length === 0 ? "no project matches '" + q + "'" : "'" + q + "' matches " + m.length + " projects: type more of the title or use its number" };
    }
    function numberOf(item) { return root.ordered.findIndex(i => i.id === item.id) + 1; }

    // ---------------------------------------------------------------- dialog (Widgets/Projects/ProjectsDialog.qml)
    property string editId: ""
    readonly property bool dialogOpen: ShellState.projectsOpen
    function openDialog(id) {
        root.editId = id || "";
        ShellState.open("projects");          // closes any other modal surface first
    }
    function closeDialog() { ShellState.close("projects") }

    // ---------------------------------------------------------------- IPC
    function lineOf(it) { return numberOf(it) + ". [" + (it.status === "built" ? "x" : " ") + "] " + it.title; }
    function act(query, what) {                              // shared by the IPC verbs: find → do → one-line answer
        const r = root.find(query);
        if (r.error) return r.error;
        const it = r.item;
        if (what === "toggle") { root.toggle(it.id); return (it.status === "built" ? "back in progress: " : "built: ") + it.title; }
        if (what === "done") { if (it.status === "built") return "already built: " + it.title; root.setBuilt(it.id, true); return "built: " + it.title; }
        if (what === "undone") { if (it.status !== "built") return "already in progress: " + it.title; root.setBuilt(it.id, false); return "back in progress: " + it.title; }
        if (what === "remove") { root.remove(it.id); return "removed: " + it.title; }
        if (what === "edit") { root.openDialog(it.id); return "editing: " + it.title; }
        return "?";
    }
    IpcHandler {
        target: "projects"
        function open(): void { root.openDialog("") }
        function add(title: string): string { return root.add(title, "", false) ? "added: " + root.clean(title) : "nothing to add" }
        function toggle(which: string): string { return root.act(which, "toggle") }
        function done(which: string): string { return root.act(which, "done") }
        function undone(which: string): string { return root.act(which, "undone") }
        function remove(which: string): string { return root.act(which, "remove") }
        function rm(which: string): string { return root.act(which, "remove") }
        function edit(which: string): string { return root.act(which, "edit") }
        function undo(): string { return root.undoRemove() ? "restored" : "nothing to undo" }
        function list(): string { return root.ordered.length ? root.ordered.map(root.lineOf).join("\n") : "no projects yet" }
        function status(): string { return root.inProgress.length + " in progress, " + root.built.length + " built" }
    }
}
