#!/usr/bin/env bash
# desktop.sh — compile (if stale) and launch the native studio_view window on a run dir.
#   ./desktop.sh [RUN_DIR]      (default: out/fastener)
set -euo pipefail
here=$(cd -- "$(dirname -- "$0")" && pwd)
mkdir -p "$here/build"
bin="$here/build/studio_view"; src="$here/studio_view.swift"
if [ ! -x "$bin" ] || [ "$src" -nt "$bin" ]; then
  echo "[desktop] compiling studio_view…"
  swiftc -O "$src" -o "$bin"
fi
exec "$bin" "${1:-$here/out/fastener}"
