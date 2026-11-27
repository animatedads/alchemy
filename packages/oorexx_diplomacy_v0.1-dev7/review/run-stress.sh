#!/bin/sh
# Reproducible supplemental acceptance audit, not the original Claude scripts.
set -eu
cd "$(dirname "$0")/.."
: "${ALCHEMY_REPO_ROOT:?Set ALCHEMY_REPO_ROOT to the estate checkout}"
lintdir="$ALCHEMY_REPO_ROOT/packages/oorexx_source_editor_v0.1-dev9/src"
[ "$(git hash-object "$lintdir/PitfallChecker.cls")" = e6ee19c34dd441170d8dcc023277b4042819463d ]
[ "$(git hash-object "$lintdir/SourceLint.cls")" = 7295efb10e6ff0b53315900eb26c9d747182c11c ]
export REXX_PATH="$PWD/src:$lintdir${REXX_PATH:+:$REXX_PATH}"
sha256sum --check --quiet MANIFEST.sha256
rexx tests/lint.rex review/random-positions.rex
rexx tests/lint.rex review/literal-mutate.rex
rexx review/random-positions.rex 20000 7 MIXED
rexx review/random-positions.rex 10000 8 CONVOY
rexx review/literal-mutate.rex 3000 9 CONVOY review/datc-v3.4-sixth-order.txt 6.F.
rexx review/literal-mutate.rex 3000 10 CONVOY review/datc-v3.4-additions-movement.txt 6.F.
