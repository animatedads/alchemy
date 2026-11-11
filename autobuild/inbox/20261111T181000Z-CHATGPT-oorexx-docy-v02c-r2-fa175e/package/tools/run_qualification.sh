#!/bin/sh
set -eu
REXX_BIN="${1:-rexx}"
REXX_BIN=$(command -v "$REXX_BIN") || { echo 'DOCY: ooRexx interpreter not found' >&2; exit 2; }
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
RDIR=$(dirname "$REXX_BIN")
RLIB=$(dirname "$RDIR")/lib
export REXX_PATH="$HERE:$RDIR${REXX_PATH:+:$REXX_PATH}"
export LD_LIBRARY_PATH="$RLIB${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
WORK_DIR=$(mktemp -d "${TMPDIR:-/tmp}/docy-qualification.XXXXXXXX")
trap 'rm -rf -- "$WORK_DIR"' EXIT HUP INT TERM
cp "$HERE/alchemy_shared_graph_office.docy" "$WORK_DIR/alchemy_shared_graph_office.docy"
cd "$WORK_DIR"
for casefile in tests/demo_test.rex tests/test_extension.rex tests/test_office_adapters.rex tests/test_native_odt_archive.rex tests/test_docy_archive_pipeline.rex tests/test_office_error_handling.rex tests/test_shared_mutation_plans.rex; do
  echo "== $casefile =="
  "$REXX_BIN" "$HERE/$casefile"
done
