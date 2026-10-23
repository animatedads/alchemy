#!/bin/sh
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT=$(CDPATH= cd -- "$HERE/.." && pwd)
: "${MACROSPACE_ROOT:?Set MACROSPACE_ROOT to the repaired Macrospace root}"
command -v aplay >/dev/null 2>&1 || { echo "error: aplay is required" >&2; exit 4; }
command -v arecord >/dev/null 2>&1 || { echo "error: arecord is required" >&2; exit 4; }
[ -n "${OOREXX_SPEECH_AZURE_KEY:-${SPEECH_KEY:-}}" ] || { echo "error: Azure Speech key missing" >&2; exit 3; }
PYTHON=${PYTHON:-python3}
"$PYTHON" -c 'import azure.cognitiveservices.speech' >/dev/null 2>&1 || { echo "error: Azure Speech SDK unavailable" >&2; exit 4; }
PROFILE=${OOREXX_SPEECH_AUDIO_PROFILE:-speech-16k}
RATE=16000
case "$PROFILE" in
  telephony-8k|TELEPHONY-8K) RATE=8000 ;;
  speech-16k|SPEECH-16K) RATE=16000 ;;
  *) echo "error: live duplex supports speech-16k or telephony-8k" >&2; exit 4 ;;
esac
DURATION=${OOREXX_SPEECH_CAPTURE_SECONDS:-8}
CAPTURE_FIFO=${OOREXX_SPEECH_CAPTURE_FIFO:-/tmp/oorexx-speech-duplex-capture-$$.fifo}
PLAYBACK_FIFO=${OOREXX_SPEECH_PLAYBACK_FIFO:-/tmp/oorexx-speech-duplex-playback-$$.fifo}
rm -f -- "$CAPTURE_FIFO" "$PLAYBACK_FIFO"
mkfifo "$CAPTURE_FIFO" "$PLAYBACK_FIFO"
cleanup(){
  kill "${ARECORD_PID:-}" "${APLAY_PID:-}" 2>/dev/null || true
  rm -f -- "$CAPTURE_FIFO" "$PLAYBACK_FIFO"
}
trap cleanup EXIT INT TERM
aplay -q -t raw -f S16_LE -r "$RATE" -c 1 "$PLAYBACK_FIFO" & APLAY_PID=$!
arecord -q -d "$DURATION" -t raw -f S16_LE -r "$RATE" -c 1 "$CAPTURE_FIFO" & ARECORD_PID=$!
PATHS="$ROOT/src:$MACROSPACE_ROOT/rexx"
[ -z "${ALCHEMY_OBJECTS_ROOT:-}" ] || PATHS="$PATHS:$ALCHEMY_OBJECTS_ROOT/src"
[ -z "${FOREIGN_RUNTIME_ROOT:-}" ] || PATHS="$PATHS:$FOREIGN_RUNTIME_ROOT/rexx"
[ -z "${CRYPTO_ROOT:-}" ] || PATHS="$PATHS:$CRYPTO_ROOT/src"
export REXX_PATH="$PATHS${REXX_PATH:+:$REXX_PATH}"
export LD_LIBRARY_PATH="$MACROSPACE_ROOT/rexx${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
${REXX:-rexx} "$ROOT/tests/live_azure_duplex.rex" "$ROOT/python" "$CAPTURE_FIFO" "$PLAYBACK_FIFO"
wait "$ARECORD_PID" || true
wait "$APLAY_PID" || true
