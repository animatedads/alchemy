#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
: "${CC:=clang}"
command -v pkg-config >/dev/null
pkg-config --exists libavformat libavcodec libavutil libswscale || {
  echo "Missing FFmpeg development metadata. Install/repair Termux ffmpeg." >&2; exit 2; }
CFLAGS="$(pkg-config --cflags libavformat libavcodec libavutil libswscale)"
LIBS="$(pkg-config --libs libavformat libavcodec libavutil libswscale)"
mkdir -p ../build
$CC -O2 -fPIC -Wall -Wextra $CFLAGS -c vision_ffmpeg.c -o ../build/vision_ffmpeg.o
$CC -shared ../build/vision_ffmpeg.o $LIBS -o ../build/libvision_ffmpeg.so
$CC -O2 -Wall -Wextra $CFLAGS vision_ffmpeg_source.c ../build/vision_ffmpeg.o $LIBS -o ../build/vision_ffmpeg_source
echo "Built:"
ls -l ../build/libvision_ffmpeg.so ../build/vision_ffmpeg_source
