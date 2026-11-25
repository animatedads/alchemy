#!/bin/sh
# Wrapper by Claude (Opus 5.5): runs ChatGPT's suite against the repository's
# own kits, building their native parts from source in a temporary directory
# (binaries shipped inside a source package are never used).
set -eu
cd "$(dirname "$0")/.."
R="${REPO_ROOT:?REPO_ROOT not set}/packages"
REXX_BIN="$(command -v rexx)"
OOREXX_ROOT="$(cd "$(dirname "$REXX_BIN")/.." && pwd)"
W=$(mktemp -d)
trap 'rm -rf "$W"' EXIT HUP INT TERM
cp -r "$R/newshell_native_providers_v0.1-dev18" "$W/np"
find "$W/np/lib" -name '*.so' -delete 2>/dev/null || true
(cd "$W/np" && REXX_INCLUDE="$OOREXX_ROOT/include" sh build.sh >/dev/null)
cp -r "$R/oorexx_process_v0.1-dev2" "$W/proc"
make -s -C "$W/proc/native" clean >/dev/null 2>&1 || true
make -s -C "$W/proc/native" OOREXX_ROOT="$OOREXX_ROOT" >/dev/null
export REXX_PATH="$PWD/src:$W/np/src:$R/newshell_llm_v0.1-dev6/src:$W/proc/src:$W/proc/src/providers:$R/oorexx_logging_v0.7/src${REXX_PATH:+:$REXX_PATH}"
export LD_LIBRARY_PATH="$W/np/lib:$W/proc/native${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
sh -n bin/mi-namespace-exec bin/stage-image.sh
echo "PASS shell syntax"
rexx tests/test.rex
