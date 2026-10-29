#!/usr/bin/env bash
# scripts/make-wallpapers.sh — build the Apothecary Hyprland wallpaper sets and
# widget/lock/login art from the raw character art in assets/art/raw/.
#
#   assets/fetch-art.sh              # 1. download the raw images (gitignored)
#   scripts/make-wallpapers.sh       # 2. build everything below
#
# Outputs (all gitignored, 1920x1080 unless noted):
#   assets/wallpapers/light/NN-slug.png   "Apothecary" daytime set (rice-paper ground)
#   assets/wallpapers/dark/NN-slug.png    "Inner Palace" night set (lacquer ground)
#   assets/art/portrait-maomao.png        512x512 avatar, face centred
#   assets/art/lock-{light,dark}.png      hyprlock backgrounds (calm left area for the clock)
#   assets/art/sddm-{light,dark}.png      SDDM backgrounds (same idea)
#   assets/art/fastfetch-maomao{,-dark}.png   420px wide bust on paper / lacquer
#   assets/art/launcher-maomao.png        600px tall bust, soft ink-wash alpha edge
#   qa/screenshots/art-contact-sheet.png  montage of every wallpaper for review
#
# Idempotent: outputs that already exist are skipped unless FORCE=1.
#   ONLY=03 scripts/make-wallpapers.sh      rebuild one wallpaper number
#   WIDGETS=1 scripts/make-wallpapers.sh    rebuild the widget/lock art only
# Requirements: ImageMagick 7 (magick); optional realesrgan-ncnn-vulkan for
# upscaling small scans (skipped gracefully if absent).
#
# Composition rules (BRIEF.md §2, docs/REQUESTS.md design-director note):
#   * Portrait art (novel covers, inserts, tall key visuals) is shown as a
#     ~840px "hanging scroll" column on the design-director's paper / lacquer
#     textures (assets/pd/textures), feathered with an ink-wash edge.  The
#     column sits at x≈820–1660 so Maomao's face lands inside the widget-free
#     art zone x 520–1420 / y 180–780; the left ~800px stay calm for widgets.
#   * Each crop is art-directed (fractions of the raw image): title columns,
#     volume badges, author/publisher logos are cropped away, the face stays
#     intact and fills the column at desktop scale.  Crops are upscaled with
#     Real-ESRGAN (anime model) AFTER cropping, only when they are small.
#   * Wide anime visuals are cover-cropped to 16:9 and tint-matched per mode.
#   * A faint vertical 薬屋のひとりごと inscription + a small vermilion 猫 seal
#     sit in the right margin of the scroll (bottom-right on wide images).

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RAW="$ROOT/assets/art/raw"
ART="$ROOT/assets/art"
WORK="$ART/work"
OUT="$ROOT/assets/wallpapers"
QA="$ROOT/qa/screenshots"
TEX="$ROOT/assets/pd/textures"
FONT_DIR="$HOME/.local/share/fonts/apothecary"
F_SEAL="$FONT_DIR/MaShanZheng-Regular.ttf"
F_TITLE="$FONT_DIR/ShipporiMinchoB1-Regular.ttf"
ESRGAN="$HOME/.local/bin/realesrgan-ncnn-vulkan"
ESRGAN_MODELS="$HOME/.local/opt/realesrgan/models"
FORCE="${FORCE:-0}"
ONLY="${ONLY:-}"            # e.g. ONLY=03 to rebuild one wallpaper number
WIDGETS="${WIDGETS:-0}"     # WIDGETS=1 -> only widget/lock art

W=1920; H=1080
LIGHT_BG="#f0e9da"; LIGHT_INK="#2a2420"     # mean of paper.png / lacquer.png
DARK_BG="#231e1b";  DARK_INK="#e9dfc9"
SEAL_RED="#b5332e"
COL_W=840                   # default scroll column width
COL_MARGIN=260              # default distance from the right canvas edge
UPSCALE_BELOW=1100          # x4-upscale a crop whose WIDTH is below this (then resized down)

mkdir -p "$WORK" "$OUT/light" "$OUT/dark" "$QA"
export MAGICK_TMPDIR="${TMPDIR:-/tmp}"

