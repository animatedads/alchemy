#!/bin/sh
set -eu
: "${REXX:=rexx}"
cd "$(dirname "$0")"
rm -rf work-interop
mkdir work-interop
printf 'abcabcabcabcabcabcabcabcabcabc\n' > work-interop/input
../bin/oorexx-compress.rex gzip work-interop/input work-interop/fixed.gz >/dev/null
gzip -t work-interop/fixed.gz
gzip -dc work-interop/fixed.gz > work-interop/system.out
cmp work-interop/input work-interop/system.out
../bin/oorexx-compress.rex gunzip work-interop/fixed.gz work-interop/native.out >/dev/null
cmp work-interop/input work-interop/native.out

../bin/oorexx-compress.rex gzip-stored work-interop/input work-interop/stored.gz >/dev/null
gzip -t work-interop/stored.gz

# Ordinary gzip is normally dynamic-Huffman for a sufficiently compressible input.
yes 'dynamic-huffman-qualification-line' | head -c 65536 > work-interop/dynamic.input || true
gzip -c work-interop/dynamic.input > work-interop/dynamic.gz
"$REXX" ./test_expected_failure.rex GUNZIP work-interop/dynamic.gz

# CRC corruption must fail closed.
cp work-interop/fixed.gz work-interop/badcrc.gz
size=$(wc -c < work-interop/badcrc.gz)
offset=$((size - 8))
printf '\000' | dd of=work-interop/badcrc.gz bs=1 seek="$offset" conv=notrunc 2>/dev/null
"$REXX" ./test_expected_failure.rex GUNZIP work-interop/badcrc.gz

echo 'PASS external gzip interoperability qualification'
