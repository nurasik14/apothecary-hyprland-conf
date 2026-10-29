#!/usr/bin/env python3
"""Fetch public-domain herb plates from Wikimedia Commons.

Source: 植物名實圖考 (Zhiwu Mingshi Tukao, "Illustrated Reference of Plant
Names and Realities", Wu Qijun, 1848) — woodblock line-art plates, public
domain (PD-old-100).  Commons category: "Images from Zhiwu Mingshi Tukao".

Usage:
    assets/pd/plates/fetch-plates.py            # download missing originals to raw/
    assets/pd/plates/fetch-plates.py --credits  # print Markdown rows for CREDITS.md

Downloads go to assets/pd/plates/raw/<herb-id>.jpg (≈1200px wide thumbnails
served by upload.wikimedia.org; good enough for the ~560px ink masks).  Files
that already exist and are larger than 1 KiB are skipped.  429 responses are
retried with increasing sleeps.  Run make-masks.py afterwards.
"""
import json
import pathlib
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

HERE = pathlib.Path(__file__).resolve().parent
RAW = HERE / "raw"
API = "https://commons.wikimedia.org/w/api.php"
UA = "ApothecaryHyprland/1.0 (personal Hyprland theme; contact: nurasik12 via github.com/nurasik12) python-urllib"
THUMB_WIDTH = 1200
SLEEP = 8.0

# herb id (matches quotes/herbs.json "id") -> Commons file title
PLATES = {
    "ginseng":       "File:植物名實圖考·人參.jpg",
    "licorice":      "File:植物名實圖考·甘草.jpg",
    "ephedra":       "File:植物名實圖考·麻黃.jpg",
    "angelica":      "File:植物名實圖考·當歸.jpg",
    "safflower":     "File:植物名實圖考·紅花.jpg",
    "chrysanthemum": "File:植物名實圖考·菊圖一.jpg",
    "lotus":         "File:植物名實圖考·蓮藕.jpg",
    "jujube":        "File:植物名實圖考·棗.jpg",
    "goji":          "File:植物名實圖考·枸杞.jpg",
    "rhubarb":       "File:植物名實圖考·大黃.jpg",
    "mint":          "File:植物名實圖考·薄荷.jpg",
    "ginger":        "File:植物名實圖考·乾薑.jpg",
    "cinnamon":      "File:植物名實圖考·桂.jpg",
    "aconite":       "File:植物名實圖考·附子.jpg",
    "poppy":         "File:植物名實圖考·甖子粟.jpg",
    "oleander":      "File:植物名實圖考·夾竹桃.jpg",
    "camphor":       "File:植物名實圖考·樟.jpg",
    "mugwort":       "File:植物名實圖考·艾圖一.jpg",
    "gelsemium":     "File:植物名實圖考·鉤吻.jpg",
    "apricot":       "File:植物名實圖考·杏.jpg",
    "henbane":       "File:植物名實圖考·莨菪.jpg",
}


def api(params):
    url = API + "?" + urllib.parse.urlencode(params)
    for attempt in range(6):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": UA})
            with urllib.request.urlopen(req, timeout=60) as r:
                return json.loads(r.read())
        except urllib.error.HTTPError as e:
            if e.code == 429:
                wait = 10 * (attempt + 1)
                print(f"  429 from API, sleeping {wait}s", file=sys.stderr)
                time.sleep(wait)
                continue
            raise
    raise RuntimeError("API kept returning 429")


def imageinfo(titles):
    """title -> {url, thumburl, descriptionurl, artist, licence, width, height}"""
    out = {}
    titles = list(titles)
    for i in range(0, len(titles), 25):
        batch = titles[i:i + 25]
        d = api({
            "action": "query", "format": "json", "titles": "|".join(batch),
            "prop": "imageinfo", "iiprop": "url|size|extmetadata",
            "iiextmetadatafilter": "LicenseShortName|Artist|Credit|ObjectName",
            "iiurlwidth": THUMB_WIDTH,
        })
        for p in d.get("query", {}).get("pages", {}).values():
            ii = (p.get("imageinfo") or [None])[0]
            if not ii:
                continue
            em = ii.get("extmetadata", {})
            strip = lambda s: "".join(ch for ch in s if ch not in "\n\r").strip()
            out[p["title"]] = {
                "url": ii["url"], "thumburl": ii.get("thumburl", ii["url"]),
                "page": ii["descriptionurl"], "width": ii["width"], "height": ii["height"],
                "artist": strip(_untag(em.get("Artist", {}).get("value", ""))) or "unknown",
                "licence": em.get("LicenseShortName", {}).get("value", "unknown"),
            }
        time.sleep(1.0)
    return out


def _untag(s):
    import re
    return re.sub(r"<[^>]+>", "", s)


def download(url, dest):
    for attempt in range(6):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": UA})
            with urllib.request.urlopen(req, timeout=120) as r:
                data = r.read()
            if len(data) > 1024:
                dest.write_bytes(data)
                return True
        except urllib.error.HTTPError as e:
            if e.code == 429:
                # upload.wikimedia.org answers bursts with 429 + Retry-After (often 600 s);
                # honour it, otherwise the block is extended
                try:
                    wait = min(int(e.headers.get("Retry-After", "0")), 900)
                except ValueError:
                    wait = 0
                wait = wait or 60 * (attempt + 1)
                print(f"  429 from upload server, sleeping {wait}s (Retry-After)", file=sys.stderr)
                time.sleep(wait)
                continue
            print(f"  HTTP {e.code} for {url}", file=sys.stderr)
            return False
        except Exception as e:  # noqa: BLE001
            print(f"  error {e}; retrying", file=sys.stderr)
            time.sleep(5)
    return False


def main():
    credits_only = "--credits" in sys.argv
    RAW.mkdir(parents=True, exist_ok=True)
    info = imageinfo(PLATES.values())
    if credits_only:
        for hid, title in PLATES.items():
            m = info.get(title)
            raw = RAW / f"{hid}.jpg"
            if not m or not (raw.exists() and raw.stat().st_size > 1024):
                continue   # only plates that were actually downloaded get a credit row
            print(f"| assets/pd/plates/{hid}.webp (ink mask from raw/{hid}.jpg) | [{title[5:]}]({m['page']}) — 植物名實圖考 (Wu Qijun, 1848), via Wikimedia Commons | {m['artist']} | {m['licence']} (PD-old-100, public domain) |")
        return 0
    got = skipped = failed = 0
    for hid, title in PLATES.items():
        dest = RAW / f"{hid}.jpg"
        if dest.exists() and dest.stat().st_size > 1024:
            skipped += 1
            continue
        m = info.get(title)
        if not m:
            print(f"{hid}: {title} not found on Commons", file=sys.stderr)
            failed += 1
            continue
        print(f"{hid}: {title} ({m['width']}x{m['height']}, {m['licence']})")
        if download(m["thumburl"], dest):
            got += 1
        else:
            failed += 1
        time.sleep(SLEEP)
    print(f"fetch-plates: {got} downloaded, {skipped} already present, {failed} failed (dest: {RAW})")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
