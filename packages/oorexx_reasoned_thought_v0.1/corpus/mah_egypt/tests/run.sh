#!/bin/sh
set -eu
CASE_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
REXX_BIN=${REXX_BIN:-rexx}
# Published Git tree: use the package's canonical operator and WorldEnsemble.
# Portable standalone ZIP: use the pinned source copies in vendor/.
PKG_ROOT=$(CDPATH= cd -- "$CASE_ROOT/../.." && pwd)
if [ -f "$PKG_ROOT/src/StandardApplicationAudit.cls" ] && \
   [ -f "$PKG_ROOT/tests/vanishing_dinner/WorldEnsemble.cls" ]; then
  AUDIT_ROOT="$PKG_ROOT/src"
  WORLDS_ROOT="$PKG_ROOT/tests/vanishing_dinner"
elif [ -f "$CASE_ROOT/vendor/StandardApplicationAudit.cls" ] && \
     [ -f "$CASE_ROOT/vendor/WorldEnsemble.cls" ]; then
  AUDIT_ROOT="$CASE_ROOT/vendor"
  WORLDS_ROOT="$CASE_ROOT/vendor"
else
  echo 'MISSING_DEPENDENCY: canonical StandardApplicationAudit/WorldEnsemble (or standalone pinned vendor)' >&2
  exit 3
fi
REXX_PATH="$CASE_ROOT/src:$AUDIT_ROOT:$WORLDS_ROOT" "$REXX_BIN" "$CASE_ROOT/tests/test_mah_judgment.rex"
REXX_PATH="$CASE_ROOT/src:$AUDIT_ROOT:$WORLDS_ROOT" "$REXX_BIN" "$CASE_ROOT/tests/test_mah_edge_soundness.rex"
