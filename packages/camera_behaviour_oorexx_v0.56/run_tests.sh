#!/bin/sh
set -eu

: "${ALCHEMY_OBJECTS_ROOT:?set ALCHEMY_OBJECTS_ROOT to alchemy_objects_v0.8 package root}"
: "${OOREXX_CRYPTO_ROOT:?set OOREXX_CRYPTO_ROOT to oorexx_crypto_v0.4 package root}"
: "${FOREIGN_RUNTIME_ROOT:?set FOREIGN_RUNTIME_ROOT to foreign_runtime_v0.11.0 package root}"

PACKAGE_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ALCHEMY_SRC="$ALCHEMY_OBJECTS_ROOT/src"
ALCHEMY_INSPECTOR="$ALCHEMY_OBJECTS_ROOT/inspector"
CRYPTO_SRC="$OOREXX_CRYPTO_ROOT/src"
FOREIGN_REXX="$FOREIGN_RUNTIME_ROOT/rexx"
FOREIGN_BUILD="$FOREIGN_RUNTIME_ROOT/build"
REXX_CMD=${REXX_CMD:-rexx}
REXXC_CMD=${REXXC_CMD:-rexxc}
REXX_BIN=$(dirname -- "$(command -v "$REXX_CMD")")

for d in "$PACKAGE_ROOT" "$ALCHEMY_SRC" "$ALCHEMY_INSPECTOR" "$CRYPTO_SRC" "$FOREIGN_REXX" "$FOREIGN_BUILD" "$REXX_BIN"; do
  [ -d "$d" ] || { echo "required directory missing: $d" >&2; exit 125; }
done

export REXX_PATH="$PACKAGE_ROOT:$ALCHEMY_SRC:$ALCHEMY_INSPECTOR:$CRYPTO_SRC:$FOREIGN_REXX:$REXX_BIN${REXX_PATH:+:$REXX_PATH}"
export LD_LIBRARY_PATH="$FOREIGN_BUILD${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

compile_count=0
for f in "$PACKAGE_ROOT/CameraCore.cls" "$PACKAGE_ROOT/CameraFFmpegMediaSource.cls" "$PACKAGE_ROOT"/test_*.rex; do
  "$REXXC_CMD" "$f" >/dev/null
  compile_count=$((compile_count + 1))
done
rm -f -- "$PACKAGE_ROOT"/*.orx

runtime_count=0
for f in "$PACKAGE_ROOT"/test_*.rex; do
  (cd "$PACKAGE_ROOT" && "$REXX_CMD" "$(basename "$f")") >/dev/null
  runtime_count=$((runtime_count + 1))
done
rm -f -- "$PACKAGE_ROOT"/*.orx

echo "CAMERA V0.45 ACCEPTANCE: OK compile=$compile_count runtime=$runtime_count"
