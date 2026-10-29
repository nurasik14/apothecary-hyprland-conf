#!/usr/bin/env bash
# assets/fetch-art.sh — re-download the copyrighted character art used by the
# Apothecary Hyprland theme (The Apothecary Diaries / 薬屋のひとりごと).
#
# The images are copyrighted (Touko Shino / Natsu Hyuuga / Hero Bunko / Imagica
# Infos; Nekokurage / Square Enix; TOHO animation / OLM).  They are NEVER
# committed to this repository; this script fetches them into
# assets/art/raw/ for personal, non-redistributed desktop use.
#
# Usage:
#   assets/fetch-art.sh            download everything that is missing
#   assets/fetch-art.sh --list     print the record table (file|url|origin|artist|size)
#   assets/fetch-art.sh --credits  print Markdown rows for assets/CREDITS.md
#   ART_DIR=/tmp/x assets/fetch-art.sh   download into another directory
#
# Idempotent: files that already exist and are larger than 1 KiB are skipped.
# The source is the MediaWiki file store behind kusuriya.fandom.com
# (static.wikia.nocookie.net).  The CDN requires a browser-like User-Agent
# and a Referer header; "&format=original" asks for the un-recompressed file.

set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST="${ART_DIR:-$HERE/art/raw}"
UA="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36 ApothecaryHyprland/1.0"
REFERER="https://kusuriya.fandom.com/"
SLEEP="${FETCH_SLEEP:-1.5}"
MIN_BYTES=1024

