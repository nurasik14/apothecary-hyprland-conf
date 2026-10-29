#!/usr/bin/python3
"""Turn the scanned 植物名實圖考 herb plates into theme-recolourable ink masks.

    assets/pd/plates/make-masks.py            # raw/*.jpg -> <herb-id>.webp (skips existing)
    assets/pd/plates/make-masks.py --force    # rebuild everything
    assets/pd/plates/make-masks.py ginseng    # one plate

Output: RGBA WebP, ~560 px tall, black RGB, alpha = ink coverage.  Render it
with `background: <ink colour>; mask: url(plate.webp) center/contain no-repeat`
(CSS) or as an Image + ColorOverlay / MultiEffect colorization in QML, so the
same plate works on paper (light) and lacquer (dark) grounds.

Recipe (period-authentic-ui-design skill, "ink-only alpha masks"):
  grayscale -> paper = 70th percentile -> ink = clip((paper-18-v)/(paper-58), 0, 1)
  -> zero values < 0.08 -> blank a 2.5 % border (scan edges) -> crop to the
  bounding box of ink > 0.25 -> resize to 560 px tall -> RGBA WebP, black RGB.

Uses the system python (/usr/bin/python3: numpy + Pillow).  Running it also
updates the "plate" field of quotes/herbs.json for every herb id that has a
finished mask (relative path from the repo root), and nulls ids whose mask is
missing, so the HerbService never points at a file that does not exist.
"""
import json
import pathlib
import sys

import numpy as np
from PIL import Image

HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE.parents[2]
RAW = HERE / "raw"
HERBS = ROOT / "quotes" / "herbs.json"
TARGET_H = 560
BORDER = 0.025
PLATE_REL = "assets/pd/plates"


def ink_mask(src: pathlib.Path) -> Image.Image:
    img = Image.open(src).convert("L")
    v = np.asarray(img, dtype=np.float32)
    paper = float(np.percentile(v, 70))
    ink = np.clip((paper - 18.0 - v) / max(paper - 58.0, 1.0), 0.0, 1.0)
    ink[ink < 0.08] = 0.0
    h, w = ink.shape
    by, bx = int(round(h * BORDER)), int(round(w * BORDER))
    ink[:by, :] = 0; ink[-by:, :] = 0; ink[:, :bx] = 0; ink[:, -bx:] = 0
    ys, xs = np.where(ink > 0.25)
    if len(ys) == 0:
        raise SystemExit(f"{src.name}: no ink found (paper={paper:.0f})")
    pad = 6
    y0, y1 = max(ys.min() - pad, 0), min(ys.max() + pad + 1, h)
    x0, x1 = max(xs.min() - pad, 0), min(xs.max() + pad + 1, w)
    ink = ink[y0:y1, x0:x1]
    a = Image.fromarray((ink * 255).astype(np.uint8), "L")
    scale = TARGET_H / a.height
    a = a.resize((max(1, round(a.width * scale)), TARGET_H), Image.LANCZOS)
    rgba = Image.new("RGBA", a.size, (0, 0, 0, 0))
    rgba.putalpha(a)
    return rgba


def dump_herbs(items) -> str:
    """Reproduce the file's compact hand layout: header keys on one line, then
    fact / caution / maomao_note / plate on their own lines (3-space indent)."""
    head_keys = ("id", "name_en", "name_cjk", "reading", "kind")
    out = []
    for h in items:
        j = lambda k: json.dumps(h[k], ensure_ascii=False)  # noqa: E731
        lines = [", ".join(f'"{k}": {j(k)}' for k in head_keys if k in h)]
        lines += [f'"{k}": {j(k)}' for k in h if k not in head_keys]
        out.append("  {" + ",\n   ".join(lines) + "}")
    return "[\n" + ",\n".join(out) + "\n]\n"


def update_herbs_json(done: set[str]) -> int:
    herbs = json.loads(HERBS.read_text(encoding="utf-8"))
    items = herbs if isinstance(herbs, list) else herbs["herbs"]
    changed = 0
    for h in items:
        want = f"{PLATE_REL}/{h['id']}.webp" if h["id"] in done else None
        if h.get("plate") != want:
            h["plate"] = want
            changed += 1
    if changed:
        text = dump_herbs(items) if isinstance(herbs, list) else json.dumps(herbs, ensure_ascii=False, indent=2) + "\n"
        assert json.loads(text) == herbs
        HERBS.write_text(text, encoding="utf-8")
    return changed


def main(argv: list[str]) -> int:
    force = "--force" in argv
    only = {a for a in argv if not a.startswith("--")}
    made = skipped = 0
    for src in sorted(RAW.glob("*.jpg")):
        hid = src.stem
        if only and hid not in only:
            continue
        out = HERE / f"{hid}.webp"
        if out.exists() and out.stat().st_size > 0 and not force:
            skipped += 1
            continue
        m = ink_mask(src)
        m.save(out, "WEBP", lossless=False, quality=88, method=6, exact=False)
        cov = np.asarray(m.getchannel("A")).mean() / 255
        print(f"{hid}: {m.width}x{m.height}, ink coverage {cov:.1%}, {out.stat().st_size // 1024} KiB")
        made += 1
    done = {p.stem for p in HERE.glob("*.webp") if p.stat().st_size > 0}
    changed = update_herbs_json(done)
    print(f"make-masks: {made} built, {skipped} kept, {len(done)} plates total; herbs.json: {changed} plate field(s) updated")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
