#!/usr/bin/env bash
# segment.u2net — SEGMENT backend: prompt-free salient-foreground matte (U^2-Net).
# Ignores the box; best when the background is clean (the chute), where the lone
# object IS the salient foreground. On cluttered scenes it may grab the hand.
# Contract: writes mask.png (saliency/alpha) and object.png (object-on-white, square).
#
# Requires the generic CLI  modersNets/build/u2net_matte  (NOT BUILT YET):
#   u2net_matte --image <bmp> --out-mask <png> --out-object <png> [--bg FFFFFF]
# Build target: modersNets/tools/u2net_matte.mm against models/u2net/u2net_ref.h
# (self-contained full forward — the simplest real segmenter to bring up first).
set -euo pipefail
RUN=$1
BIN=/Users/ericmoderbacher/repos/modersNets/build/u2net_matte
if [ ! -x "$BIN" ]; then
  echo "!! u2net_matte not built yet — see this script's header for the build target."
  echo "   (swap SEGMENT=manual to run the chain now)"; exit 2
fi
"$BIN" --image "$RUN/source.bmp" --out-mask "$RUN/mask.png" --out-object "$RUN/object.png" --bg FFFFFF
echo "   object.png matted from U^2-Net saliency"
