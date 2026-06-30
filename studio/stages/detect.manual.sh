#!/usr/bin/env bash
# detect.manual — DETECT backend: no network. Emits a box from $BOX, or a centered
# square of side $CROP if BOX is empty. Lets the chain run before owlvit is built.
# Contract: writes box.txt = "x0 y0 x1 y1 [score] [label]" in source pixels.
set -euo pipefail
RUN=$1
read -r W H < <(sips -g pixelWidth -g pixelHeight "$RUN/source.png" | awk '/pixelWidth/{w=$2}/pixelHeight/{h=$2}END{print w, h}')
if [ -n "${BOX:-}" ]; then
  echo "$BOX 1.0 manual" > "$RUN/box.txt"
else
  s=${CROP:-1700}; [ "$s" -gt "$W" ] && s=$W; [ "$s" -gt "$H" ] && s=$H
  x0=$(( (W - s) / 2 )); y0=$(( (H - s) / 2 ))
  echo "$x0 $y0 $((x0+s)) $((y0+s)) 1.0 centered" > "$RUN/box.txt"
fi
echo "   box.txt: $(cat "$RUN/box.txt")  (image ${W}x${H})"
