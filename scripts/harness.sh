#!/bin/bash
# Chroma-key hill-climbing harness.
# Applies N approaches to M test images, extracts alpha masks,
# evaluates each, writes results/<image>/<approach>.webp + -alpha.png
# and a combined results/metrics.json.
set -eu

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$REPO_ROOT/results"
TMP="${TMPDIR:-/tmp}/chroma-evals-tmp"
mkdir -p "$OUT" "$TMP"

# --- test images (magenta-background originals) ---
# Name → path. Add more by extending both arrays in lock-step.
IMAGES_KEYS=(sparse dense)
IMAGES_PATHS=(
  "$REPO_ROOT/test_images/case-sparse.webp"
  "$REPO_ROOT/test_images/case-dense.webp"
)

# --- approaches: each is a bash function that takes $1=input, $2=output ---

approach_plain() {
  magick "$1" -fuzz 30% -transparent "#FF00FF" "$2"
}

approach_flood4() {
  local W H W1 H1
  W=$(magick identify -format "%w" "$1")
  H=$(magick identify -format "%h" "$1")
  W1=$((W-1)); H1=$((H-1))
  magick "$1" -alpha set -fuzz 30% -fill none \
    -draw "color 0,0 floodfill" \
    -draw "color ${W1},0 floodfill" \
    -draw "color 0,${H1} floodfill" \
    -draw "color ${W1},${H1} floodfill" \
    "$2"
}

approach_flood4_then_tight_3() {
  approach_flood4 "$1" "$TMP/_tmp.webp"
  magick "$TMP/_tmp.webp" -fuzz 3% -transparent "#FF00FF" "$2"
}

approach_flood4_then_tight_5() {
  approach_flood4 "$1" "$TMP/_tmp.webp"
  magick "$TMP/_tmp.webp" -fuzz 5% -transparent "#FF00FF" "$2"
}

approach_flood4_then_tight_10() {
  approach_flood4 "$1" "$TMP/_tmp.webp"
  magick "$TMP/_tmp.webp" -fuzz 10% -transparent "#FF00FF" "$2"
}

approach_cc_border() {
  # Connected-components: any magenta region touching the image border is
  # background; anything else is kept.
  local tmpmask="$TMP/_ccmask.png"
  magick "$1" -fuzz 30% \
    -fill white +opaque "#FF00FF" \
    -fill black -opaque white \
    "$tmpmask"
  local W H W1 H1
  W=$(magick identify -format "%w" "$tmpmask")
  H=$(magick identify -format "%h" "$tmpmask")
  W1=$((W-1)); H1=$((H-1))
  magick "$tmpmask" -fuzz 10% \
    -fill red \
    -draw "color 0,0 floodfill" \
    -draw "color ${W1},0 floodfill" \
    -draw "color 0,${H1} floodfill" \
    -draw "color ${W1},${H1} floodfill" \
    -channel R -separate -threshold 50% -negate "$TMP/_ccalpha.png"
  magick "$1" "$TMP/_ccalpha.png" -compose CopyOpacity -composite "$2"
}

APPROACHES=(plain flood4 flood4_then_tight_3 flood4_then_tight_5 flood4_then_tight_10 cc_border)

# --- run matrix ---
METRICS_JSON="$OUT/metrics.json"
echo "[" > "$METRICS_JSON"
first=1

for i in "${!IMAGES_KEYS[@]}"; do
  img_key="${IMAGES_KEYS[$i]}"
  src="${IMAGES_PATHS[$i]}"
  img_out_dir="$OUT/$img_key"
  mkdir -p "$img_out_dir"

  for a in "${APPROACHES[@]}"; do
    result="$img_out_dir/${a}.webp"
    alpha="$img_out_dir/${a}-alpha.png"
    "approach_$a" "$src" "$result"
    # Extract alpha channel as grayscale PNG for visual inspection.
    magick "$result" -alpha extract "$alpha"
    metrics=$("$REPO_ROOT/scripts/eval.py" "$result")
    echo ""
    echo "=== $img_key × $a ==="
    echo "$metrics"
    if [ $first -eq 0 ]; then echo "," >> "$METRICS_JSON"; fi
    first=0
    echo "{\"image\":\"$img_key\",\"approach\":\"$a\",\"metrics\":$metrics}" >> "$METRICS_JSON"
  done
done

echo "]" >> "$METRICS_JSON"

echo ""
echo "Wrote metrics → $METRICS_JSON"
echo "Result images under $OUT/<image>/<approach>{.webp,-alpha.png}"
