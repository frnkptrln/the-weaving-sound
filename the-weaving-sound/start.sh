#!/usr/bin/env bash
# =============================================================
#  THE WEAVING SOUND — start.sh
#  Headless launcher for sclang (SuperCollider interpreter)
#
#  Tested on: Arch Linux + PipeWire + linux-rt kernel
#  Requires:  supercollider, sc3-plugins
# =============================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MAIN_SCD="$SCRIPT_DIR/src/main.scd"

# ── Banner ─────────────────────────────────────────────────────
echo ""
echo "╔═══════════════════════════════════════╗"
echo "║   T H E   W E A V I N G   S O U N D  ║"
echo "╚═══════════════════════════════════════╝"
echo ""

# ── Dependency checks ──────────────────────────────────────────
if ! command -v sclang &>/dev/null; then
    echo "[ERROR] 'sclang' not found."
    echo "        Arch:   sudo pacman -S supercollider sc3-plugins"
    echo "        Debian: sudo apt install supercollider sc3-plugins"
    exit 1
fi

if [ ! -f "$MAIN_SCD" ]; then
    echo "[ERROR] Main file not found: $MAIN_SCD"
    exit 1
fi

# ── PipeWire low-latency hint ──────────────────────────────────
# For best performance, set the PipeWire quantum to 256 frames.
# Option A — temporary (current session only):
#   pw-metadata -n settings 0 clock.force-quantum 256
#
# Option B — permanent (create/edit):
#   /etc/pipewire/pipewire.conf.d/99-lowlatency.conf
#   context.properties = {
#       default.clock.quantum     = 256
#       default.clock.min-quantum = 128
#   }
#
# Check current quantum:
#   pw-metadata -n settings | grep quantum

# ── JACK / PipeWire client name ────────────────────────────────
# Sets the JACK/PipeWire client name for easy identification
# in tools like qpwgraph, Carla, or Helvum.
export SC_JACK_NAME="the-weaving-sound"

# ── Real-time scheduling ───────────────────────────────────────
# SCHED_RR prevents xruns by raising sclang's scheduler priority.
# Requires one of:
#   a) User is in the 'realtime' group (recommended for Arch + rtkit):
#        sudo usermod -aG realtime $USER  →  re-login
#   b) /etc/security/limits.d/99-realtime.conf with:
#        @realtime  -  rtprio   95
#        @realtime  -  memlock  unlimited
#   c) Running as root (not recommended for production).

USE_RT=false
if command -v chrt &>/dev/null; then
    # Test if we actually have permission before committing
    if chrt --rr 50 true 2>/dev/null; then
        USE_RT=true
        echo ">> Real-time scheduling: SCHED_RR priority 50 (via chrt)"
    else
        echo ">> Note: RT scheduling unavailable (no permission)."
        echo "   Add user to 'realtime' group for lower latency."
    fi
fi

# ── Memory locking ─────────────────────────────────────────────
# scsynth handles its own mlockall when using --memory-locking.
# sclang options can be set in ~/.config/SuperCollider/startup.scd
# or in the s.options block inside main.scd (see src/main.scd).

echo ">> Launching sclang → $MAIN_SCD"
echo ">> Press Ctrl+C to stop."
echo ""

# ── Execute ────────────────────────────────────────────────────
# 'exec' replaces this shell process with sclang so that
# Ctrl+C / SIGTERM propagate correctly to the SC server.

if [ "$USE_RT" = true ]; then
    exec chrt --rr 50 sclang "$MAIN_SCD"
else
    exec sclang "$MAIN_SCD"
fi
