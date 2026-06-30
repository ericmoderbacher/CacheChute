#!/usr/bin/env bash
# detect.owlvit — DETECT backend: open-vocab text→box with OWL-ViT (full image forward
# exists in modersNets models/owlvit). Picks the top box for the $PROMPT labels.
# Contract: writes box.txt = "x0 y0 x1 y1 score label" in source pixels.
#
# Requires the generic CLI  modersNets/build/owlvit_detect  (NOT BUILT YET):
#   owlvit_detect --image <bmp> --labels "screw,bolt" --thresh 0.1 --out <box.txt>
# Build target lives in modersNets/tools/owlvit_detect.mm (to be added) against
# models/owlvit/owlvit_ref.h (imageForward + textForward + forward) and the CLIP
# BPE tokenizer (weights/sd15_vocab.json + sd15_merges.txt).
set -euo pipefail
RUN=$1
BIN=/Users/ericmoderbacher/repos/modersNets/build/owlvit_detect
if [ ! -x "$BIN" ]; then
  echo "!! owlvit_detect not built yet — see this script's header for the build target."
  echo "   (swap DETECT=manual to run the chain now)"; exit 2
fi
labels=$(printf '%s' "${PROMPT:-screw.}" | tr '.' ',' | sed 's/ *, */,/g; s/^,//; s/,$//')
"$BIN" --image "$RUN/source.bmp" --labels "$labels" --thresh "${OWL_THRESH:-0.1}" --out "$RUN/box.txt"
echo "   box.txt: $(cat "$RUN/box.txt")"
