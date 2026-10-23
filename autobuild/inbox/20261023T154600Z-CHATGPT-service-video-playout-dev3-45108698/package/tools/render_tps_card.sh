#!/usr/bin/env bash
# Test-only FFmpeg text renderer; report text is read via textfile, not shell expansion.
set -euo pipefail
[[ $# == 2 ]] || { echo 'USAGE: render_tps_card.sh REPORT_TEXT OUTPUT_PNG' >&2; exit 2; }
TEXTFILE="$(realpath "$1")"
OUTPUT="$(realpath -m "$2")"
FONT="${SERVICE_CARD_FONT:-/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf}"
[[ -f "$FONT" ]] || { echo "Missing font: $FONT" >&2; exit 3; }
[[ -s "$TEXTFILE" ]] || exit 4
ffmpeg -nostdin -hide_banner -v error -y -f lavfi \
  -i 'color=c=0x182534:s=1280x720:r=24:d=1' \
  -vf "drawbox=x=32:y=32:w=1216:h=656:color=0x263d50:t=fill,drawbox=x=35:y=35:w=1210:h=650:color=0x152332:t=fill,drawtext=fontfile=${FONT}:text=INITECH  /  NOTNOTES  /  TPS REPORT:fontcolor=0x66dde6:fontsize=30:x=68:y=63,drawbox=x=68:y=115:w=1140:h=3:color=0x66dde6:t=fill,drawtext=fontfile=${FONT}:textfile=${TEXTFILE}:expansion=none:fontcolor=white:fontsize=25:line_spacing=20:x=68:y=160" \
  -frames:v 1 -update 1 "$OUTPUT"
