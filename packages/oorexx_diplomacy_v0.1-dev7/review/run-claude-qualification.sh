#!/bin/sh
# Reviewer-authored scripts recovered via mailbox, hash-verified.
set -eu
cd "$(dirname "$0")/.."
: "${ALCHEMY_REPO_ROOT:?Set ALCHEMY_REPO_ROOT to the estate checkout}"
lintdir="$ALCHEMY_REPO_ROOT/packages/oorexx_source_editor_v0.1-dev9/src"
[ "$(git hash-object "$lintdir/PitfallChecker.cls")" = e6ee19c34dd441170d8dcc023277b4042819463d ]
[ "$(git hash-object "$lintdir/SourceLint.cls")" = 7295efb10e6ff0b53315900eb26c9d747182c11c ]
export REXX_PATH="$PWD/src:$lintdir${REXX_PATH:+:$REXX_PATH}"
sha256sum --check --quiet MANIFEST.sha256
sha256sum --check --quiet evidence/reviewer-recovered.sha256
rexx tests/lint.rex tests/movement.rex
rexx tests/lint.rex tests/season.rex
rexx tests/lint.rex review/fuzz.rex
rexx tests/lint.rex review/mutate.rex
rexx tests/movement.rex review/claude-datc-v3.4-combined-movement.txt 10
rexx tests/season.rex review/datc-v3.4-additions-season.txt 3
rexx review/fuzz.rex 20000 7 MIXED
rexx review/fuzz.rex 10000 8 CONVOY
rexx review/mutate.rex 3000 9 review/claude-datc-v3.4-combined-movement.txt 6.F
