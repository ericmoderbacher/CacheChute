#!/usr/bin/env bash
# Back-compat convenience wrapper. The demo is now the configurable pipeline.sh.
#   ./run_fastener_demo.sh [INPUT_IMAGE] [NAME]
# Equivalent to:  INPUT=<img> NAME=<name> ./pipeline.sh
# Swap networks per stage with DETECT=/SEGMENT=/MULTIVIEW= (see pipeline.conf).
set -euo pipefail
here=$(cd -- "$(dirname -- "$0")" && pwd)
exec env ${1:+INPUT="$1"} ${2:+NAME="$2"} "$here/pipeline.sh"