log() { printf '%s\n' "$*" >&2; }
have_font() { [ -f "$1" ]; }
fresh() { # fresh <output> -> true if it must be (re)built
  [ "$FORCE" = 1 ] && return 0
  [ ! -s "$1" ]
}

# ---------------------------------------------------------------- grounds ---
# The design-director's textures are the canvas grounds; fall back to a
# generated grain if they are missing (older checkouts).
make_textures() {
  local light="$WORK/paper-light.png" dark="$WORK/paper-dark.png"
  if fresh "$light"; then
    if [ -s "$TEX/paper.png" ]; then
      magick "$TEX/paper.png" -resize "${W}x${H}^" -gravity center -extent "${W}x${H}" -strip "$light"
    else
      log "texture: rice paper (generated fallback)"
      magick -size ${W}x${H} xc:"$LIGHT_BG" \
        \( -size ${W}x${H} xc:gray50 -seed 11 +noise Gaussian -attenuate 0.35 -colorspace gray -blur 0x0.5 \) \
          -compose overlay -composite -strip "$light"
    fi
  fi
  if fresh "$dark"; then
    if [ -s "$TEX/lacquer.png" ]; then
      magick "$TEX/lacquer.png" -resize "${W}x${H}^" -gravity center -extent "${W}x${H}" -strip "$dark"
    else
      log "texture: lacquer (generated fallback)"
      magick -size ${W}x${H} xc:"$DARK_BG" \
        \( -size ${W}x${H} xc:gray50 -seed 13 +noise Gaussian -attenuate 0.22 -colorspace gray -blur 0x0.4 \) \
          -compose overlay -composite -strip "$dark"
    fi
  fi
}

# ----------------------------------------------------------------- helpers ---
img_w() { magick identify -ping -format '%w' "$1"; }
img_h() { magick identify -ping -format '%h' "$1"; }

# crop_frac <src> <x0,y0,x1,y1> <out>  — crop by fractions of width/height
crop_frac() {
  local src="$1" out="$3" w h x0 y0 x1 y1
  IFS=, read -r x0 y0 x1 y1 <<<"$2"
  w=$(img_w "$src"); h=$(img_h "$src")
  local cx cy cw ch
  cx=$(awk -v w="$w" -v f="$x0" 'BEGIN{printf "%d", w*f}')
  cy=$(awk -v h="$h" -v f="$y0" 'BEGIN{printf "%d", h*f}')
  cw=$(awk -v w="$w" -v a="$x0" -v b="$x1" 'BEGIN{printf "%d", w*(b-a)}')
  ch=$(awk -v h="$h" -v a="$y0" -v b="$y1" 'BEGIN{printf "%d", h*(b-a)}')
  magick "$src" -crop "${cw}x${ch}+${cx}+${cy}" +repage "$out"
}

# upscale_if_small <in> <cache name> -> prints the path to use.
# x4 Real-ESRGAN (anime model) on the CROP only; crops are small (<1 MP) so this
# takes a few seconds on the GPU.  Never upscale whole covers (minutes).
upscale_if_small() {
  local src="$1" out="$WORK/$2.up.png" w
  w=$(img_w "$src")
  if [ "$w" -ge "$UPSCALE_BELOW" ] || [ ! -x "$ESRGAN" ]; then printf '%s' "$src"; return; fi
  if fresh "$out"; then
    log "  upscale x4: $(basename "$src") (${w}px wide)"
    "$ESRGAN" -i "$src" -o "$out" -n realesrgan-x4plus-anime -m "$ESRGAN_MODELS" -s 4 >/dev/null 2>&1 \
      || { log "  upscale failed, using original"; rm -f "$out"; printf '%s' "$src"; return; }
  fi
  printf '%s' "$out"
}

