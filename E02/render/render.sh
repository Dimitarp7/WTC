#!/bin/bash
# WTC E02 — assembles the final episode from downloaded assets.
# Requires ffmpeg (brew install ffmpeg). Run from any directory.
set -euo pipefail
BASE="$HOME/Downloads/WealthThroughTime/E02"
V="$BASE/video"; S="$BASE/stills"; A="$BASE/audio"
W="$BASE/render/work"; mkdir -p "$W"
EDL="$(cd "$(dirname "$0")" && pwd)/edit_decision_list.txt"
OUT="$BASE/E02_CosimoDeMedici_FINAL.mp4"
FF="ffmpeg -nostdin -hide_banner -loglevel error -y"

norm() { # normalize a clip to 1920x1080/30fps h264, silent
  local src="$1" dst="$2"
  [ -s "$dst" ] && return 0
  $FF -i "$src" -vf "scale=1920:1080:force_original_aspect_ratio=decrease,pad=1920:1080:(ow-iw)/2:(oh-ih)/2,fps=30,format=yuv420p" \
    -an -c:v libx264 -preset fast -crf 18 "$dst"
}

dur() { ffprobe -v error -show_entries format=duration -of csv=p=0 "$1"; }

# --- parse EDL into per-block work ---
block=""; declare -a parts=(); audio=""
seg_files=()

flush_block() {
  [ -z "$block" ] && return 0
  local list="$W/block${block}.txt" cat="$W/block${block}_cat.mp4" fin="$W/block${block}_final.mp4"
  : > "$list"
  for p in "${parts[@]}"; do echo "file '$p'" >> "$list"; done
  $FF -f concat -safe 0 -i "$list" -c:v libx264 -preset fast -crf 18 "$cat"
  local ad vd factor
  ad=$(dur "$A/$audio"); vd=$(dur "$cat")
  factor=$(python3 -c "print(f'{$ad/$vd:.6f}')")
  echo "Block $block: video ${vd}s -> audio ${ad}s (stretch x$factor)"
  $FF -i "$cat" -i "$A/$audio" -filter_complex "[0:v]setpts=${factor}*PTS,fps=30[v]" \
    -map "[v]" -map 1:a -c:v libx264 -preset fast -crf 18 -c:a aac -b:a 192k -shortest "$fin"
  seg_files+=("$fin")
  block=""; parts=(); audio=""
}

while read -r line; do
  case "$line" in
    \#*|"") continue ;;
    BLOCK\ *) flush_block; block=$(echo "$line" | awk '{print $2}'); audio=$(echo "$line" | awk '{print $3}') ;;
    HARDCUT)
      flush_block
      blk="$W/black.mp4"
      [ -s "$blk" ] || $FF -f lavfi -i "color=black:s=1920x1080:r=30:d=0.4" -f lavfi -i "anullsrc=r=48000:cl=stereo" \
        -t 0.4 -c:v libx264 -preset fast -crf 18 -c:a aac -shortest "$blk"
      seg_files+=("$blk") ;;
    TITLE\ *)
      png=$(echo "$line" | awk '{print $2}'); secs=$(echo "$line" | awk '{print $3}')
      t="$W/title_${secs}s.mp4"
      [ -s "$t" ] || $FF -loop 1 -t "$secs" -i "$S/$png" \
        -vf "scale=1920:1080:force_original_aspect_ratio=decrease,pad=1920:1080:(ow-iw)/2:(oh-ih)/2,fps=30,format=yuv420p" \
        -an -c:v libx264 -preset fast -crf 18 "$t"
      parts+=("$t") ;;
    *.mp4)
      n="$W/n_${line}"
      norm "$V/$line" "$n"
      parts+=("$n") ;;
  esac
done < "$EDL"
flush_block

# --- final concat ---
list="$W/final.txt"; : > "$list"
for f in "${seg_files[@]}"; do echo "file '$f'" >> "$list"; done
$FF -f concat -safe 0 -i "$list" -c:v libx264 -preset medium -crf 18 -c:a aac -b:a 192k -movflags +faststart "$OUT"
echo
echo "DONE: $OUT ($(dur "$OUT")s)"
