#!/bin/sh
# Runs ooRexx with this package's classes, the Audio V9 provider and Physics World on the path.
# Set ALCHEMY (a checkout of this repo) and FR_ROOT (Foreign Runtime v0.22.6 build with rexx/ and build/).
# The native provider is built in place by native/build_native.sh.
P=$(cd "$(dirname "$0")/.." && pwd)
: "${ALCHEMY:?set ALCHEMY to the alchemy checkout}"; : "${FR_ROOT:?set FR_ROOT to the Foreign Runtime build}"
export REXX_PATH="$P/spash3d:$P/src:$FR_ROOT/rexx:$ALCHEMY/packages/oorexx_units_v0.1-dev4/rexx:$ALCHEMY/packages/oorexx_maths/rexx:$ALCHEMY/packages/oorexx_physics_world/rexx:$ALCHEMY/packages/audio_v9_voice_recovery_v0.1-dev16/src${REXX_PATH:+:$REXX_PATH}"
export LD_LIBRARY_PATH="$FR_ROOT/build:$P/native${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export AUDIO_V9_VOICE_ROOT="$P"
mkdir -p "$P/run/native"; [ -f "$P/run/native/av9_spatial.bridge.json" ] || cp "$P/native/av9_spatial.bridge.json" "$P/run/native/"
[ -f "$P/run/native/libav9_spatial_provider.so" ] || cp "$P/native/libav9_spatial_provider.so" "$P/run/native/" 2>/dev/null || true
exec rexx "$@"
