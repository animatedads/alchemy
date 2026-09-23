#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
. "$ROOT/tools/runtime_common.sh"
"$ROOT/tools/prepare_runtime.sh" >/dev/null
REXX=$(av9_find_rexx) || { echo 'FAIL ooRexx executable not found' >&2; exit 2; }
av9_check_rexx "$REXX"
REXXC=${OOREXX_REXXC:-$(dirname "$REXX")/rexxc}
[ -x "$REXXC" ] || { echo "FAIL exact rexxc not executable: $REXXC" >&2; exit 2; }
PREFIX=$(av9_oorexx_prefix "$REXX" || true); LIBDIR=''; [ -n "$PREFIX" ] && LIBDIR=$(av9_oorexx_libdir "$PREFIX")
RUNTIME="$ROOT/run/runtime"; FR="$RUNTIME/oorexx_foreign_runtime_v0.22.6"; ML="$RUNTIME/oorexx_ml_v0.1-dev11"; MLG="$RUNTIME/oorexx_ml_graph_v0.1-dev5"; AV9="$RUNTIME/audio_v9_pattern_locator_v0.1-dev5-hotfix1"
export REXX_PATH="$ROOT/src:$ML/src:$ML/lib:$MLG/src:$AV9/src:$FR/rexx${REXX_PATH:+:$REXX_PATH}"
export LD_LIBRARY_PATH="$FR/build:$ROOT/run/native:$AV9/native${LIBDIR:+:$LIBDIR}${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export AUDIO_V9_VOICE_ROOT="$ROOT"; export OOREXX_REXX="$REXX"
exec "$REXXC" "$@"
