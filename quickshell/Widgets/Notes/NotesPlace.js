.pragma library
/*  NotesPlace.js — where the editor's slip goes (pure JS, checked by tests/notes-layout.test.js).
 *    place(rect, W, H, w, h, grid, margin) → {x, y}    rect = the card's slip {x, y, w, h, shown} or null; W×H the output; w×h the form
 *  Centred over the slip horizontally, the top a bit above it, then kept on the screen, on a `grid` px grid; no card on the screen (hidden) =
 *  the middle of the screen.
 */
function place(rect, W, H, w, h, grid, margin) {
    const snap = v => Math.round(v / grid) * grid;
    if (!rect || !rect.shown) return { x: snap((W - w) / 2), y: snap((H - h) / 2) };
    const x = rect.x + (rect.w - w) / 2;
    const y = rect.y - 4 * grid;
    const maxX = W - w - margin, maxY = H - h - margin;
    return { x: snap(Math.max(margin, Math.min(maxX, x))), y: snap(Math.max(margin, Math.min(maxY, y))) };
}
