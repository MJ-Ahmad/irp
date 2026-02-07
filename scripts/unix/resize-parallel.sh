#!/usr/bin/env bash
SRC="data/raw"; DST="outputs/qf_resized"; W=800; H=600
export DST W H
find "$SRC" -type f \( -iname '*.jpg' -o -iname '*.png' \) | parallel --bar '
  rel={/}
  out="$DST/{/}"
  mkdir -p "$(dirname "$out")"
  magick "{}" -resize "${W}x${H}^" -gravity center -extent "${W}x${H}" "$out"
'
