#!/bin/sh
set -eu
count=0
for t in test_*.rex; do
  echo "== $t =="
  rexx "$t"
  count=$((count+1))
done
echo "PASS: $count test_*.rex files"