# ink_mask <w> <h> <seed> <feather right 0|1|2> <feather bottom 0|1> <out> [tight left 0|1]
# White art area whose LEFT edge (and right / bottom when requested) dissolves
# into an irregular ink-wash feather; the top always bleeds off the canvas.
#   feather right 2 / tight left 1 = narrow feather (~50px) for crops where the
#   face sits right at that edge of the usable (text-free) area of the cover.
ink_mask() {
  local w="$1" h="$2" seed="$3" rf="$4" bf="$5" out="$6" lf="${7:-0}" cut="${8:-}"
  local l=120 t=-80 b=$((h+300)) r=$((w+300)) r2=$((w+300)) b2=$((h+300))
  [ "$lf" = 1 ] && l=50
  if [ "$rf" = 1 ]; then r=$((w-120)); r2=$((w-40)); fi
  if [ "$rf" = 2 ]; then r=$((w-50));  r2=$((w-16)); fi
  if [ "$bf" = 1 ]; then b=$((h-120)); b2=$((h-40)); fi
  local cutop=()
  if [ -n "$cut" ]; then   # soft ink-wash cutout of the top-left corner (WxH), hides a badge next to the face
    local cw="${cut%x*}" ch="${cut#*x}"
    cutop=( \( -size "${w}x${h}" xc:white -fill black -draw "roundrectangle -200,-200 $cw,$ch 70,70" -blur 0x28 \) -compose multiply -composite -clamp )
  fi
  magick -size "${w}x${h}" xc:black -fill white -draw "rectangle $l,$t $r,$b" -blur 0x60 \
    \( -size "${w}x${h}" -seed "$seed" plasma:fractal -blur 0x9 -colorspace gray -auto-level \) \
    -compose mathematics -define compose:args=0,0.55,1,-0.275 -composite -clamp \
    \( -size "${w}x${h}" xc:black -fill white -draw "rectangle 40,-80 $r2,$b2" -blur 0x22 \) \
    -compose multiply -composite -clamp \
    "${cutop[@]}" \
    -blur 0x2 -colorspace gray "$out"
}

# seal <out> — small vermilion seal with a white 猫 glyph
seal() {
  local out="$1" s=52
  if fresh "$out"; then
    if have_font "$F_SEAL"; then
      magick -size ${s}x${s} xc:"$SEAL_RED" \
        \( -size ${s}x${s} -seed 2 plasma:fractal -colorspace gray -blur 0x1 -level 30%,100% \) \
          -compose multiply -define compose:args=100 -composite \
        -fill "$SEAL_RED" -colorize 30 \
        -font "$F_SEAL" -pointsize 40 -fill "#f7efe0" -gravity center -annotate +0+3 "猫" \
        -bordercolor "#f7efe0" -border 2 -bordercolor "$SEAL_RED" -border 2 \
        -channel A -evaluate multiply 0.92 +channel "$out"
    else
      magick -size ${s}x${s} xc:"$SEAL_RED" -bordercolor "#f7efe0" -border 2 -bordercolor "$SEAL_RED" -border 2 "$out"
    fi
  fi
}

# vtitle <ink colour> <out> — faint vertical 薬屋のひとりごと
vtitle() {
  local ink="$1" out="$2"
  have_font "$F_TITLE" || { magick -size 1x1 xc:none "$out"; return; }
  if fresh "$out"; then
    magick -background none -fill "$ink" -font "$F_TITLE" -pointsize 22 -interline-spacing 4 \
      -gravity center label:"薬\n屋\nの\nひ\nと\nり\nご\nと" \
      -channel A -evaluate multiply 0.28 +channel "$out"
  fi
}

# tint_art <mode> <in> <out> — mode matching for the art itself
tint_art() {
  local mode="$1" in="$2" out="$3"
  if [ "$mode" = light ]; then
    magick "$in" \( +clone -fill "$LIGHT_BG" -colorize 100 \) -compose blend -define compose:args=8 -composite "$out"
  else
    magick "$in" -modulate 78,88 \( +clone -fill "$DARK_BG" -colorize 100 \) -compose blend -define compose:args=18 -composite "$out"
  fi
}

# decorate <mode> <in> <out> <title x> <title y> <seal x> <seal y>
decorate() {
  local mode="$1" in="$2" out="$3" tx="$4" ty="$5" sx="$6" sy="$7" ink
  [ "$mode" = light ] && ink="$LIGHT_INK" || ink="$DARK_INK"
  seal "$WORK/seal.png"; vtitle "$ink" "$WORK/vtitle-$mode.png"
  magick "$in" \
    "$WORK/vtitle-$mode.png" -geometry "+${tx}+${ty}" -composite \
    "$WORK/seal.png" -geometry "+${sx}+${sy}" -composite \
    -strip "$out"
}

