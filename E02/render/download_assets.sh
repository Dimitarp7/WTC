#!/bin/bash
# WTC E02 — downloads all generated assets into ~/Downloads/WealthThroughTime/E02
set -euo pipefail
cd "$(dirname "$0")"
BASE="$HOME/Downloads/WealthThroughTime/E02"
mkdir -p "$BASE/stills" "$BASE/video" "$BASE/audio" "$BASE/render"

total=$(wc -l < manifest.tsv | tr -d ' ')
i=0
while IFS=$'\t' read -r name url; do
  [ -z "$name" ] && continue
  i=$((i+1))
  case "$name" in
    *.png) dest="$BASE/stills/$name" ;;
    *.mp4) dest="$BASE/video/$name" ;;
    *.wav|*.mp3) dest="$BASE/audio/$name" ;;
    *) dest="$BASE/$name" ;;
  esac
  if [ -s "$dest" ]; then echo "[$i/$total] skip $name (exists)"; continue; fi
  echo "[$i/$total] $name"
  curl -sfL --retry 3 -o "$dest" "$url" || echo "  !! FAILED: $name"
done < manifest.tsv

cp edit_decision_list.txt render.sh "$BASE/render/" 2>/dev/null || true
chmod +x "$BASE/render/render.sh" 2>/dev/null || true
echo
echo "Done. Assets in $BASE"
echo "Next: cd \"$BASE/render\" && ./render.sh"
