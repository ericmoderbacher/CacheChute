#!/usr/bin/env bash
# segment.mobilesam — SEGMENT backend: box-prompted mask via MobileSAM (fast SAM).
# Takes detect's box, returns a tight mask, mattes the object onto white.
# Contract: writes mask.png (binary) and object.png (object-on-white, square).
#
# Requires the generic CLI  modersNets/build/mobilesam_segment  (NOT BUILT YET):
#   mobilesam_segment --image <bmp> --box "x0 y0 x1 y1" \
#                     --out-mask <png> --out-object <png> [--pad 0.15 --bg FFFFFF]
# Build target: modersNets/tools/mobilesam_segment.mm against models/mobilesam/*.
set -euo pipefail
RUN=$1
BIN=/Users/ericmoderbacher/repos/modersNets/build/mobilesam_segment
if [ ! -x "$BIN" ]; then
  echo "!! mobilesam_segment not built yet — see this script's header for the build target."
  echo "   (swap SEGMENT=manual to run the chain now)"; exit 2
fi
read -r x0 y0 x1 y1 _ < "$RUN/box.txt"
"$BIN" --image "$RUN/source.bmp" --box "$x0 $y0 $x1 $y1" \
       --out-mask "$RUN/mask.png" --out-object "$RUN/object.png" --bg FFFFFF
echo "   object.png matted from MobileSAM mask"
