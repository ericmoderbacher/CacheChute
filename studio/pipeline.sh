#!/usr/bin/env bash
# pipeline.sh — the studio orchestrator. Runs the stages in order, dispatching each
# to a swappable backend adapter (stages/<stage>.<backend>.sh). The backends talk to
# each other only through files in the run dir (the "stage contract" below), so any
# network can be swapped in without touching the others.
#
#   ./pipeline.sh                 # use pipeline.conf
#   SEGMENT=u2net ./pipeline.sh   # override any conf value from the env
#
# Stage contract (files in out/<NAME>/):
#   source.png source.bmp   prep      decoded input (HEIC handled natively by sips)
#   box.txt                 DETECT →  "x0 y0 x1 y1 [score] [label]" in source pixels
#   object.png              SEGMENT → the isolated object on white, square, ready for multiview
#   mask.png                SEGMENT → binary mask (optional, for inspection)
#   view_0..5.png           MULTIVIEW → the 6 synthesized views
#   index.html              VIEW →    the window
set -euo pipefail
here=$(cd -- "$(dirname -- "$0")" && pwd)
cd "$here"

# config: the conf uses `: "${VAR:=default}"`, so env values set before this win
# shellcheck disable=SC1091
source ./pipeline.conf

RUN="$here/out/$NAME"
mkdir -p "$RUN"
export RUN PROMPT BOX CROP CONDPX NAME

run_stage() {  # run_stage <stage> <backend>
  local stage=$1 backend=$2 script="stages/$1.$2.sh"
  [ -f "$script" ] || { echo "!! no backend '$backend' for stage '$stage' ($script missing)"; exit 1; }
  echo "── $stage : $backend ──────────────────────────────"
  bash "$script" "$RUN"
}

echo "[prep] native decode  $INPUT  →  source.{png,bmp}"
IN="$here/$INPUT"; [ -f "$IN" ] || IN="$INPUT"
# bmp first: sips BAKES EXIF orientation into BMP (but not PNG), so derive the PNG
# from the BMP → source.png, source.bmp, and every mask share one upright frame.
sips -s format bmp "$IN" --out "$RUN/source.bmp" >/dev/null
sips -s format png "$RUN/source.bmp" --out "$RUN/source.png" >/dev/null

run_stage detect  "$DETECT"
run_stage segment "$SEGMENT"
[ "$MULTIVIEW" = none ] || run_stage multiview "$MULTIVIEW"
if [ "${VIEWER:-desktop}" != none ]; then
  echo "── view : assemble window ──────────────────────────"
  bash stages/view.sh "$RUN"
fi

echo "done → out/$NAME/index.html"
