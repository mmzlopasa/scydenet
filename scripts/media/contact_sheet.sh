#!/usr/bin/env bash
# One frame from every clip, tiled, so the pack can be reviewed as a single image.
set -uo pipefail
IN="$1"; OUT="$2"
mkdir -p "$OUT/frames"
i=0
for f in $(ls "$IN"/*.mp4 | sort); do
  i=$((i+1))
  ffmpeg -y -loglevel error -ss 1.5 -i "$f" -frames:v 1 \
    -vf "scale=240:240:force_original_aspect_ratio=increase,crop=240:240,drawbox=x=0:y=0:w=240:h=22:color=black@0.6:t=fill" \
    "$OUT/frames/$(printf %03d $i).jpg"
done
ffmpeg -y -loglevel error -framerate 1 -i "$OUT/frames/%03d.jpg" -vf "tile=8x10:padding=4" -frames:v 1 "$OUT/sheet.jpg"
ls "$IN"/*.mp4 | sort | xargs -n1 basename > "$OUT/order.txt"