# ---------------------------------------------------------- compositions ---
# compose_portrait <nn> <slug> <src> <crop x0,y0,x1,y1> [width] [right margin] [y offset] [flags]
#   The crop is scaled to the column WIDTH (never shorter than the canvas) and
#   anchored at the top (+ y offset, usually 0 or negative), so face + upper body
#   sit at desktop scale and the overflow is lost at the bottom.
#   right margin 0  -> the art bleeds off the right edge (only the left is feathered)
#   right margin >0 -> the art floats inset like a hanging scroll, feathered both sides
#   flags: L = tight left feather, R = narrow right feather (face at that edge),
#          C<w>x<h> = soft cutout of the top-left corner of the art (hides a volume badge)
compose_portrait() {
  local nn="$1" slug="$2" src="$RAW/$3" crop="$4" awant="${5:-$COL_W}" margin="${6:-$COL_MARGIN}" yoff="${7:-0}" flags="${8:-}"
  [ -n "$ONLY" ] && [ "$ONLY" != "$nn" ] && return 0
  local lo="$OUT/light/$nn-$slug.png" do="$OUT/dark/$nn-$slug.png"
  if ! fresh "$lo" && ! fresh "$do"; then return 0; fi
  [ -s "$src" ] || { log "missing raw: $src (run assets/fetch-art.sh)"; return 0; }
  log "portrait $nn $slug"
  local cut="$WORK/$nn-cut.png" art="$WORK/$nn-art.png" mask="$WORK/$nn-mask.png"
  crop_frac "$src" "$crop" "$cut"
  local base; base=$(upscale_if_small "$cut" "$nn")
  local cw ch; cw=$(img_w "$base"); ch=$(img_h "$base")
  local geom="${awant}x"
  # never shorter than the canvas: fall back to height-fit for squat crops
  if [ $(( ch * awant / cw )) -lt "$H" ]; then geom="x${H}"; fi
  magick "$base" -background white -alpha remove -alpha off \
    -filter Lanczos -resize "$geom" -unsharp 0x0.6+0.4+0.02 "$art"
  local aw ah; aw=$(img_w "$art"); ah=$(img_h "$art")
  local ax=$(( W - aw - margin )); local ay="$yoff"
  local rf=0; [ "$margin" -gt 0 ] && rf=1
  case "$flags" in *R*) [ "$rf" = 1 ] && rf=2 ;; esac
  local lf=0; case "$flags" in *L*) lf=1 ;; esac
  local cut=""; case "$flags" in *C[0-9]*) cut="${flags##*C}"; cut="${cut%%[!0-9x]*}" ;; esac
  local bf=0; [ $(( ah + ay )) -gt $(( H + 40 )) ] || bf=1   # feather the bottom if the art ends on-canvas
  ink_mask "$aw" "$ah" "$((10#$nn + 3))" "$rf" "$bf" "$mask" "$lf" "$cut"
  # inscription + seal: in the right margin when inset, else bottom-right corner
  local tx ty sx sy
  if [ "$margin" -ge 90 ]; then
    tx=$(( ax + aw + 18 )); ty=190; sx=$(( ax + aw + 14 )); sy=430
  else
    tx=$(( ax - 64 )); [ "$tx" -lt 24 ] && tx=24; ty=760; sx=$(( W - 56 - 30 )); sy=$(( H - 56 - 30 ))
  fi
  for mode in light dark; do
    local target; [ "$mode" = light ] && target="$lo" || target="$do"
    fresh "$target" || continue
    tint_art "$mode" "$art" "$WORK/$nn-tint.png"
    magick "$WORK/$nn-tint.png" "$mask" -alpha off -compose CopyOpacity -composite "$WORK/$nn-rgba.png"
    magick "$WORK/paper-$mode.png" "$WORK/$nn-rgba.png" -geometry "+${ax}+${ay}" -compose over -composite "$WORK/$nn-flat.png"
    decorate "$mode" "$WORK/$nn-flat.png" "$target" "$tx" "$ty" "$sx" "$sy"
  done
  rm -f "$WORK/$nn-cut.png" "$WORK/$nn-tint.png" "$WORK/$nn-rgba.png" "$WORK/$nn-flat.png"
}

