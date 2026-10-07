#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REXX_ROOT="${REXX_ROOT:-/usr/local}"
REXX="${REXX_BIN:-$REXX_ROOT/bin/rexx}"
REXXC="${REXXC_BIN:-$REXX_ROOT/bin/rexxc}"
if [[ ! -x "$REXX" || ! -x "$REXXC" ]]; then
  echo "ERROR: set REXX_ROOT or REXX_BIN/REXXC_BIN to ooRexx 5.3.0 r13196" >&2
  exit 2
fi
export LD_LIBRARY_PATH="${REXX_ROOT}/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export REXX_PATH="${REXX_ROOT}/bin:$ROOT/src${REXX_PATH:+:$REXX_PATH}"
echo "== runtime =="
"$REXX" -v | head -4

echo "== compile =="
for f in "$ROOT"/src/*.cls "$ROOT"/tests/*.rex; do
  "$REXXC" "$f" >/dev/null
  echo "PASS rexxc ${f#$ROOT/}"
done

echo "== deterministic tests =="
cd "$ROOT/tests"
"$REXX" test_castv2_codec.rex
"$REXX" test_mdns_codec.rex
"$REXX" test_device_objects.rex

echo "== live environment gate =="
if [[ -n "${CAST_TARGET_IP:-}" ]]; then
  echo "CAST_TARGET_IP=$CAST_TARGET_IP supplied."
  echo "Live TLS/8009 acquisition is intentionally delegated to the current Socket Provider/TLS engine."
  echo "This dev1 package does not bypass that provider with openssl/ncat/python."
else
  echo "SKIP live Chromecast: set CAST_TARGET_IP after wiring the estate TLS SocketProvider security profile."
fi

echo "PASS Chromecast v0.1-dev1 deterministic qualification"
