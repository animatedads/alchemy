#!/usr/bin/env bash
set -euo pipefail
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
: "${REXX:=rexx}"
: "${REXXC:=rexxc}"

# Discover ooRexx standard-library classes carried beside the selected runtime
# (for r13196 this includes json.cls).  External REXX_PATH remains additive.
REXX_BIN=$(command -v "$REXX" 2>/dev/null || true)
REXX_STDLIB=""
if [[ -n "$REXX_BIN" && -f "$(dirname -- "$REXX_BIN")/json.cls" ]]; then
  REXX_STDLIB=$(dirname -- "$REXX_BIN")
fi

resolve_src() {
  local input="$1" marker="$2" label="$3"
  if [[ -z "$input" ]]; then
    echo "error: set $label to the external dependency package root (or src directory)" >&2
    return 2
  fi
  if [[ -f "$input" ]]; then
    [[ "$(basename -- "$input")" == "$marker" ]] || { echo "error: $label file must be $marker" >&2; return 2; }
    dirname -- "$input"
    return
  fi
  if [[ -f "$input/$marker" ]]; then
    CDPATH= cd -- "$input" && pwd
    return
  fi
  if [[ -f "$input/src/$marker" ]]; then
    CDPATH= cd -- "$input/src" && pwd
    return
  fi
  echo "error: cannot find $marker below $label=$input" >&2
  return 2
}

ALCHEMY_SRC=$(resolve_src "${ALCHEMY_OBJECTS_ROOT:-${ALCHEMY_OBJECTS_SRC:-}}" "AlchemyObject.cls" "ALCHEMY_OBJECTS_ROOT")
CRYPTO_SRC=$(resolve_src "${OOREXX_CRYPTO_ROOT:-${OOREXX_CRYPTO_SRC:-}}" "crypto.cls" "OOREXX_CRYPTO_ROOT")
MSQLSHIM_SRC=$(resolve_src "${MSQLSHIM_ROOT:-${MSQLSHIM_SRC:-}}" "MySQLDeflate.cls" "MSQLSHIM_ROOT")
JOURNAL_SRC=""
if [[ -f "$ROOT/IBM4361Journal.cls" ]]; then
  JOURNAL_SRC=$(resolve_src "${JOURNAL_POINTED_STATE_ROOT:-${JOURNAL_POINTED_STATE_SRC:-}}" "JournalPointedState.cls" "JOURNAL_POINTED_STATE_ROOT")
fi

if [[ -d "$ROOT/lib" ]]; then
  echo "error: IBM 4361 package must not vendor shared libraries; remove $ROOT/lib" >&2
  exit 2
fi
if find "$ROOT" -type f \( -name 'AlchemyObject.cls' -o -name 'crypto.cls' -o -name 'JournalPointedState.cls' \) -print -quit | grep -q .; then
  echo "error: shared Alchemy/crypto/journal sources must be loaded by reference, not carried in the package" >&2
  exit 2
fi

export REXX_PATH="$ROOT:$ROOT/tests:$ALCHEMY_SRC:$CRYPTO_SRC:$MSQLSHIM_SRC${JOURNAL_SRC:+:$JOURNAL_SRC}${REXX_STDLIB:+:$REXX_STDLIB}${REXX_PATH:+:$REXX_PATH}"

compile_count=0
while IFS= read -r src; do
  "$REXXC" "$src" >/dev/null
  compile_count=$((compile_count+1))
done < <(find "$ROOT" -type f \( -name '*.cls' -o -name '*.rex' \) | sort)
echo "COMPILE PASS $compile_count sources"

test_count=0
for t in "$ROOT"/tests/test_*.rex; do
  echo "== $(basename "$t") =="
  case "$(basename "$t")" in
    test_real_media.rex|test_real_mvt_ipl.rex)
      if [[ -n "${MVTRES_350:-}" ]]; then "$REXX" "$t" "$MVTRES_350" "${MVTRES_SHA256:-UNVERIFIED}"; else "$REXX" "$t"; fi
      ;;
    *) "$REXX" "$t" ;;
  esac
  test_count=$((test_count+1))
done
echo "RUNTIME PASS $test_count tests"
