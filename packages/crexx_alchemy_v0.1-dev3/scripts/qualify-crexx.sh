#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
: "${CREXX_ROOT:?set CREXX_ROOT to pinned CREXX source tree}"
: "${CREXX_BUILD:?set CREXX_BUILD to matching build tree}"
WORK="${CREXX_ALCHEMY_WORK:-$ROOT/.qualification}"
CC="${CC:-cc}"
for f in "$CREXX_ROOT/rxpa/crexxpa.h" "$CREXX_BUILD/bin/rxc" "$CREXX_BUILD/bin/rxas" "$CREXX_BUILD/bin/rxlink"; do
  [[ -e "$f" ]] || { echo "missing: $f" >&2; exit 2; }
done
RXVM="${RXVM:-$CREXX_BUILD/bin/rxvm}"
[[ -x "$RXVM" ]] || RXVM="$CREXX_BUILD/bin/rxbvm"
[[ -x "$RXVM" ]] || { echo "missing VM" >&2; exit 2; }
mkdir -p "$WORK"
"$CC" -std=c90 -fPIC -shared -DBUILD_DLL -DPLUGIN_ID=rx_alchemytest -I"$CREXX_ROOT/rxpa" -I"$CREXX_BUILD/generated" "$ROOT/native/alchemy_test_provider.c" -o "$WORK/rx_alchemytest.rxplugin"
for name in alchemytest alchemytest_signal alchemytest_lifetime; do
  base="$WORK/$name"
  "$CREXX_BUILD/bin/rxc" --no-exe-import -n -i "$CREXX_BUILD/bin;$WORK" -o "$base" "$ROOT/tests/$name.crexx"
  "$CREXX_BUILD/bin/rxas" -o "$base" "$base"
  "$CREXX_BUILD/bin/rxlink" -o "$base-linked" "$base" "$CREXX_BUILD/bin/library" "$CREXX_BUILD/bin/classlib" "$CREXX_BUILD/bin/rxfnsg"
  CREXX_PROVIDER_PATH="$WORK" "$RXVM" "$base-linked.rxbin"
done
echo "PASS: cREXX Alchemy dev3 qualification"
