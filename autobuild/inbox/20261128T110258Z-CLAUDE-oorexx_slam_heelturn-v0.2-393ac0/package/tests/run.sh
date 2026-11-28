#!/bin/sh
# Heel Turn SLAM qualification. Architecture: Tom Dyer. Code: Claude (Opus 5.5).
# Needs rexx (ooRexx 5.3) on PATH and ALCHEMY_REPO_ROOT pointing at the estate.
set -eu
cd "$(dirname "$0")/.."
: "${ALCHEMY_REPO_ROOT:?Set ALCHEMY_REPO_ROOT to the estate checkout}"
A="$ALCHEMY_REPO_ROOT/packages"
D="$A/oorexx_diplomacy_v0.1-dev7r1"
BC="$A/oorexx_slam_bostoncrab_v0.24"
LINT="$A/oorexx_source_editor_v0.1-dev9/src"
export HEELTURN_ROOT="$PWD"
export REXX_PATH="$PWD/src:$PWD/tools:$PWD/tests:$A/oorexx_reasoned_thought_v0.1/src:$A/virtual_ryta_hardworld_v0.31_work/librarian:$D/src:$D/tools:$A/oorexx_logging_v0.7/src:$A/oorexx_crypto_v0.8.3/src:$BC/tests:$LINT"
sha256sum --check --quiet MANIFEST.sha256
for f in src/*.cls tools/*.cls tools/*.rex tests/*.cls tests/*.rex; do
  rexx "$BC/tests/rexx_pitfalls.rex" "$f" >/dev/null
  rexx "$D/tests/lint.rex" "$f" | grep -q "findings: 0"
done
echo "PASS lint (Boston Crab pitfalls P1-P4, SourceLint) on all sources"
rexx tests/prompt.rex .
rexx tests/press.rex .
rexx tests/orders.rex .
rexx tests/truth.rex .
rexx tests/answers.rex .
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT HUP INT TERM
rexx tests/tactics.rex "$PWD" "$D" "$work"
rexx tests/game.rex "$PWD" "$D" "$work"
