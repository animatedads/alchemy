#!/bin/sh
# Fail closed; materialise outputs only after BOTH native and ooRexx receipts PASS.
set -eu
if [ "$#" -ne 8 ]; then
 echo 'USAGE qualify_tripwire.sh nodes.psv source.v5b water_mask.psv gates.psv sourceSHA256 original.mp4 outputPrefix rexx_bin' >&2
 exit 2
fi
nodes=$1;v5b=$2;mask=$3;gates=$4;sha=$5;video=$6;prefix=$7;rexx=$8
root=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
actual=$(sha256sum "$video" | cut -d' ' -f1)
[ "$actual" = "$sha" ] || { echo "SOURCE_MEDIA_HASH_MISMATCH expected=$sha actual=$actual" >&2; exit 5; }
cc -std=c11 -O2 -Wall -Wextra -Werror "$root/v5v_line_band_scan.c" -lm -o "$root/v5v_line_band_scan"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT HUP INT TERM
"$root/v5v_line_band_scan" "$nodes" "$v5b" "$mask" "$gates" "$work/lines.psv" "$work/water.psv"
export REXX_PATH="$root${REXX_PATH:+:$REXX_PATH}"
"$rexx" "$root/test_v5v_tripwire_follow.rex"
"$rexx" "$root/follow_v5v_gate_movement.rex" "$nodes" "$work/water.psv" "$gates" "$work/follow.psv" "$sha"
"$rexx" "$root/verify_tripwire_receipts.rex" "$nodes" "$work/follow.psv" "$gates" "$sha"
# Three atomic renames; PASS file is the single final commit marker.
mv "$work/lines.psv" "${prefix}.line_components.psv"
mv "$work/water.psv" "${prefix}.water_components.psv"
mv "$work/follow.psv" "${prefix}.gate_follow.psv"
{
 echo 'qualification=PASS'
 echo "source_sha256=$sha"
 echo "source_v5v_sha256=$(sha256sum "$v5b" | cut -d' ' -f1)"
 echo "gates_sha256=$(sha256sum "$gates" | cut -d' ' -f1)"
 sha256sum "${prefix}.line_components.psv" "${prefix}.water_components.psv" "${prefix}.gate_follow.psv"
} > "${prefix}.PASS.tmp"
mv "${prefix}.PASS.tmp" "${prefix}.PASS"
echo 'V5V_TRIPWIRE_QUALIFIED_SOURCE_COMMITTED PASS'
