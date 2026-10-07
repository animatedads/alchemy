#!/bin/sh
set -eu

HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT=$(CDPATH= cd -- "$HERE/.." && pwd)

: "${MACROSPACE_ROOT:?Set MACROSPACE_ROOT to oorexx_python_macrospace_poc_v0.31.7-rexxfirst2 root}"

if [ ! -f "$MACROSPACE_ROOT/rexx/animals.cls" ]; then
  echo "error: Macrospace animals.cls not found under $MACROSPACE_ROOT/rexx" >&2
  exit 2
fi
if [ ! -e "$MACROSPACE_ROOT/rexx/librexxpython_poc.so" ]; then
  echo "error: Macrospace native bridge is not built." >&2
  echo "Build it from MACROSPACE_ROOT first: BUILD_TARGET=host ./build.sh" >&2
  exit 2
fi

if [ -z "${OOREXX_SPEECH_AZURE_KEY:-${SPEECH_KEY:-}}" ]; then
  echo "error: set OOREXX_SPEECH_AZURE_KEY (or SPEECH_KEY)" >&2
  exit 3
fi
if [ -z "${OOREXX_SPEECH_AZURE_REGION:-${SPEECH_REGION:-}}" ] && \
   [ -z "${OOREXX_SPEECH_AZURE_ENDPOINT:-${ENDPOINT:-}}" ]; then
  echo "error: set Azure region or endpoint" >&2
  exit 3
fi

PYTHON=${PYTHON:-python3}
if ! "$PYTHON" -c 'import azure.cognitiveservices.speech' >/dev/null 2>&1; then
  echo "error: Azure Speech SDK is not importable by $PYTHON" >&2
  echo "install: $PYTHON -m pip install azure-cognitiveservices-speech" >&2
  exit 4
fi

REXX=${REXX:-rexx}
PATHS="$ROOT/src:$MACROSPACE_ROOT/rexx"
if [ -n "${ALCHEMY_OBJECTS_ROOT:-}" ]; then PATHS="$PATHS:$ALCHEMY_OBJECTS_ROOT/src"; fi
if [ -n "${FOREIGN_RUNTIME_ROOT:-}" ]; then PATHS="$PATHS:$FOREIGN_RUNTIME_ROOT/rexx"; fi
if [ -n "${CRYPTO_ROOT:-}" ]; then PATHS="$PATHS:$CRYPTO_ROOT/src"; fi
export REXX_PATH="$PATHS${REXX_PATH:+:$REXX_PATH}"
export LD_LIBRARY_PATH="$MACROSPACE_ROOT/rexx${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

set +e
OUTPUT=$("$REXX" "$ROOT/tests/live_azure_tts.rex" "$ROOT/python" 2>&1)
RC=$?
set -e
printf '%s\n' "$OUTPUT"
[ "$RC" -eq 0 ] || exit "$RC"

ARTIFACT=$(printf '%s\n' "$OUTPUT" | sed -n 's/^ARTIFACT //p' | tail -1)
if [ -z "$ARTIFACT" ]; then
  echo "error: live test passed but returned no ARTIFACT line" >&2
  exit 6
fi

if [ -n "${OOREXX_SPEECH_OUTPUT:-}" ]; then
  cp -- "$ARTIFACT" "$OOREXX_SPEECH_OUTPUT"
  ARTIFACT=$OOREXX_SPEECH_OUTPUT
  echo "COPIED $ARTIFACT"
fi

if [ "${OOREXX_SPEECH_PLAY:-0}" = "1" ]; then
  if command -v aplay >/dev/null 2>&1; then
    aplay "$ARTIFACT"
  elif command -v paplay >/dev/null 2>&1; then
    paplay "$ARTIFACT"
  elif command -v ffplay >/dev/null 2>&1; then
    ffplay -nodisp -autoexit "$ARTIFACT"
  else
    echo "warning: no aplay, paplay or ffplay found; WAV is $ARTIFACT" >&2
  fi
fi
