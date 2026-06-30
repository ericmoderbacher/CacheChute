#!/usr/bin/env bash
# segment.manual — SEGMENT backend: no network. Centered-crops to a square (box side)
# and pads onto a white canvas. NOTE: this only *frames* — it does not remove the
# background (the glove stays). It exists so the chain runs before a real segmenter.
# Contract: writes object.png (object-on-white, square) and mask.png (placeholder).
set -euo pipefail
RUN=$1
# square side = min of the box dims (from detect), capped to image
read -r x0 y0 x1 y1 _ < "$RUN/box.txt"
s=$(( x1 - x0 )); bh=$(( y1 - y0 )); [ "$bh" -lt "$s" ] && s=$bh
sips -c "$s" "$s" "$RUN/source.png" --out "$RUN/object.png" >/dev/null     # centered crop
sips -Z 512 "$RUN/object.png" --out "$RUN/object.png" >/dev/null
rm -f "$RUN/mask.png"   # manual produces NO real mask — the viewer shows just the box
echo "   object.png written (FRAMED only — background NOT removed; swap SEGMENT=mobilesam/u2net for a real matte)"