# file|url|origin|artist|pixel size  (all rights: copyright holders; personal use, not redistributed)
records() {
cat <<'EOF'
ln-v01-cover-jp.png|https://static.wikia.nocookie.net/kusuriya-no-hitorigoto/images/a/a9/Volume_1_Light_Novel.png/revision/latest?cb=20240128033058&format=original|light novel vol 1 cover (JP)|Touko Shino (しのとうこ) / Natsu Hyuuga, Hero Bunko (Imagica Infos)|1988x2883
ln-v02-cover-jp.png|https://static.wikia.nocookie.net/kusuriya-no-hitorigoto/images/5/55/Volume_2_Light_Novel.png/revision/latest?cb=20240128193056&format=original|light novel vol 2 cover (JP)|Touko Shino (しのとうこ) / Natsu Hyuuga, Hero Bunko (Imagica Infos)|1768x2560
ln-v03-cover-jp.png|https://static.wikia.nocookie.net/kusuriya-no-hitorigoto/images/e/e2/Volume_3_Light_Novel.png/revision/latest?cb=20240128193124&format=original|light novel vol 3 cover (JP)|Touko Shino (しのとうこ) / Natsu Hyuuga, Hero Bunko (Imagica Infos)|1768x2560
ln-v06-cover-jp.png|https://static.wikia.nocookie.net/kusuriya-no-hitorigoto/images/4/45/Volume_6_Light_Novel.png/revision/latest?cb=20240128193308&format=original|light novel vol 6 cover (JP)|Touko Shino (しのとうこ) / Natsu Hyuuga, Hero Bunko (Imagica Infos)|1768x2560
ln-v07-cover-jp.png|https://static.wikia.nocookie.net/kusuriya-no-hitorigoto/images/e/e7/Volume_7_Light_Novel.png/revision/latest?cb=20240128214229&format=original|light novel vol 7 cover (JP)|Touko Shino (しのとうこ) / Natsu Hyuuga, Hero Bunko (Imagica Infos)|1768x2560
ln-v09-cover-jp.png|https://static.wikia.nocookie.net/kusuriya-no-hitorigoto/images/f/f1/Volume_9_Light_Novel.png/revision/latest?cb=20240128214304&format=original|light novel vol 9 cover (JP)|Touko Shino (しのとうこ) / Natsu Hyuuga, Hero Bunko (Imagica Infos)|1768x2560
ln-v10-cover-jp.png|https://static.wikia.nocookie.net/kusuriya-no-hitorigoto/images/c/c0/Volume_10_Light_Novel.png/revision/latest?cb=20240128214401&format=original|light novel vol 10 cover (JP)|Touko Shino (しのとうこ) / Natsu Hyuuga, Hero Bunko (Imagica Infos)|1447x2094
ln-v11-cover-jp.png|https://static.wikia.nocookie.net/kusuriya-no-hitorigoto/images/8/8a/Volume_11_Light_Novel.png/revision/latest?cb=20240128214438&format=original|light novel vol 11 cover (JP)|Touko Shino (しのとうこ) / Natsu Hyuuga, Hero Bunko (Imagica Infos)|1447x2094
ln-v12-cover-jp.png|https://static.wikia.nocookie.net/kusuriya-no-hitorigoto/images/3/3c/Volume_12_Light_Novel.png/revision/latest?cb=20240128214951&format=original|light novel vol 12 cover (JP)|Touko Shino (しのとうこ) / Natsu Hyuuga, Hero Bunko (Imagica Infos)|1768x2560
ln-v13-cover-jp.png|https://static.wikia.nocookie.net/kusuriya-no-hitorigoto/images/a/a4/Volume_13_Light_Novel.png/revision/latest?cb=20240128214736&format=original|light novel vol 13 cover (JP)|Touko Shino (しのとうこ) / Natsu Hyuuga, Hero Bunko (Imagica Infos)|1240x1795
ln-v14-cover-jp.png|https://static.wikia.nocookie.net/kusuriya-no-hitorigoto/images/7/79/Volume_14_Light_Novel.png/revision/latest?cb=20240128214813&format=original|light novel vol 14 cover (JP)|Touko Shino (しのとうこ) / Natsu Hyuuga, Hero Bunko (Imagica Infos)|1447x2094
ln-v15-cover-jp.png|https://static.wikia.nocookie.net/kusuriya-no-hitorigoto/images/d/d8/Volume_15_Light_Novel.png/revision/latest?cb=20240628041309&format=original|light novel vol 15 cover (JP)|Touko Shino (しのとうこ) / Natsu Hyuuga, Hero Bunko (Imagica Infos)|1326x1920
ln-v16-cover-jp.png|https://static.wikia.nocookie.net/kusuriya-no-hitorigoto/images/1/16/Volume_16_Light_Novel.png/revision/latest?cb=20250418150517&format=original|light novel vol 16 cover (JP)|Touko Shino (しのとうこ) / Natsu Hyuuga, Hero Bunko (Imagica Infos)|829x1200
ln-v02-cover-textless.png|https://static.wikia.nocookie.net/kusuriya-no-hitorigoto/images/f/ff/Light_Novel_Vol_2_Cover_no_words.png/revision/latest?cb=20241002162547&format=original|light novel vol 2 cover art (textless)|Touko Shino (しのとうこ) / Natsu Hyuuga, Hero Bunko (Imagica Infos)|1602x2258
ln-v01-insert-1.jpg|https://static.wikia.nocookie.net/kusuriya-no-hitorigoto/images/9/9b/LN_Vol1-Insert1EN.jpg/revision/latest?cb=20220224173728&format=original|light novel vol 1 colour insert 1|Touko Shino (しのとうこ); J-Novel Club English edition|1400x2084
ln-v08-insert-2.png|https://static.wikia.nocookie.net/kusuriya-no-hitorigoto/images/3/37/LN_Vol8-2_EN.png/revision/latest?cb=20231116025157&format=original|light novel vol 8 colour insert 2|Touko Shino (しのとうこ); J-Novel Club English edition|1400x2027
manga-winter-clothes.jpg|https://static.wikia.nocookie.net/kusuriya-no-hitorigoto/images/2/28/Winter_Cloths_Maomao.jpg/revision/latest?cb=20201214112057&format=original|manga/Big Gangan illustration (Maomao in winter clothes)|Nekokurage (manga art) / Itsuki Nanao; Square Enix Big Gangan|2048x1468
anime-kv-s1-03.png|https://static.wikia.nocookie.net/kusuriya-no-hitorigoto/images/f/f2/KusuriyaHitorigoto-Anime-MainVisual-S1-03.png/revision/latest?cb=20240111031207&format=original|anime season 1 main visual 3|TOHO animation / OLM (anime key visual)|1600x2273
anime-kv-s2-01.png|https://static.wikia.nocookie.net/kusuriya-no-hitorigoto/images/5/5f/KusuriyaHitorigoto-Anime-MainArt-S2-01.png/revision/latest?cb=20241022150344&format=original|anime season 2 main art 1|TOHO animation / OLM (anime key visual)|1560x2211
anime-kv-s2-02.png|https://static.wikia.nocookie.net/kusuriya-no-hitorigoto/images/2/22/KusuriyaHitorigoto-Anime-MainArt-S2-02.png/revision/latest?cb=20250328203135&format=original|anime season 2 main art 2|TOHO animation / OLM (anime key visual)|1809x2560
anime-kv-s3-teaser.png|https://static.wikia.nocookie.net/kusuriya-no-hitorigoto/images/7/7b/KusuriyaHitorigoto-Anime-TeaserArt-S3.png/revision/latest?cb=20251022154132&format=original|anime season 3 teaser art|TOHO animation / OLM (anime key visual)|2508x3549
anime-pr-maomao-2024-10.png|https://static.wikia.nocookie.net/kusuriya-no-hitorigoto/images/2/27/Twitter-kusuriya_PR-Maomao-23oct2024.png/revision/latest?cb=20241030190140&format=original|anime official PR visual (Maomao, 2024-10)|TOHO animation / OLM (anime key visual)|4096x3072
anime-maomao-render.png|https://static.wikia.nocookie.net/kusuriya-no-hitorigoto/images/2/26/Maomao_%28Anime%29.png/revision/latest?cb=20260403010751&format=original|anime character art (Maomao)|TOHO animation / OLM (anime key visual)|1200x1200
anime-season-lotus-2024-07.png|https://static.wikia.nocookie.net/kusuriya-no-hitorigoto/images/e/e9/Traveling_through_the_Seasons_with_Maomao_and_Jinshi-Lotus-22jul2024.png/revision/latest?cb=20241112215230&format=original|anime 'Traveling through the Seasons' monthly visual (lotus-2024-07)|TOHO animation / OLM (anime key visual)|2048x1460
anime-season-sunflower-2024-08.png|https://static.wikia.nocookie.net/kusuriya-no-hitorigoto/images/2/25/Traveling_through_the_Seasons_with_Maomao_and_Xiaolan-Sunflower-22aug2024.png/revision/latest?cb=20241112215235&format=original|anime 'Traveling through the Seasons' monthly visual (sunflower-2024-08)|TOHO animation / OLM (anime key visual)|2048x1450
anime-season-maple-2024-11.png|https://static.wikia.nocookie.net/kusuriya-no-hitorigoto/images/b/be/Traveling_through_the_Seasons_with_Maomao_and_Jinshi-Maple_Leaves-22nov2024.png/revision/latest?cb=20241129192555&format=original|anime 'Traveling through the Seasons' monthly visual (maple-2024-11)|TOHO animation / OLM (anime key visual)|1727x1222
anime-season-daffodil-2024-12.png|https://static.wikia.nocookie.net/kusuriya-no-hitorigoto/images/8/8e/Traveling_through_the_Seasons_with_Maomao_and_Lihua-Daffodil-22dec2024.png/revision/latest?cb=20241222194441&format=original|anime 'Traveling through the Seasons' monthly visual (daffodil-2024-12)|TOHO animation / OLM (anime key visual)|3072x2072
anime-season-peony-2025-01.png|https://static.wikia.nocookie.net/kusuriya-no-hitorigoto/images/a/a5/Traveling_through_the_Seasons_with_Maomao_Xiaolan_and_Shisui-Winter_Peony-22jan2025.png/revision/latest?cb=20250122215216&format=original|anime 'Traveling through the Seasons' monthly visual (peony-2025-01)|TOHO animation / OLM (anime key visual)|2048x1448
anime-season-nanohana-2025-03.png|https://static.wikia.nocookie.net/kusuriya-no-hitorigoto/images/7/75/Traveling_through_the_Seasons_with_Maomao_and_Lihaku-Nanohana-22mar2025.png/revision/latest?cb=20250504185505&format=original|anime 'Traveling through the Seasons' monthly visual (nanohana-2025-03)|TOHO animation / OLM (anime key visual)|4096x2896
anime-season-sakura-2025-04.png|https://static.wikia.nocookie.net/kusuriya-no-hitorigoto/images/f/f9/Traveling_through_the_Seasons_with_Maomao_Jinshi-Cherry_Blossom_Viewing-22apr2025.png/revision/latest?cb=20250422225647&format=original|anime 'Traveling through the Seasons' monthly visual (sakura-2025-04)|TOHO animation / OLM (anime key visual)|2560x1810
anime-season-wisteria-2025-05.png|https://static.wikia.nocookie.net/kusuriya-no-hitorigoto/images/3/36/Traveling_through_the_Seasons_with_Xiaolan_Maomao_Shisui-Wisteria-22may2025.png/revision/latest?cb=20250526163803&format=original|anime 'Traveling through the Seasons' monthly visual (wisteria-2025-05)|TOHO animation / OLM (anime key visual)|2048x1448
anime-season-hydrangea-2025-06.png|https://static.wikia.nocookie.net/kusuriya-no-hitorigoto/images/3/3c/Traveling_through_the_Seasons_with_Maomao_and_Jinshi-Hydrangea-22jun2025.png/revision/latest?cb=20250622171143&format=original|anime 'Traveling through the Seasons' monthly visual (hydrangea-2025-06)|TOHO animation / OLM (anime key visual)|4096x2896
anime-season-bellflower-2025-07.png|https://static.wikia.nocookie.net/kusuriya-no-hitorigoto/images/b/b5/Traveling_through_the_Seasons_with_Maomao_and_Pairin-Bellflower-22jul2025.png/revision/latest?cb=20250723043522&format=original|anime 'Traveling through the Seasons' monthly visual (bellflower-2025-07)|TOHO animation / OLM (anime key visual)|1861x1316
anime-season-mikan-2025-12.png|https://static.wikia.nocookie.net/kusuriya-no-hitorigoto/images/7/7d/Traveling_through_the_Seasons_with_Maomao_and_Jinshi-Mikan-22dec2025.png/revision/latest?cb=20251229002628&format=original|anime 'Traveling through the Seasons' monthly visual (mikan-2025-12)|TOHO animation / OLM (anime key visual)|2048x1448
anime-season-butterbur-2026-02.png|https://static.wikia.nocookie.net/kusuriya-no-hitorigoto/images/f/f9/Traveling_through_the_Seasons_with_Luomen_and_Maomao-Butterbur-22feb2026.png/revision/latest?cb=20260222165211&format=original|anime 'Traveling through the Seasons' monthly visual (butterbur-2026-02)|TOHO animation / OLM (anime key visual)|1718x1150
anime-s2-august-2025.png|https://static.wikia.nocookie.net/kusuriya-no-hitorigoto/images/b/b7/S2_August_visual-Summer_veg_Chou-u_Maomao.png/revision/latest?cb=20250823044857&format=original|anime season 2 August 2025 visual|TOHO animation / OLM (anime key visual)|2048x1448
anime-s2-september-2025.png|https://static.wikia.nocookie.net/kusuriya-no-hitorigoto/images/3/33/S2_September_visual-Summer_persimmons_Jinshi_Maomao.png/revision/latest?cb=20250924145727&format=original|anime season 2 September 2025 visual|TOHO animation / OLM (anime key visual)|2048x1448
anime-valentine-2025.png|https://static.wikia.nocookie.net/kusuriya-no-hitorigoto/images/d/de/Valentines_visual_with_Maomao_and_Xiaolan-14feb2025.png/revision/latest?cb=20260228000451&format=original|anime Valentine's 2025 visual|TOHO animation / OLM (anime key visual)|1527x1080
EOF
}

