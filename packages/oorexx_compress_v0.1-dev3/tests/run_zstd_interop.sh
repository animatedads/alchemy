#!/bin/sh
set -eu
: "${REXX:=rexx}"
cd "$(dirname "$0")"
rm -rf work-zstd
mkdir work-zstd

# Native encoder -> reference decoder: checksummed Raw and RLE profiles.
printf 'native zstandard raw frame interoperability\n' > work-zstd/input
"$REXX" ../bin/oorexx-compress.rex zstd-raw work-zstd/input work-zstd/native-raw.zst >/dev/null
zstd -t work-zstd/native-raw.zst >/dev/null
zstd -dc work-zstd/native-raw.zst > work-zstd/reference.out
cmp work-zstd/input work-zstd/reference.out

dd if=/dev/zero of=work-zstd/rle.input bs=4096 count=8 2>/dev/null
"$REXX" ../bin/oorexx-compress.rex zstd-rle work-zstd/rle.input work-zstd/native-rle.zst >/dev/null
zstd -t work-zstd/native-rle.zst >/dev/null
zstd -dc work-zstd/native-rle.zst > work-zstd/rle.out
cmp work-zstd/rle.input work-zstd/rle.out

# Reference encoder -> native decoder: incompressible content normally becomes Raw_Block.
dd if=/dev/urandom of=work-zstd/random.input bs=4096 count=8 2>/dev/null
zstd -q -f work-zstd/random.input -o work-zstd/reference-raw.zst
"$REXX" ../bin/oorexx-compress.rex unzstd work-zstd/reference-raw.zst work-zstd/native.out >/dev/null
cmp work-zstd/random.input work-zstd/native.out

# A deterministic corpus large enough to exercise ordinary Compressed_Block,
# Huffman/FSE sequence coding, and multi-block table reuse in the reference encoder.
awk 'BEGIN {
  for (i=0; i<3200; i++) {
    c = 65 + (i % 23)
    printf("record-%05d|alpha-alpha-alpha|beta-%03d|%c%c%c|tail-%05d\\n", i, i%197, c,c,c, i%997)
  }
}' > work-zstd/compressed.input

for level in 1 3 9 15; do
  zstd -q -f -"$level" work-zstd/compressed.input -o "work-zstd/reference-l${level}.zst"
  "$REXX" ../bin/oorexx-compress.rex unzstd "work-zstd/reference-l${level}.zst" "work-zstd/native-l${level}.out" >/dev/null
  cmp work-zstd/compressed.input "work-zstd/native-l${level}.out"
done

# Content checksum is optional. Verify a no-check reference frame as well.
zstd -q -f --no-check -5 work-zstd/compressed.input -o work-zstd/reference-nocheck.zst
"$REXX" ../bin/oorexx-compress.rex unzstd work-zstd/reference-nocheck.zst work-zstd/native-nocheck.out >/dev/null
cmp work-zstd/compressed.input work-zstd/native-nocheck.out

# Unknown-size streaming input normally omits Frame_Content_Size and exercises a
# Window_Descriptor instead of Single_Segment framing.
cat work-zstd/compressed.input | zstd -q -3 -c > work-zstd/reference-streaming.zst
"$REXX" ../bin/oorexx-compress.rex unzstd work-zstd/reference-streaming.zst work-zstd/native-streaming.out >/dev/null
cmp work-zstd/compressed.input work-zstd/native-streaming.out

# Reference-produced concatenated frames must decode as concatenated content.
printf 'frame-one\n' > work-zstd/one.input
printf 'frame-two\n' > work-zstd/two.input
zstd -q -f work-zstd/one.input -o work-zstd/one.zst
zstd -q -f work-zstd/two.input -o work-zstd/two.zst
cat work-zstd/one.zst work-zstd/two.zst > work-zstd/concat.zst
"$REXX" ../bin/oorexx-compress.rex unzstd work-zstd/concat.zst work-zstd/concat.out >/dev/null
cat work-zstd/one.input work-zstd/two.input > work-zstd/concat.expected
cmp work-zstd/concat.expected work-zstd/concat.out

echo 'PASS Zstandard reference interoperability qualification'
