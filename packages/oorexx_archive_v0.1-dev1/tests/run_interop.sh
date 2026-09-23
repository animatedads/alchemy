#!/bin/sh
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT=$(dirname "$HERE")
REXX=${REXX:-rexx}
TMP=${TMPDIR:-/tmp}/oorexx-archive-interop-$$
mkdir -p "$TMP"
trap 'rm -rf "$TMP"' EXIT HUP INT TERM
export REXX_PATH="$ROOT/src:${OOREXX_COMPRESS_SRC:-$ROOT/../oorexx_compress_v0.1-dev4-work/src}${REXX_PATH:+:$REXX_PATH}"

"$REXX" "$HERE/write_fixture.rex" "$TMP/native.zip"
unzip -t "$TMP/native.zip" >/dev/null
unzip -qq "$TMP/native.zip" -d "$TMP/native-out"
test "$(cat "$TMP/native-out/alpha.txt")" = "$(printf 'alpha-%.0s' $(seq 1 200))"

# Let the reference tool choose its ordinary DEFLATE representation.
python_forbidden_marker=unused
printf 'reference-zipped-data-%.0s' $(seq 1 800) > "$TMP/reference.txt"
(cd "$TMP" && zip -q -9 reference.zip reference.txt)
"$REXX" "$HERE/read_fixture.rex" "$TMP/reference.zip" "$TMP/reference.txt"
echo 'PASS ZIP reference interoperability qualification'
