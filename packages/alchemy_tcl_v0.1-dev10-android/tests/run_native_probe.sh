#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
CC=${CC:-cc}
OUT="${TMPDIR:-/tmp}/alchemy_tcl_resident_probe.$$"
trap 'rm -f "$OUT"' EXIT HUP INT TERM
"$CC" -std=c11 -Wall -Wextra -Werror "$ROOT/native/tcl_resident_probe.c" -ldl -o "$OUT"
"$OUT"
