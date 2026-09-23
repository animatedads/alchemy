#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
QF_V082_SRC=${QF_V082_SRC:-}
if [[ -z "$QF_V082_SRC" || ! -f "$QF_V082_SRC/ObjectQueueFabric.cls" ]]; then
  echo "set QF_V082_SRC to the accepted Queue Fabric v0.8.2 src directory" >&2
  exit 2
fi
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
KEY="00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff"
BASE_REXX_PATH=${REXX_PATH:-}
REXX_PATH="$QF_V082_SRC${BASE_REXX_PATH:+:$BASE_REXX_PATH}" rexx "$ROOT/tests/compat_v082_auth_writer.rex" "$TMP/state" "$KEY"
REXX_PATH="$ROOT/src${BASE_REXX_PATH:+:$BASE_REXX_PATH}" rexx "$ROOT/tests/compat_v09_auth_reader.rex" "$TMP/state" "$KEY"
