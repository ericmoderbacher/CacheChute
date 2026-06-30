#!/usr/bin/env bash
# segment.sam2 — SEGMENT backend: high-quality class-agnostic SAM2 mask, prompted by a
# foreground point at the detect box's center. Writes mask.png (full res) + object.png
# (object matted on white, bbox-cropped square). Slower than fastsam, much higher quality.
set -euo pipefail
RUN=$1
BIN=/Users/ericmoderbacher/repos/modersNets/build/sam2_segment
if [ ! -x "$BIN" ]; then
  echo "!! sam2_segment not built — (cd modersNets && cmake --build build --target sam2_segment)"; exit 2
fi
read -r x0 y0 x1 y1 _ < "$RUN/box.txt"
"$BIN" --image "$RUN/source.bmp" --box "$x0 $y0 $x1 $y1" \
       --out-mask "$RUN/mask.png" --out-object "$RUN/object.png"
echo "   SAM2 mask + matte written"
