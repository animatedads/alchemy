#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
URL="${1:-https://192.168.188.25:4444/video/mjpeg}"
HERE="$(cd "$(dirname "$0")" && pwd)"
exec "$HERE/build/vision_live_probe" "$URL" 55 73 5
