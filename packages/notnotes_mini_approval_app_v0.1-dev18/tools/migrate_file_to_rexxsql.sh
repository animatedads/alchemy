#!/usr/bin/env bash
# Source-preserving legacy Mini NotNotes -> indexed Rexx/SQL SQLite conversion.
# Takes a private filesystem copy before asking FileDatabaseEngine to open it.
set -euo pipefail
if [[ $# -ne 2 ]]; then
  echo "usage: $0 LEGACY_STORE_DIRECTORY NEW_TARGET.sqlite" >&2
  exit 64
fi
source_root=$1
target=$2
here=$(cd "$(dirname "$0")/.." && pwd)
: "${REXX_BIN:=rexx}"
: "${REXX_HOME:=/usr/local}"
if [[ ! -f "$source_root/database.yaml" || ! -d "$source_root" ]]; then
  echo "MIGRATION_REFUSED: source directory/database.yaml missing" >&2; exit 66
fi
if [[ -e "$target" || -L "$target" || -e "$target-wal" || -e "$target-shm" ]]; then
  echo "MIGRATION_REFUSED: SQLite destination or journal exists" >&2; exit 73
fi
# Keep Rexx arg decoding unambiguous; paths with spaces need a dedicated argv
# entrypoint rather than allowing Rexx PARSE ARG to split them silently.
if [[ "$source_root" == *[[:space:]]* || "$target" == *[[:space:]]* ]]; then
  echo "MIGRATION_REFUSED: paths containing whitespace are not yet supported" >&2; exit 64
fi
case "$target" in
  /*) ;;
  *) target="$(pwd)/$target";;
esac
source_root=$(cd "$source_root" && pwd -P)
if [[ "$target" == "$source_root"/* ]]; then
  echo "MIGRATION_REFUSED: destination must not be inside the live source store" >&2; exit 73
fi
scratch=$(mktemp -d "${TMPDIR:-/tmp}/notnotes-migrate.XXXXXX")
trap 'rm -rf -- "$scratch"' EXIT
mkdir -p "$scratch/snapshot"
cp -a -- "$source_root/." "$scratch/snapshot/"
# Refuse symlinks: an in-store link might point outside the snapshot and let
# journal recovery change the original file store.
if find "$scratch/snapshot" -type l -print -quit | grep -q .; then
  echo "MIGRATION_REFUSED: source contains symlinks; snapshot is not isolated" >&2
  exit 73
fi
# Existing native provider is a neighbour. There is deliberately no local
# replacement for librexxsql.so.
rexxsql_src="$here/../oorexx_rexxsql_backend_v0.1/src"
native_db_src="$here/../oorexx_native_database_backends_v0.1/src"
if [[ ! -d "$rexxsql_src" || ! -d "$native_db_src" ]]; then
  echo "MIGRATION_REFUSED: existing Rexx/SQL provider source not found" >&2; exit 69
fi
export REXX_PATH="$here:$here/src:$here/vendor/nosql:$here/vendor/notnotes:$rexxsql_src:$native_db_src:$REXX_HOME/share/ooRexx:$REXX_HOME/bin${REXX_PATH:+:$REXX_PATH}"
export LD_LIBRARY_PATH="${REXXSQL_LIB_DIR:+$REXXSQL_LIB_DIR:}$REXX_HOME/lib64:$REXX_HOME/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export MININOTES_DB_BACKEND=rexxsql-sqlite
# Never remove or overwrite a failed target automatically: it is not accepted
# until MIGRATION_VERIFIED_PASS and needs an explicit human disposition.
cd "$here"
"$REXX_BIN" tools/migrate_file_to_rexxsql.rex "$scratch/snapshot" "$target"