case "${1:-}" in
  --list)
    records; exit 0 ;;
  --credits)
    records | while IFS='|' read -r file url origin artist dims; do
      [ -z "$file" ] && continue
      printf '| assets/art/raw/%s | [%s](%s) | %s | copyright, personal use, not redistributed (%s) |\n' \
        "$file" "$origin" "$url" "$artist" "$dims"
    done
    exit 0 ;;
  -h|--help)
    sed -n '2,20p' "$0"; exit 0 ;;
esac

mkdir -p "$DEST"
downloaded=0; skipped=0; failed=0; failed_list=()
total=$(records | grep -c '|')
i=0
while IFS='|' read -r file url origin artist dims; do
  [ -z "$file" ] && continue
  i=$((i+1))
  out="$DEST/$file"
  if [ -f "$out" ] && [ "$(stat -c %s "$out")" -gt "$MIN_BYTES" ]; then
    skipped=$((skipped+1)); continue
  fi
  printf '[%2d/%d] %s\n' "$i" "$total" "$file"
  tmp="$out.part"
  if curl -sfL --retry 5 --retry-delay 4 --retry-all-errors --max-time 120 \
        -A "$UA" -H "Referer: $REFERER" -H "Accept: image/png,image/jpeg,image/*;q=0.8,*/*;q=0.5" \
        -o "$tmp" "$url" && [ "$(stat -c %s "$tmp" 2>/dev/null || echo 0)" -gt "$MIN_BYTES" ]; then
    mv -f "$tmp" "$out"; downloaded=$((downloaded+1))
  else
    rm -f "$tmp"; failed=$((failed+1)); failed_list+=("$file")
    echo "   FAILED: $url" >&2
  fi
  sleep "$SLEEP"
done < <(records)

echo "fetch-art: $downloaded downloaded, $skipped already present, $failed failed (dest: $DEST)"
if [ "$failed" -gt 0 ]; then
  printf '  missing: %s\n' "${failed_list[@]}" >&2
  exit 1
fi
