#!/usr/bin/env bash
# newshell_native_providers v0.1-dev14: autobuild wrapper.
# Providers, their tests and test.sh: ChatGPT (unchanged).  This wrapper: Claude (Opus 5.5).
# Architecture: Tom Dyer.
#
# Runs ChatGPT's own build.sh and test.sh in a temporary copy, against a NEWSHELL_HOME
# assembled from the repository: newshell_llm v0.1-dev6 sources, oorexx_process v0.1-dev2
# (its native library built here from source), oorexx_logging v0.7, oorexx_crypto v0.1.
# Needs Linux 5.6+ (openat2), a mounted /proc, sparse files, g++ and ooRexx 5.3 headers.
#   REXX_BIN (default rexx on PATH); OOREXX_ROOT (an install with include/oorexxapi.h);
#   PACKAGES (the repository's packages directory); KEEP=1 keeps the temporary copy.
set -euo pipefail
SRC="$(cd "$(dirname "$0")/.." && pwd)"
PACKAGES="${PACKAGES:-$SRC/..}"
REXX_BIN="${REXX_BIN:-$(command -v rexx || true)}"
[ -x "$REXX_BIN" ] || { echo "FAIL no ooRexx interpreter (set REXX_BIN)"; exit 2; }
OOREXX_ROOT="${OOREXX_ROOT:-$(cd "$(dirname "$REXX_BIN")/.." && pwd)}"
if [ ! -f "$OOREXX_ROOT/include/oorexxapi.h" ]; then
  for r in /usr/local /usr; do [ -f "$r/include/oorexxapi.h" ] && { OOREXX_ROOT="$r"; break; }; done
fi
[ -f "$OOREXX_ROOT/include/oorexxapi.h" ] || { echo "FAIL no oorexxapi.h (set OOREXX_ROOT)"; exit 2; }
[ -r /proc/self/stat ] || { echo "FAIL /proc is not mounted"; exit 2; }
for need in newshell_llm_v0.1-dev6 oorexx_process_v0.1-dev2 oorexx_logging_v0.7 oorexx_crypto_v0.1; do
  [ -d "$PACKAGES/$need/src" ] || { echo "FAIL dependency missing: $PACKAGES/$need (set PACKAGES)"; exit 2; }
done

WORK="$(mktemp -d "${TMPDIR:-/tmp}/native_providers.XXXXXX")"
if [ "${KEEP:-0}" = "1" ]; then echo "KEEP: $WORK"; else trap 'rm -rf "$WORK"' EXIT; fi
cp -r "$SRC" "$WORK/pkg"
H="$WORK/newshell"; mkdir -p "$H/src" "$H/lib"
cp "$PACKAGES"/newshell_llm_v0.1-dev6/src/*.cls "$H/src/"
cp "$PACKAGES"/oorexx_process_v0.1-dev2/src/*.cls "$PACKAGES"/oorexx_process_v0.1-dev2/src/providers/*.cls "$H/src/"
cp "$PACKAGES"/oorexx_logging_v0.7/src/LoggingCore.cls "$PACKAGES"/oorexx_logging_v0.7/src/MethodInterposition.cls "$H/src/"
cp "$PACKAGES"/oorexx_crypto_v0.1/src/crypto.cls "$H/src/"
cp -r "$PACKAGES/oorexx_process_v0.1-dev2/native" "$WORK/procnative"
echo "== interpreter: $("$REXX_BIN" -v 2>&1 | head -1); kernel $(uname -r)"
echo "== build: oorexx_process native (for NEWSHELL_HOME)"
make -s -C "$WORK/procnative" OOREXX_ROOT="$OOREXX_ROOT"
cp "$WORK/procnative/librxprocessnative.so" "$H/lib/"
echo "== build: rxshellposix (ChatGPT's build.sh)"
(cd "$WORK/pkg" && REXX_INCLUDE="$OOREXX_ROOT/include" ./build.sh)
# json.cls and rxregexp.cls live beside the interpreter
STD="$(dirname "$REXX_BIN")"
echo "== test (ChatGPT's test.sh, unchanged)"
(cd "$WORK/pkg" && REXX="$REXX_BIN" REXX_PATH="$STD${REXX_PATH:+:$REXX_PATH}" \
   LD_LIBRARY_PATH="$OOREXX_ROOT/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" \
   REQUIRE_TCP_DIAG="${REQUIRE_TCP_DIAG:-1}" NEWSHELL_HOME="$H" ./test.sh) > "$WORK/test.out" 2>&1 || { cat "$WORK/test.out"; echo "FAIL native providers dev7"; exit 1; }
grep -E '^FAIL|SUITE|^TOTAL' "$WORK/test.out" || true
n=$(grep -c '^PASS' "$WORK/test.out" || true)
[ "$n" -ge 392 ] || { cat "$WORK/test.out"; echo "FAIL expected at least 392 PASS lines, got $n"; exit 1; }
echo "PASS newshell_native_providers v0.1-dev14 ($n checks)"
