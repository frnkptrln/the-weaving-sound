#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

python3 src/render.py

if command -v ffmpeg >/dev/null 2>&1; then
  ffmpeg -y -hide_banner -loglevel error \
    -i renders/rooms-change-us.wav \
    -codec:a libmp3lame -b:a 256k \
    renders/rooms-change-us.mp3
  echo "Rendered renders/rooms-change-us.wav and renders/rooms-change-us.mp3"
else
  echo "Rendered renders/rooms-change-us.wav (install ffmpeg for MP3 output)"
fi
