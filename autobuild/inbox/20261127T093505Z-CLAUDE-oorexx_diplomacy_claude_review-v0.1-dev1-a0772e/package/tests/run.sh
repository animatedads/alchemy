#!/bin/sh
# Independent review checks against the published dev5 engine package.
# Author: Claude (Opus 5.5). Architecture: Tom Dyer.
# Every check must exit 0; output is kept in a log and its tail shown.
set -eu
: "${ALCHEMY_REPO_ROOT:?Set ALCHEMY_REPO_ROOT to the estate checkout}"
here=$(cd "$(dirname "$0")/.." && pwd)
engine="$ALCHEMY_REPO_ROOT/packages/oorexx_diplomacy_v0.1-dev5"
lintdir="$ALCHEMY_REPO_ROOT/packages/oorexx_source_editor_v0.1-dev9/src"
logdir="$ALCHEMY_REPO_ROOT/packages/oorexx_logging_v0.7/src"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

check() {
  label="$1"
  shift
  echo "== $label"
  if "$@" > "$work/out.txt" 2>&1; then
    tail -3 "$work/out.txt"
  else
    cat "$work/out.txt"
    echo "FAILED: $label"
    exit 1
  fi
}

check "review package manifest" sh -c "cd '$here' && sha256sum -c --quiet MANIFEST.sha256"
cd "$engine"
for f in fuzz.rex mutate.rex game_audit.rex DiplomacyRichStubSource.cls regex_probe.rex regex_timing.rex; do
  check "lint $f" env REXX_PATH="$lintdir" rexx tests/lint.rex "$here/review/$f"
done
export REXX_PATH="$engine/src:$engine/tools:$here/review:$logdir"
check "DATC v3.4 movement additions" rexx tests/movement.rex "$here/review/datc-v3.4-additions-movement.txt" 10
check "DATC v3.4 season additions" rexx tests/season.rex "$here/review/datc-v3.4-additions-season.txt" 3
check "movement fuzz MIXED" rexx "$here/review/fuzz.rex" 1000 7 MIXED
check "movement fuzz CONVOY" rexx "$here/review/fuzz.rex" 500 8 CONVOY
check "paradox mutation" rexx "$here/review/mutate.rex" 300 9 "$here/review/datc-v3.4-additions-movement.txt" 6.F
check "full-game audit RICH" rexx "$here/review/game_audit.rex" 5 1000 RICH "$work/games"
check "full-game audit RANDOM" rexx "$here/review/game_audit.rex" 3 3000 RANDOM "$work/games"
echo "== all review checks passed"
