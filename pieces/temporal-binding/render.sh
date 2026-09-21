#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# The language interpreter uses Qt even when rendering without a window.
export QT_QPA_PLATFORM="${QT_QPA_PLATFORM:-offscreen}"
# sclang links Qt WebEngine, which refuses to start its sandbox for root
# (containers, CI). Rendering needs no browser, so disable it like
# scripts/render_piece.py does for its own sclang child.
export QTWEBENGINE_DISABLE_SANDBOX="${QTWEBENGINE_DISABLE_SANDBOX:-1}"
exec sclang -D "$SCRIPT_DIR/src/render.scd"
