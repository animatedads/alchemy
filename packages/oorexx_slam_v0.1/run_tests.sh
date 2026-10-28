#!/bin/sh
# SLAM v0.1 qualification: segmenter, SQLite node store, edge weights, Task turns, corpus.
# Architecture: Tom Dyer. Code: Claude (Opus 5.5), 2026-10-28.
# Needs: ooRexx 5.x (rexx on PATH, plus its headers to build Rexx/SQL), gcc, make, patch, SQLite 3 dev files.
# ALCHEMY_REPO_ROOT: the alchemy checkout (default: two directories above this package).
# REXXSQL_LIBDIR: a directory that already holds librexxsql.so (default: build it now).
# REXX_INCDIR, REXX_LIBDIR: passed to the Rexx/SQL build when ooRexx is not installed system-wide.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO=${ALCHEMY_REPO_ROOT:-$(CDPATH= cd -- "$ROOT/../.." && pwd)}
P="$REPO/packages"
WORK=$(mktemp -d); trap 'rm -rf "$WORK"' EXIT
if [ -z "${REXXSQL_LIBDIR:-}" ]; then
  echo "== build librexxsql.so"
  sh "$P/oorexx_rexxsql_backend_v0.1/tools/build_rexxsql.sh" "$WORK/lib"
  REXXSQL_LIBDIR="$WORK/lib"
fi
export LD_LIBRARY_PATH="$REXXSQL_LIBDIR${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export REXX_PATH="$ROOT/src:$ROOT/vendor/rx2cpp:$P/oorexx_rexxsql_backend_v0.1/src:$P/oorexx_native_database_backends_v0.1/src"
cd "$ROOT"
echo "== corpus closure"
rexx corpus/corpus_check.rex corpus/circular_corpus_v2.csv | head -3
echo "== SLAM qualification"
rexx tests/test_slam.rex "$WORK|$P/oorexx_ml_v0.1-dev11|$ROOT/corpus/circular_corpus_v2.csv"
echo "== ChatGPT's task: compose, run, check two ways, break, learn"
rexx tests/test_compose.rex "$WORK|$P/oorexx_crypto_v0.8.3/src/crypto.cls|$P/oorexx_adb_v0.1-dev1/src/AdbAuth.cls"
echo "== ability before score on real contracts (rule from Claude (Opus 4.8))"
rexx tests/test_needs.rex "$WORK|$P/oorexx_crypto_v0.8.3/src/crypto.cls|$P/oorexx_adb_v0.1-dev1/src/AdbAuth.cls"
echo "== rx_mod_inverse condition check (fix found by SLAM, in the repository since 1f422d76)"
rexx tests/test_modinv.rex "$WORK|$P/oorexx_crypto_v0.8.3/src/crypto.cls|CHECK|$WORK/modinv.db|v0.8.3"
echo "== SLAM chooses its own path (ChatGPT's third task)"
rexx tests/test_choose.rex "$WORK|$REPO|$ROOT/tests/fixtures/standalone_pool.txt"
