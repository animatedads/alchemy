#!/bin/sh
# Fails if any corrupted input is admitted as a valid tripwire receipt.
set -eu
[ "$#" -eq 7 ] || { echo 'USAGE negative_tripwire.sh nodes.v5v.psv .v5b mask gates events SHA256 rexx_bin' >&2; exit 2; }
nodes=$1;binary=$2;mask=$3;gates=$4;events=$5;sha=$6;rexx=$7
base=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
export REXX_PATH="$base${REXX_PATH:+:$REXX_PATH}"
count=0
mustFail() {
 label=$1;shift
 if "$@" > "$tmp/case.log" 2>&1; then echo "NEGATIVE_FAIL $label: accepted bad input" >&2;exit 9; fi
 grep -Eq 'V5V_LINE_SCAN_FAIL|V5V_GATE_RECEIPTS_FAIL' "$tmp/case.log" || { echo "NEGATIVE_FAIL $label: no fail-closed diagnostic" >&2;cat "$tmp/case.log";exit 10; }
 count=$((count+1));echo "REJECTED $label"
}
cp "$events" "$tmp/forged.events"; sed -i '2s/OBSERVED_UNTESTED$/TESTED/' "$tmp/forged.events"
mustFail forged_authority "$rexx" "$base/verify_tripwire_receipts.rex" "$nodes" "$tmp/forged.events" "$gates" "$sha"
cp "$events" "$tmp/forged.events"; sed -i '2s/sha256:[a-f0-9]\{64\}/sha256:0000000000000000000000000000000000000000000000000000000000000000/' "$tmp/forged.events"
mustFail forged_source "$rexx" "$base/verify_tripwire_receipts.rex" "$nodes" "$tmp/forged.events" "$gates" "$sha"
awk -F'|' 'BEGIN{OFS="|"} $2=="LOCAL_SEARCH_REQUESTED"&&!done{$6=$6+2;done=1}{print}' "$events" > "$tmp/forged.events"
mustFail future_frame_wrong "$rexx" "$base/verify_tripwire_receipts.rex" "$nodes" "$tmp/forged.events" "$gates" "$sha"
awk -F'|' 'BEGIN{OFS="|"} $2=="LOCAL_SEARCH_REQUESTED"&&!done{$15=400;done=1}{print}' "$events" > "$tmp/forged.events"
mustFail area_limit_bypass "$rexx" "$base/verify_tripwire_receipts.rex" "$nodes" "$tmp/forged.events" "$gates" "$sha"
cp "$events" "$tmp/forged.events"; sed -i '2s/|WEST|/|UNDEFINED|/;2s/|CENTRE|/|UNDEFINED|/;2s/|EAST|/|UNDEFINED|/' "$tmp/forged.events"
mustFail unknown_gate "$rexx" "$base/verify_tripwire_receipts.rex" "$nodes" "$tmp/forged.events" "$gates" "$sha"
cp "$events" "$tmp/forged.events"; sed -n '2p' "$events" >> "$tmp/forged.events"
mustFail repeated_event "$rexx" "$base/verify_tripwire_receipts.rex" "$nodes" "$tmp/forged.events" "$gates" "$sha"
cp "$nodes" "$tmp/forged.nodes"; sed -i '2s/OBSERVED_UNTESTED$/TESTED/' "$tmp/forged.nodes"
mustFail forged_frame_authority "$base/v5v_line_band_scan" "$tmp/forged.nodes" "$binary" "$mask" "$gates" "$tmp/lines" "$tmp/water"
cp "$nodes" "$tmp/forged.nodes"; sed -i '3s/|DELTA|/|KEYFRAME|/' "$tmp/forged.nodes"
mustFail invalid_delta_schedule "$base/v5v_line_band_scan" "$tmp/forged.nodes" "$binary" "$mask" "$gates" "$tmp/lines" "$tmp/water"
cp "$nodes" "$tmp/forged.nodes"; sed -i '3s/|2739|/|999999|/;3s/|2250|/|999999|/' "$tmp/forged.nodes"
# independent byte-offset corruption, rewrite field 8 unconditionally
awk -F'|' 'BEGIN{OFS="|"}NR==3{$8=999999}{print}' "$nodes" > "$tmp/forged.nodes"
mustFail invalid_record_offset "$base/v5v_line_band_scan" "$tmp/forged.nodes" "$binary" "$mask" "$gates" "$tmp/lines" "$tmp/water"
head -c 12000 "$binary" > "$tmp/short.v5b"
mustFail truncated_v5v_payload "$base/v5v_line_band_scan" "$nodes" "$tmp/short.v5b" "$mask" "$gates" "$tmp/lines" "$tmp/water"
cp "$gates" "$tmp/forged.gates"; sed -i '2s/|12|28|12|38|/|79|1|79|2|/' "$tmp/forged.gates"
mustFail skyline_or_bad_gate_geometry "$base/v5v_line_band_scan" "$nodes" "$binary" "$mask" "$tmp/forged.gates" "$tmp/lines" "$tmp/water"
[ "$count" -eq 11 ] || { echo "EXPECTED 11 NEGATIVES, got $count" >&2;exit 12; }
echo 'V5V_TRIPWIRE_NEGATIVE_PASS 11/11'
