#!/usr/bin/env python3
"""WCAG contrast spot checks on real screenshots.

For every region (x, y, w, h) the background is the most common colour and the
text colour is the pixel whose luminance is furthest from it (a fully covered
glyph pixel; anti-aliased edges are lighter/darker intermediates and ignored).
Prints the ratio and PASS/FAIL against 4.5 (body) or 3.0 (large/UI)."""
import subprocess, sys, collections, os

HERE = os.path.dirname(os.path.abspath(__file__))
SHOTS = os.path.join(HERE, "screenshots")

def pixels(png, x, y, w, h):
    out = subprocess.check_output(
        ["magick", png, "-crop", f"{w}x{h}+{x}+{y}", "+repage", "-depth", "8", "txt:-"], text=True)
    px = []
    for line in out.splitlines()[1:]:
        hexpart = line.split("#")[1].split()[0]
        px.append(tuple(int(hexpart[i:i + 2], 16) for i in (0, 2, 4)))
    return px

def lum(c):
    def ch(v):
        v /= 255
        return v / 12.92 if v <= 0.03928 else ((v + 0.055) / 1.055) ** 2.4
    r, g, b = c
    return 0.2126 * ch(r) + 0.7152 * ch(g) + 0.0722 * ch(b)

def ratio(a, b):
    la, lb = sorted((lum(a), lum(b)), reverse=True)
    return (la + 0.05) / (lb + 0.05)

SPOTS = {
    "light": [
        ("qa-17-on-light.png", "bar clock 16:49",            880,   6,  60, 20, 4.5),
        ("qa-17-on-light.png", "card title bar 天气|WEATHER", 190,  66, 140, 20, 3.0),
        ("qa-17-on-light.png", "card body Kowloon",           370, 108, 110, 26, 4.5),
        ("qa-17-on-light.png", "card body SysInfo Fedora 44", 1710,384, 110, 20, 4.5),
        ("qa-17-on-light.png", "quote body italic",          1460, 906, 420, 26, 4.5),
        ("qa-17-on-light.png", "brew Resting·2 min left",     140, 916, 150, 20, 4.5),
        ("qa-17-on-light.png", "muted: weather Precipitation", 40, 180, 130, 18, 4.5),
        ("qa-17-on-light.png", "muted: weather feels 29°",    410, 212,  60, 18, 4.5),
        ("qa-17-on-light.png", "muted: sysinfo label OS",    1640, 384,  50, 18, 4.5),
        ("qa-03-launcher-kit.png", "launcher selected drawer kitty", 700, 352, 60, 20, 4.5),
        ("qa-03-launcher-kit.png", "launcher search text kit",       590, 300, 60, 20, 4.5),
        ("qa-09-notif-popups.png", "notification body (normal)",   1560, 216, 200, 20, 4.5),
        ("qa-09-notif-popups.png", "notification critical body",   1560, 108, 100, 20, 4.5),
        ("qa-04-network.png",      "network connected row",        1520, 164, 190, 20, 4.5),
        ("qa-04-network.png",      "network plain row <campus-wifi>",    1520, 252, 100, 20, 4.5),
    ],
    "dark": [
        ("qa-17-on-dark.png", "bar clock 16:48",               880,   6,  60, 20, 4.5),
        ("qa-17-on-dark.png", "card title bar 日历|CALENDAR",  1660,  66, 160, 20, 3.0),
        ("qa-17-on-dark.png", "card body SysInfo Fedora 44",   1710, 384, 110, 20, 4.5),
        ("qa-17-on-dark.png", "quote body italic",             1460, 906, 420, 26, 4.5),
        ("qa-17-on-dark.png", "cava status silence",           1810, 696,  70, 20, 4.5),
        ("qa-17-on-dark.png", "herb body Panax ginseng",        780, 934, 250, 20, 4.5),
        ("qa-17-on-dark.png", "calendar today seal 29",        1696, 258,  20, 20, 3.0),
        ("qa-17-on-dark.png", "muted: sysinfo label OS",       1640, 384,  50, 18, 4.5),
        ("qa-17-on-dark.png", "muted: weather feels 29°",       410, 212,  60, 18, 4.5),
        ("qa-17-on-dark.png", "muted: quote attribution",      1700, 934, 190, 18, 4.5),
    ],
}

fails = 0
for mode, spots in SPOTS.items():
    print(f"\n### {mode}")
    print("| spot | background | text | ratio | min | result |")
    print("|---|---|---|---|---|---|")
    for png, name, x, y, w, h, need in spots:
        px = pixels(os.path.join(SHOTS, png), x, y, w, h)
        bg = collections.Counter(px).most_common(1)[0][0]
        lb = lum(bg)
        fg = max(px, key=lambda c: abs(lum(c) - lb))
        r = ratio(fg, bg)
        ok = r >= need
        fails += not ok
        hx = lambda c: "#%02x%02x%02x" % c
        print(f"| {name} ({png} +{x}+{y}) | {hx(bg)} | {hx(fg)} | {r:.2f} | {need} | {'PASS' if ok else 'FAIL'} |")
print(f"\nfailures: {fails}")
sys.exit(1 if fails else 0)
