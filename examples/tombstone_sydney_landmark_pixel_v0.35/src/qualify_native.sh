#!/bin/sh
# Validate native C input failures; flags, hashes and sizes are not advisory.
set -eu
root=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
cc -std=c11 -O2 -Wall -Wextra -Werror "$root/static_landmark_diff.c" -o "$root/static_landmark_diff"
cruise=c3bea629be6f054bafe08d50d03e259f894a97ddeae089dd69d77da0985cae7e
baseline=58616633e8239ec1f6a0699231f1466279af794d622090086babbc4af01c100d
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
n=0
reject() {
 name=$1; shift
 if "$root/static_landmark_diff" "$@" >"$tmp/output" 2>"$tmp/error"; then
  echo "FAIL: malformed native input admitted: $name" >&2; exit 4
 fi
 n=$((n+1)); echo "NATIVE_REJECTED $name"
}
reject missing_args
reject bad_sha "$root/cruise.rgb" "$root/baseline.rgb" BAD "$baseline"
reject duplicate_source_sha "$root/cruise.rgb" "$root/baseline.rgb" "$cruise" "$cruise"
reject nonexistent_file "$tmp/missing" "$root/baseline.rgb" "$cruise" "$baseline"
head -c 690000 "$root/cruise.rgb" > "$tmp/short.rgb"
reject truncated_rgb_stack "$tmp/short.rgb" "$root/baseline.rgb" "$cruise" "$baseline"
[ "$n" = 5 ] || exit 5
"$root/static_landmark_diff" "$root/cruise.rgb" "$root/baseline.rgb" "$cruise" "$baseline" >"$tmp/valid.psv"
cmp "$tmp/valid.psv" "$root/anchor_receipts.psv"
echo 'NATIVE_IMAGE_GATE_PASS 5/5 rejected, valid source receipt byte-identical'
