#!/bin/sh
# Build librexxsql.so (Rexx/SQL 2.6B3 + Alchemy patches) for ooRexx 4.0+/5.x and SQLite 3.
# Author: Claude (Opus 5.5), 2026-10-24. Architecture: Tom Dyer. Rexx/SQL: Mark Hessling (LGPL).
# Usage: sh tools/build_rexxsql.sh OUT_DIR
#   OUT_DIR receives librexxsql.so and build.log.
#   Optional: REXX_INCDIR, REXX_LIBDIR (ooRexx headers/libs), SQLITE_LIBDIR.
set -eu
OUT=${1:?usage: build_rexxsql.sh OUT_DIR}
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
mkdir -p "$OUT"
OUT=$(CDPATH= cd -- "$OUT" && pwd)
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
cp -r "$ROOT/upstream/rxsql26B3" "$WORK/src"
for p in "$ROOT"/upstream/patches/*.patch; do
  if command -v patch >/dev/null 2>&1; then
    patch -s -p1 -d "$WORK/src" < "$p"
  else
    (cd "$WORK/src" && git apply -p1 "$p")
  fi
done
chmod +x "$WORK/src/configure" "$WORK/src/install-sh" "$WORK/src/common/config.guess" "$WORK/src/common/config.sub"
mkdir "$WORK/build"
cd "$WORK/build"
set -- --with-rexx=oorexx --with-db=sqlite3
[ -n "${REXX_INCDIR:-}" ] && set -- "$@" --with-rexxincdir="$REXX_INCDIR"
[ -n "${REXX_LIBDIR:-}" ] && set -- "$@" --with-rexxlibdir="$REXX_LIBDIR"
[ -n "${SQLITE_LIBDIR:-}" ] && set -- "$@" --with-dblibdir="$SQLITE_LIBDIR"
sh ../src/configure "$@" > "$OUT/build.log" 2>&1 || { tail -20 "$OUT/build.log"; exit 1; }
grep -q '#define OOREXX_40 1' config.h || { echo "configure did not select the ooRexx 4.0+ API" >&2; exit 1; }
make >> "$OUT/build.log" 2>&1 || { grep -E 'error' "$OUT/build.log" | head -20; exit 1; }
cp librexxsql.so "$OUT/"
echo "built $OUT/librexxsql.so"