# compose_wide <nn> <slug> <src> <gravity>   — cover-crop to 16:9, tint per mode
compose_wide() {
  local nn="$1" slug="$2" src="$RAW/$3" grav="$4"
  [ -n "$ONLY" ] && [ "$ONLY" != "$nn" ] && return 0
  local lo="$OUT/light/$nn-$slug.png" do="$OUT/dark/$nn-$slug.png"
  if ! fresh "$lo" && ! fresh "$do"; then return 0; fi
  [ -s "$src" ] || { log "missing raw: $src (run assets/fetch-art.sh)"; return 0; }
  log "wide     $nn $slug"
  local cover="$WORK/$nn-cover.png"
  magick "$src" -filter Lanczos -resize "${W}x${H}^" -gravity "$grav" -extent "${W}x${H}" +repage "$cover"
  for mode in light dark; do
    local target; [ "$mode" = light ] && target="$lo" || target="$do"
    fresh "$target" || continue
    if [ "$mode" = light ]; then
      magick "$cover" \( "$WORK/paper-light.png" \) -compose blend -define compose:args=11 -composite "$WORK/$nn-flat.png"
    else
      magick "$cover" -modulate 72,82 \( "$WORK/paper-dark.png" \) -compose blend -define compose:args=16 -composite "$WORK/$nn-flat.png"
    fi
    decorate "$mode" "$WORK/$nn-flat.png" "$target" 24 760 $(( W - 56 - 30 )) $(( H - 56 - 30 ))
  done
  rm -f "$WORK/$nn-cover.png" "$WORK/$nn-flat.png"
}

# ------------------------------------------------------------ widget art ---
# Source: the textless Touko Shino cover of volume 2 (Maomao, arms crossed on
# her knees, blue flower) — the cleanest light-novel Maomao with no text.
make_widget_art() {
  local src="$RAW/ln-v02-cover-textless.png"            # 1602x2258
  [ -s "$src" ] || { log "missing raw: $src — widget art skipped"; return 0; }

  # 512px square avatar centred on the face (head spans x 520–1200, y 140–780)
  if fresh "$ART/portrait-maomao.png"; then
    log "widget: portrait-maomao.png"
    magick "$src" -crop 900x900+410+40 +repage -filter Lanczos -resize 512x512 \
      -unsharp 0x0.5+0.3+0.02 -strip "$ART/portrait-maomao.png"
  fi

  # bust crop used by fastfetch + launcher: head + crossed arms (x 400–1440, y 20–1360)
  local bust="$WORK/bust.png"
  if fresh "$bust"; then
    magick "$src" -crop 1040x1340+400+20 +repage "$bust"
  fi

  # fastfetch: 420px wide bust on paper / lacquer, ink-wash feather on all sides
  for mode in light dark; do
    local out="$ART/fastfetch-maomao.png"; [ "$mode" = dark ] && out="$ART/fastfetch-maomao-dark.png"
    fresh "$out" || continue
    log "widget: $(basename "$out")"
    local fw=420 fh=500
    magick "$bust" -filter Lanczos -resize "${fw}x${fh}^" -gravity north -extent "${fw}x${fh}" \
      -unsharp 0x0.5+0.3+0.02 "$WORK/ff-art.png"
    tint_art "$mode" "$WORK/ff-art.png" "$WORK/ff-tint.png"
    magick -size "${fw}x${fh}" xc:black -fill white -draw "roundrectangle 30,30 $((fw-30)),$((fh-30)) 60,60" -blur 0x20 \
      \( -size "${fw}x${fh}" -seed 21 plasma:fractal -blur 0x5 -colorspace gray -auto-level \) \
      -compose mathematics -define compose:args=0,0.45,1,-0.225 -composite -clamp -blur 0x1.5 -colorspace gray "$WORK/ff-mask.png"
    magick "$WORK/ff-tint.png" "$WORK/ff-mask.png" -alpha off -compose CopyOpacity -composite "$WORK/ff-rgba.png"
    magick "$WORK/paper-$mode.png" -gravity center -crop "${fw}x${fh}+0+0" +repage \
      "$WORK/ff-rgba.png" -gravity center -compose over -composite -strip "$out"
  done

  # launcher: 600px tall bust with a soft ink-wash alpha edge (works on any ground)
  if fresh "$ART/launcher-maomao.png"; then
    log "widget: launcher-maomao.png"
    local lw=470 lh=600
    magick "$bust" -filter Lanczos -resize "${lw}x${lh}^" -gravity north -extent "${lw}x${lh}" \
      -unsharp 0x0.5+0.3+0.02 "$WORK/la-art.png"
    magick -size "${lw}x${lh}" xc:black -fill white -draw "roundrectangle 48,40 $((lw-48)),$((lh-30)) 160,160" -blur 0x34 \
      \( -size "${lw}x${lh}" -seed 23 plasma:fractal -blur 0x8 -colorspace gray -auto-level \) \
      -compose mathematics -define compose:args=0,0.4,1,-0.2 -composite -clamp \
      \( -size "${lw}x${lh}" gradient:white-black -level 0%,100% -gamma 0.35 \) -compose multiply -composite \
      -blur 0x3 -colorspace gray "$WORK/la-mask.png"
    magick "$WORK/la-art.png" "$WORK/la-mask.png" -alpha off -compose CopyOpacity -composite -strip "$ART/launcher-maomao.png"
  fi
  rm -f "$WORK"/ff-*.png "$WORK"/la-*.png
}

