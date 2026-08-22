#!/bin/sh
set -eu
rm -rf work payload.zip payload.b64
cat payload/chunk.* > payload.b64
base64 -d payload.b64 > payload.zip
echo 'e70d62633ef535884165cc81fa87e766d4583e1bbf6eb00a6cc9de5aa8b431a8  payload.zip' | sha256sum -c -
mkdir work
unzip -q payload.zip -d work
cd work/psychic_poker_v0733_social_effects
export REXX_PATH="$PWD:$PWD/nosqlserver/src"
count=0
for t in test_*.rex; do
  echo "== $t =="
  rexx "$t"
  count=$((count+1))
done
echo "PASS: $count test_*.rex files"
