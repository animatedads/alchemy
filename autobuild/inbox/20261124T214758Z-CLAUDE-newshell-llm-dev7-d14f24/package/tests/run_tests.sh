#!/usr/bin/env bash
# newshell_llm v0.1-dev7 tests. Architecture: Tom Dyer. Coding: Claude (Opus 5.5).
#
# Runs in a temporary copy of the package: the source tree is never written.
# Environment (all optional; integration.json sets them under autobuild):
#   REXX_BIN              ooRexx 5.3 interpreter (default: rexx on PATH)
#   OOREXX_ROOT           an install with include/oorexxapi.h (default: from REXX_BIN)
#   PACKAGES              the repository's packages/ directory
#   PROCESS_DIR           oorexx_process v0.1-dev2
#   FOREIGN_RUNTIME_HOME  oorexx_foreign_runtime v0.22.6
#   ANTHROPIC_API_KEY     if set, test_live.rex also runs (network)
# KEEP=1 keeps the temporary copy and prints where it is.
set -euo pipefail
SRC="$(cd "$(dirname "$0")/.." && pwd)"
PACKAGES="${PACKAGES:-$SRC/..}"
P="$PACKAGES"
REXX_BIN="${REXX_BIN:-$(command -v rexx || true)}"
[ -x "$REXX_BIN" ] || { echo "FAIL no ooRexx interpreter (set REXX_BIN or put rexx on PATH)"; exit 2; }

