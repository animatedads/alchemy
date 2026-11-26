#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
: "${ALCHEMY_REPO_ROOT:?Set ALCHEMY_REPO_ROOT to the estate checkout}"
lintdir="$ALCHEMY_REPO_ROOT/packages/oorexx_source_editor_v0.1-dev9/src"
# Verify the exact checker used to qualify this candidate.
[ "$(git hash-object "$lintdir/PitfallChecker.cls")" = e6ee19c34dd441170d8dcc023277b4042819463d ]
[ "$(git hash-object "$lintdir/SourceLint.cls")" = 7295efb10e6ff0b53315900eb26c9d747182c11c ]
export REXX_PATH="$lintdir${REXX_PATH:+:$REXX_PATH}"
sha256sum --check --quiet MANIFEST.sha256
for file in src/*.cls tests/*.rex; do
  rexx tests/lint.rex "$file"
done
rexx tests/board.rex
rexx tests/reference.rex
rexx tests/orders.rex
