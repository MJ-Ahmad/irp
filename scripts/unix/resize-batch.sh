#!/usr/bin/env bash
SRC="data/raw"
DST="outputs/qf_resized"
W=800; H=600
find "$SRC" -type f \( -iname '*.jpg' -o -iname '*.png' \) | while read -r f; do
  rel="${f#$SRC/}"
  out="$DST/$rel"
  mkdir -p "$(dirname "$out")"
  magick "$f" -resize "${W}x${H}^" -gravity center -extent "${W}x${H}" "$out"
  echo "Processed $rel"
done