# pitfall P7 (made five times): "call .X~y" or "call x~y" is a syntax error in ooRexx
if grep -nE '^[[:space:]]*call[[:space:]]+\.?[A-Za-z_][A-Za-z0-9_.]*~' "$SRC"/src/*.cls "$SRC"/bin/*.rex "$SRC"/tests/*.rex; then
  echo "FAIL pitfall P7: 'call x~y' above; write 'x~y' as a message instruction"; exit 3
fi
# pitfall P9 (made twice, once after writing the rule): a variable named RESULT is
# overwritten by the next message instruction or CALL
if grep -niE '^[^-#]*(^|[^~.a-z0-9_])result[[:space:]]*=[^=]' "$SRC"/src/*.cls "$SRC"/bin/*.rex "$SRC"/tests/*.rex | grep -v 'P9-ok'; then
  echo "FAIL pitfall P9: a variable named RESULT above; ooRexx overwrites it"; exit 3
fi

# ooRexx's own classes (json.cls) and headers, looked for where installs put them
OOREXX_ROOT="${OOREXX_ROOT:-$(cd "$(dirname "$REXX_BIN")/.." && pwd)}"
OOREXX_STD="${OOREXX_STD:-}"
if [ -z "$OOREXX_STD" ]; then
  for d in "$(dirname "$REXX_BIN")" "$OOREXX_ROOT/share/ooRexx" "$OOREXX_ROOT/lib/ooRexx" /usr/local/share/ooRexx /usr/share/ooRexx /usr/local/bin /usr/bin; do
    [ -f "$d/json.cls" ] && { OOREXX_STD="$d"; break; }
  done
fi
[ -f "${OOREXX_STD:-/nonexistent}/json.cls" ] || { echo "FAIL json.cls not found (set OOREXX_STD to the directory holding it)"; exit 2; }
if [ ! -f "$OOREXX_ROOT/include/oorexxapi.h" ]; then
  for r in "$(cd "$OOREXX_STD/.." && pwd)" /usr/local /usr; do
    [ -f "$r/include/oorexxapi.h" ] && { OOREXX_ROOT="$r"; break; }
  done
fi
[ -f "$OOREXX_ROOT/include/oorexxapi.h" ] || { echo "FAIL no oorexxapi.h (set OOREXX_ROOT)"; exit 2; }

for need in oorexx_ai_provider_anthropic_v0.5 oorexx_ai_access_v0.6 alchemy_objects_v0.8 oorexx_secret_broker_v0.2 oorexx_crypto_v0.1 oorexx_logging_v0.7; do
  [ -d "$P/$need/src" ] || { echo "FAIL dependency missing: $P/$need (set PACKAGES)"; exit 2; }
done
# dev7: the source editor and AtomicFile (required), the native providers (used when they load)
EDITOR_DIR="${EDITOR_DIR:-$P/oorexx_source_editor_v0.1-dev9}"
ATOMIC_FILE_DIR="${ATOMIC_FILE_DIR:-$P/oorexx_atomic_file_v0.1-dev1}"
PROVIDERS_DIR="${PROVIDERS_DIR:-$P/newshell_native_providers_v0.1-dev10}"
[ -f "$EDITOR_DIR/src/SourceEditor.cls" ] || { echo "FAIL oorexx_source_editor dev9 not found (set EDITOR_DIR)"; exit 2; }
[ -f "$ATOMIC_FILE_DIR/src/AtomicFile.cls" ] || { echo "FAIL oorexx_atomic_file dev1 not found (set ATOMIC_FILE_DIR)"; exit 2; }
PROCESS_DIR="${PROCESS_DIR:-$P/oorexx_process_v0.1-dev2}"
FOREIGN_RUNTIME_HOME="${FOREIGN_RUNTIME_HOME:-$P/oorexx_foreign_runtime_v0.22.6}"
[ -d "$PROCESS_DIR/native" ] || { echo "FAIL oorexx_process dev2 not found (set PROCESS_DIR)"; exit 2; }
[ -d "$FOREIGN_RUNTIME_HOME/rexx" ] || { echo "FAIL foreign runtime not found (set FOREIGN_RUNTIME_HOME)"; exit 2; }

WORK="$(mktemp -d "${TMPDIR:-/tmp}/newshell_llm.XXXXXX")"
if [ "${KEEP:-0}" = "1" ]; then echo "KEEP: work copy at $WORK"; else trap 'rm -rf "$WORK"' EXIT; fi
cp -r "$SRC" "$WORK/pkg"; ROOT="$WORK/pkg"
rm -rf "$ROOT/build"; mkdir -p "$ROOT/build"

# oorexx_process's native library, built from source in the work copy
cp -r "$PROCESS_DIR" "$ROOT/build/process"
make -s -C "$ROOT/build/process/native" OOREXX_ROOT="$OOREXX_ROOT"
# dev7: AtomicFile's native library (the editor saves through it), built here
cp -r "$ATOMIC_FILE_DIR" "$ROOT/build/atomic"
make -s -C "$ROOT/build/atomic/native" clean >/dev/null
make -s -C "$ROOT/build/atomic/native" OOREXX_ROOT="$OOREXX_ROOT"
# dev7: the native providers (ChatGPT) need ooRexx 5.3; without them the objects use plain Rexx
NATIVE_LIB=""
if [ -f "$PROVIDERS_DIR/native/posix.cpp" ] && "$REXX_BIN" -v 2>&1 | head -1 | grep -q 'Version 5\.3'; then
  cp -r "$PROVIDERS_DIR" "$ROOT/build/providers"
  (cd "$ROOT/build/providers" && REXX_INCLUDE="$OOREXX_ROOT/include" ./build.sh) && NATIVE_LIB="$ROOT/build/providers/lib"
fi
[ -n "$NATIVE_LIB" ] && echo "native providers: built" || echo "native providers: not used (plain Rexx mode)"
FR="$FOREIGN_RUNTIME_HOME"
if [ ! -f "$FR/build/libforeign_runtime.so" ]; then
  cp -r "$FR" "$ROOT/build/fr"; make -s -C "$ROOT/build/fr" OOREXX="$OOREXX_ROOT" build/libforeign_runtime.so; FR="$ROOT/build/fr"
fi
export LD_LIBRARY_PATH="$FR/build:$OOREXX_ROOT/lib:$ROOT/build/process/native:$ROOT/build/atomic/native${NATIVE_LIB:+:$NATIVE_LIB}${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export REXX_PATH="$EDITOR_DIR/src:$ROOT/build/atomic/src:$ROOT/build/atomic/src/providers${NATIVE_LIB:+:$ROOT/build/providers/src}:$ROOT/build/process/src:$ROOT/build/process/src/providers:$FR/rexx:$ROOT/src:$P/oorexx_ai_provider_anthropic_v0.5/src:$P/oorexx_ai_access_v0.6/src:$P/alchemy_objects_v0.8/src:$P/oorexx_secret_broker_v0.2/src:$P/oorexx_crypto_v0.1/src:$P/oorexx_logging_v0.7/src:$OOREXX_STD"
export NEWSHELL_LOG="$ROOT/build/newshell.log"
export PATH="$(dirname "$REXX_BIN"):$PATH"

# the console's environment, for bin/nsh.sh when run from the source tree
if [ "${WRITE_ENV:-0}" = "1" ]; then
  mkdir -p "$SRC/build"
  { echo "export REXX_PATH='${REXX_PATH//$ROOT/$SRC}'"; echo "export LD_LIBRARY_PATH='${LD_LIBRARY_PATH//$ROOT/$SRC}'"; echo "REXX_BIN='$REXX_BIN'"; } > "$SRC/build/env.sh"
  rm -rf "$SRC/build/process" "$SRC/build/fr"; cp -r "$ROOT/build/process" "$SRC/build/"; [ -d "$ROOT/build/fr" ] && cp -r "$ROOT/build/fr" "$SRC/build/"
fi

echo "newshell_llm v0.1-dev7: ooRexx $("$REXX_BIN" -v 2>&1 | head -1 | awk '{print $4}'), work copy $ROOT"
"$REXX_BIN" "$ROOT/tests/test_offline.rex" "$ROOT"
"$REXX_BIN" "$ROOT/tests/test_security.rex" "$ROOT"
missing=""
for t in zip unzip make cc; do command -v "$t" >/dev/null || missing="$missing $t"; done
command -v pkill >/dev/null || command -v killall >/dev/null || missing="$missing pkill/killall"
if [ -n "$missing" ]; then
  echo "SKIP test_jobs and test_died: missing$missing"
else
  "$REXX_BIN" "$ROOT/tests/test_jobs.rex" "$ROOT"
  "$REXX_BIN" "$ROOT/tests/test_died.rex" "$ROOT"
  "$REXX_BIN" "$ROOT/tests/test_agent.rex" "$ROOT"
fi
"$REXX_BIN" "$ROOT/tests/test_dev7.rex" "$ROOT"
if [ -n "${ANTHROPIC_API_KEY:-}" ]; then "$REXX_BIN" "$ROOT/tests/test_live.rex" "$ROOT"; else echo "SKIP live test: ANTHROPIC_API_KEY not set"; fi
echo "NEWSHELL_LLM v0.1-dev7: ALL OK"
