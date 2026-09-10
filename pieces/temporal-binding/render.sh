#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# The language interpreter uses Qt even when rendering without a window.
export QT_QPA_PLATFORM="${QT_QPA_PLATFORM:-offscreen}"
exec sclang -D "$SCRIPT_DIR/src/render.scd"
