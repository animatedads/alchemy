#!/bin/sh
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd); ROOT=$(CDPATH= cd -- "$HERE/.." && pwd)
: "${MACROSPACE_ROOT:?Set MACROSPACE_ROOT to the repaired Macrospace root}"
command -v arecord >/dev/null 2>&1 || { echo "error: arecord is required for this Linux live capture adapter" >&2; exit 4; }
[ -n "${OOREXX_SPEECH_AZURE_KEY:-${SPEECH_KEY:-}}" ] || { echo "error: Azure Speech key missing" >&2; exit 3; }
PROFILE=${OOREXX_SPEECH_AUDIO_PROFILE:-speech-16k}; RATE=16000
case "$PROFILE" in telephony-8k|TELEPHONY-8K) RATE=8000 ;; speech-16k|SPEECH-16K) RATE=16000 ;; *) echo "error: microphone STT supports speech-16k or telephony-8k" >&2; exit 4 ;; esac
DURATION=${OOREXX_SPEECH_CAPTURE_SECONDS:-5}; FIFO=${OOREXX_SPEECH_CAPTURE_FIFO:-/tmp/oorexx-speech-capture-$$.fifo}
rm -f -- "$FIFO"; mkfifo "$FIFO"
cleanup(){ kill "${ARECORD_PID:-}" 2>/dev/null || true; rm -f -- "$FIFO"; }
trap cleanup EXIT INT TERM
arecord -q -d "$DURATION" -t raw -f S16_LE -r "$RATE" -c 1 "$FIFO" & ARECORD_PID=$!
PATHS="$ROOT/src:$MACROSPACE_ROOT/rexx"
[ -z "${ALCHEMY_OBJECTS_ROOT:-}" ] || PATHS="$PATHS:$ALCHEMY_OBJECTS_ROOT/src"
[ -z "${FOREIGN_RUNTIME_ROOT:-}" ] || PATHS="$PATHS:$FOREIGN_RUNTIME_ROOT/rexx"
[ -z "${CRYPTO_ROOT:-}" ] || PATHS="$PATHS:$CRYPTO_ROOT/src"
export REXX_PATH="$PATHS${REXX_PATH:+:$REXX_PATH}"; export LD_LIBRARY_PATH="$MACROSPACE_ROOT/rexx${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
${REXX:-rexx} "$ROOT/tests/live_azure_stt_microphone.rex" "$ROOT/python" "$FIFO"
wait "$ARECORD_PID" || true
