#!/usr/bin/env bash
# multiview.zero123plus — MULTIVIEW backend: one object image → 6 novel views,
# native on Metal (modersNets zero123plus_gen2 --front). Consumes object.png.
# Contract: writes view_0.png .. view_5.png.
set -euo pipefail
RUN=$1
BIN=/Users/ericmoderbacher/repos/modersNets/build/zero123plus_gen2
[ -x "$BIN" ] || { echo "!! zero123plus_gen2 not built — (cd modersNets && cmake --build build --target zero123plus_gen2)"; exit 2; }
src="$RUN/object.png"; [ -f "$src" ] || src="$RUN/source.png"   # fall back to raw if no segment
sips -s format bmp "$src" --out "$RUN/object.bmp" >/dev/null
raw="$RUN/z123raw"; mkdir -p "$raw"
"$BIN" --front "$RUN/object.bmp" --out "$raw" --label v --condpx "${CONDPX:-256}"
for i in 0 1 2 3 4 5; do cp "$raw/v_view_$i.png" "$RUN/view_$i.png"; done
echo "   6 views written"
