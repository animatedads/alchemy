#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
echo "== Vision Termux preflight =="
command -v rexx
rexx -v | head -4
command -v clang
clang --version | head -1
command -v ffprobe
ffprobe -version | head -1
echo "== build native FFmpeg source =="
./native/build-termux.sh
echo "== source probe =="
./build/vision_ffmpeg_source 2>&1 | head -1 || true
echo "READY"
echo "Test: ./bench/live_capture.sh 'https://192.168.188.25:4444/video/mjpeg' 10"
