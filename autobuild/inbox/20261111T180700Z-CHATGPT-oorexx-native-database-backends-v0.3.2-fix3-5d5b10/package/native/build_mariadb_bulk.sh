#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${1:-$ROOT/mysql/liboorexx_mariadb_bulk.so}"
CC="${CC:-cc}"
CFLAGS="${CFLAGS:--O2 -fPIC -Wall -Wextra -Werror}"
read -r -a PCFLAGS <<<"$(pkg-config --cflags libmariadb)"
read -r -a PLIBS <<<"$(pkg-config --libs libmariadb)"
"$CC" $CFLAGS -shared "${PCFLAGS[@]}" "$ROOT/native/mariadb_bulk_shim.c" -o "$OUT" "${PLIBS[@]}"
printf '%s\n' "$OUT"
