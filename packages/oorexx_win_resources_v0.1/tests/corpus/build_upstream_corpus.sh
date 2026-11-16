#!/bin/sh
# Compile the official ooRexx ooDialog sample .rc corpus with llvm-rc.
#   sh build_upstream_corpus.sh /path/to/ooRexx OUT_DIR
# The 26 paths come from packages/oorexx_rc_executable_tree/corpus/official_oodialog.txt.
# Only a successful compile leaves a .res in OUT_DIR; failures are listed in
# OUT_DIR/FAILURES.txt and leave NAME.res.tmp and NAME.log beside it.  The upstream files are never changed: a copy with
# Windows path separators (\\) turned into / is compiled from OUT_DIR/src, with
# the source folder and samples/windows/oodialog/bmp as include paths.  SDK
# headers come from ../sdk (stand-ins with the SDK's values).
# Architecture: Tom Dyer.  Coding: Claude (Opus 5.5), 2026-11-14.
set -eu
CHECKOUT=$(cd "$1" && pwd)
OUT=$2
HERE=$(cd "$(dirname "$0")" && pwd)
SDK="$HERE/../sdk"
MANIFEST="$HERE/../../../oorexx_rc_executable_tree/corpus/official_oodialog.txt"
mkdir -p "$OUT/src"
: > "$OUT/FAILURES.txt"
ok=0
bad=0
for rel in $(grep -v '^#' "$MANIFEST"); do
  name=$(basename "$rel" .rc)
  sed 's|\\\\|/|g' "$CHECKOUT/$rel" > "$OUT/src/$name.rc"
  if llvm-rc /nologo /I "$SDK" /I "$CHECKOUT/$(dirname "$rel")" /I "$CHECKOUT/samples/windows/oodialog/bmp" \
       /FO "$OUT/$name.res.tmp" "$OUT/src/$name.rc" > "$OUT/$name.log" 2>&1; then
    mv "$OUT/$name.res.tmp" "$OUT/$name.res"
    ok=$((ok + 1))
  else
    bad=$((bad + 1))
    echo "$rel: $(head -c 300 "$OUT/$name.log" | tr '\n' ' ')" >> "$OUT/FAILURES.txt"
  fi
done
echo "compiled=$ok failed=$bad (see $OUT/FAILURES.txt)"