# lock / sddm backgrounds: reuse finished wallpapers that keep the left calm
make_lock_art() {
  local l_light="$OUT/light/01-ln-v02-textless.png" l_dark="$OUT/dark/01-ln-v02-textless.png"
  local s_light="$OUT/light/02-ln-v01-cover.png"   s_dark="$OUT/dark/03-ln-v14-cover.png"
  for pair in "lock-light:$l_light" "lock-dark:$l_dark" "sddm-light:$s_light" "sddm-dark:$s_dark"; do
    local name="${pair%%:*}" src="${pair#*:}"
    fresh "$ART/$name.png" || continue
    [ -s "$src" ] || { log "lock art: $src missing, skipped"; continue; }
    log "lock/login: $name.png"
    cp -f "$src" "$ART/$name.png"
  done
}

contact_sheet() {
  local out="$QA/art-contact-sheet.png"
  log "contact sheet: $out"
  local files=()
  for f in "$OUT"/light/*.png "$OUT"/dark/*.png; do [ -s "$f" ] && files+=("$f"); done
  [ "${#files[@]}" -gt 0 ] || return 0
  magick montage -label '%f' -font DejaVu-Sans -pointsize 11 -geometry 384x216+6+6 -tile 4x \
    -background '#777777' -fill '#ffffff' "${files[@]}" "$out"
}

# ================================================================== main ===
make_textures

if [ "$WIDGETS" = 1 ]; then
  make_widget_art; make_lock_art; exit 0
fi

# nn  slug                   raw file                       crop x0,y0,x1,y1      [width] [margin] [y offset] [flags]
# --- light novel (Touko Shino) — title column + volume badge (left, ends at x≈0.27–0.32),
#     author badge (right) and publisher logos (bottom) cropped away; shown as a hanging
#     scroll inset from the right edge, face + upper body filling the column.  Fractions
#     were checked on a crop contact sheet (no lettering, faces intact) ---------------------
compose_portrait 01 ln-v02-textless      ln-v02-cover-textless.png     0.10,0.00,0.82,0.70
compose_portrait 02 ln-v01-cover         ln-v01-cover-jp.png           0.26,0.00,0.82,0.62
compose_portrait 03 ln-v14-cover         ln-v14-cover-jp.png           0.24,0.00,0.82,0.66
compose_portrait 04 ln-v13-cover         ln-v13-cover-jp.png           0.31,0.00,0.79,0.62   840 260 0 C325x330
compose_portrait 05 ln-v16-cover         ln-v16-cover-jp.png           0.29,0.00,0.785,0.66  840 200 0 R
compose_portrait 06 ln-v10-cover         ln-v10-cover-jp.png           0.29,0.00,0.79,0.64
compose_portrait 07 ln-v11-cover         ln-v11-cover-jp.png           0.28,0.11,0.78,0.70   900 220 0 L
compose_portrait 08 ln-v03-cover         ln-v03-cover-jp.png           0.29,0.12,0.78,0.62
compose_portrait 09 ln-v07-cover         ln-v07-cover-jp.png           0.28,0.30,0.78,0.72
compose_portrait 10 ln-v09-cover         ln-v09-cover-jp.png           0.31,0.00,0.74,0.62   840 320
compose_portrait 11 ln-v12-cover         ln-v12-cover-jp.png           0.32,0.15,0.98,0.74   880 240
compose_portrait 12 ln-v15-cover         ln-v15-cover-jp.png           0.325,0.18,0.78,0.72  900 220 0 L
compose_portrait 13 ln-v06-cover         ln-v06-cover-jp.png           0.28,0.12,0.79,0.70
compose_portrait 14 ln-v01-insert        ln-v01-insert-1.jpg           0.00,0.00,0.60,0.80
compose_portrait 15 ln-v08-peony         ln-v08-insert-2.png           0.13,0.00,0.55,0.57
# --- manga (Nekokurage): the volume covers carry the title across the figure, so only the
#     clean Big Gangan illustration is used ------------------------------------------------
compose_portrait 16 manga-winter         manga-winter-clothes.jpg      0.55,0.00,1.00,1.00
# --- anime key visuals, tall (text/logo blocks cropped) ------------------------------------
compose_portrait 17 anime-kv-s1          anime-kv-s1-03.png            0.36,0.18,1.00,0.80
compose_portrait 18 anime-kv-s2-maomao   anime-kv-s2-02.png            0.40,0.13,0.875,0.62  1000 320 0 R   # Maomao whole inside the art zone, left of the right widget column (was cut by the feather); stops before the poster tagline
compose_portrait 19 anime-kv-s2-pair     anime-kv-s2-01.png            0.10,0.00,0.95,0.62
compose_portrait 20 anime-kv-s3-teaser   anime-kv-s3-teaser.png        0.00,0.00,0.88,0.77   880  0
# --- anime seasonal visuals, wide (gravity chosen so the logo is cropped and heads stay) -----
compose_wide     21 anime-lotus          anime-season-lotus-2024-07.png        north
compose_wide     22 anime-sunflower      anime-season-sunflower-2024-08.png    north
compose_wide     23 anime-maple          anime-season-maple-2024-11.png        north
compose_wide     24 anime-daffodil       anime-season-daffodil-2024-12.png     south
compose_wide     25 anime-peony          anime-season-peony-2025-01.png        north
compose_wide     26 anime-nanohana       anime-season-nanohana-2025-03.png     south
compose_wide     27 anime-sakura         anime-season-sakura-2025-04.png       north
compose_wide     28 anime-wisteria       anime-season-wisteria-2025-05.png     north
compose_wide     29 anime-hydrangea      anime-season-hydrangea-2025-06.png    north
compose_wide     30 anime-bellflower     anime-season-bellflower-2025-07.png   north
compose_wide     31 anime-mikan          anime-season-mikan-2025-12.png        north
compose_wide     32 anime-butterbur      anime-season-butterbur-2026-02.png    north
compose_wide     33 anime-summer-veg     anime-s2-august-2025.png              north
compose_wide     34 anime-persimmon      anime-s2-september-2025.png           north
compose_wide     35 anime-valentine      anime-valentine-2025.png              south

if [ -z "$ONLY" ]; then
  make_widget_art
  make_lock_art
  contact_sheet
fi

nl=$(ls "$OUT/light"/*.png 2>/dev/null | wc -l); nd=$(ls "$OUT/dark"/*.png 2>/dev/null | wc -l)
log "make-wallpapers: $nl light, $nd dark wallpapers in $OUT; widget art in $ART"
