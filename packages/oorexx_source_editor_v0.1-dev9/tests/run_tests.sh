#!/usr/bin/env bash
# oorexx_source_editor v0.1-dev9 tests. Architecture: Tom Dyer. Coding: Claude (Opus 5.5).
#
# Runs in a temporary copy of the package: the source tree is never written.
# Environment (all optional; integration.json sets them under autobuild):
#   REXX_BIN          ooRexx 5.3 interpreter (default: rexx on PATH)
#   OOREXX_ROOT       an install with include/oorexxapi.h (default: from REXX_BIN)
#   OOREXX_STD        the directory holding json.cls and rxregexp.cls
#   ATOMIC_FILE_DIR   oorexx_atomic_file v0.1-dev1 (default: ../oorexx_atomic_file_v0.1-dev1)
# KEEP=1 keeps the temporary copy and prints where it is.
set -euo pipefail
SRC="$(cd "$(dirname "$0")/.." && pwd)"
REXX_BIN="${REXX_BIN:-$(command -v rexx || true)}"
[ -x "$REXX_BIN" ] || { echo "FAIL no ooRexx interpreter (set REXX_BIN or put rexx on PATH)"; exit 2; }

# pitfall P7: "call .X~y" or "call x~y" is a syntax error in ooRexx
if grep -nE '^[[:space:]]*call[[:space:]]+\.?[A-Za-z_][A-Za-z0-9_.]*~' "$SRC"/src/*.cls "$SRC"/bin/*.rex "$SRC"/tests/*.rex; then
  echo "FAIL pitfall P7: 'call x~y' above; write 'x~y' as a message instruction"; exit 3
fi
# pitfall P9: a variable named RESULT is overwritten by the next message instruction or CALL
# (the test file writes result= inside test data strings; those lines are marked P9-ok)
if grep -niE '^[^-#]*(^|[^~.[:alnum:]_])result[[:space:]]*=[^=]' "$SRC"/src/*.cls "$SRC"/bin/*.rex | grep -v 'P9-ok'; then
  echo "FAIL pitfall P9: a variable named RESULT above; ooRexx overwrites it"; exit 3
fi

OOREXX_ROOT="${OOREXX_ROOT:-$(cd "$(dirname "$REXX_BIN")/.." && pwd)}"
OOREXX_STD="${OOREXX_STD:-}"
if [ -z "$OOREXX_STD" ]; then
  for d in "$(dirname "$REXX_BIN")" "$OOREXX_ROOT/share/ooRexx" "$OOREXX_ROOT/lib/ooRexx" /usr/local/share/ooRexx /usr/share/ooRexx /usr/local/bin /usr/bin; do
    [ -f "$d/json.cls" ] && [ -f "$d/rxregexp.cls" ] && { OOREXX_STD="$d"; break; }
  done
fi
[ -f "${OOREXX_STD:-/nonexistent}/rxregexp.cls" ] || { echo "FAIL json.cls / rxregexp.cls not found (set OOREXX_STD)"; exit 2; }
if [ ! -f "$OOREXX_ROOT/include/oorexxapi.h" ]; then
  for r in "$(cd "$OOREXX_STD/.." && pwd)" /usr/local /usr; do
    [ -f "$r/include/oorexxapi.h" ] && { OOREXX_ROOT="$r"; break; }
  done
fi
[ -f "$OOREXX_ROOT/include/oorexxapi.h" ] || { echo "FAIL no oorexxapi.h (set OOREXX_ROOT)"; exit 2; }
ATOMIC_FILE_DIR="${ATOMIC_FILE_DIR:-$SRC/../oorexx_atomic_file_v0.1-dev1}"
[ -f "$ATOMIC_FILE_DIR/src/AtomicFile.cls" ] || { echo "FAIL oorexx_atomic_file v0.1-dev1 not found (set ATOMIC_FILE_DIR)"; exit 2; }

WORK="$(mktemp -d "${TMPDIR:-/tmp}/source_editor.XXXXXX")"
if [ "${KEEP:-0}" = "1" ]; then echo "KEEP: work copy at $WORK"; else trap 'rm -rf "$WORK"' EXIT; fi
cp -r "$SRC" "$WORK/pkg"; ROOT="$WORK/pkg"
cp -r "$ATOMIC_FILE_DIR" "$WORK/atomic"; A="$WORK/atomic"

echo "== build: oorexx_atomic_file native (from source, in the work copy)"
make -s -C "$A/native" clean >/dev/null
make -s -C "$A/native" OOREXX_ROOT="$OOREXX_ROOT"

export PATH="$(dirname "$REXX_BIN"):$PATH"
export LD_LIBRARY_PATH="$A/native:$OOREXX_ROOT/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export REXX_PATH="$ROOT/src:$A/src:$A/src/providers:$OOREXX_STD"
cd "$ROOT"
fail=0
for t in test_source_editor test_dev9; do
  echo "== $t"
  if "$REXX_BIN" "tests/$t.rex" > "$WORK/$t.out" 2>&1; then
    echo "PASS $t ($(grep -c '^PASS' "$WORK/$t.out") checks)"
  else
    cat "$WORK/$t.out"; echo "FAIL $t"; fail=1
  fi
done
echo "== the editor checks itself"
"$REXX_BIN" bin/code-editor.rex check src/SourceEditor.cls
for f in src/*.cls bin/*.rex; do "$REXX_BIN" bin/code-editor.rex lint "$f" | tail -1 | sed "s|^|$f: |"; done
[ "$fail" = 0 ] && echo "PASS oorexx_source_editor v0.1-dev9" || { echo "FAIL oorexx_source_editor v0.1-dev9"; exit 1; }
