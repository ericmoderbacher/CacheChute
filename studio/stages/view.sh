#!/usr/bin/env bash
# view — present the run. Desktop is the current UI (native studio_view window);
# viewer.html is kept as the eventual-web path but not opened. Launches the desktop
# viewer in the background so the pipeline returns.
set -euo pipefail
RUN=$1
here=$(cd -- "$(dirname -- "$0")/.." && pwd)
[ -f "$RUN/object.png" ] && cp "$RUN/object.png" "$RUN/input.png" || cp "$RUN/source.png" "$RUN/input.png"
cp "$here/viewer.html" "$RUN/index.html"      # web path (later) — not opened
nohup bash "$here/desktop.sh" "$RUN" >/dev/null 2>&1 &
echo "   desktop viewer (studio_view) launched on $RUN"
