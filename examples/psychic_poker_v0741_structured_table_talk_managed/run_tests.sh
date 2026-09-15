#!/bin/sh
set -eu

: "${REXX:=rexx}"
count=0
for t in $(printf '%s\n' test_*.rex | sort); do
    echo "== $t =="
    "$REXX" "$t"
    count=$((count + 1))
done

echo "PASS: $count test_*.rex files"
