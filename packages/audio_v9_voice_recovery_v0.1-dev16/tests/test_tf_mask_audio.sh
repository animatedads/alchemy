#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
mkdir -p "$ROOT/run/test"
in="$ROOT/run/test/tf_input.f32"; out="$ROOT/run/test/tf_output.f32"; mask="$ROOT/run/test/tf_mask.tsv"
"$ROOT/native/make_tf_mask_fixture" "$in" 8000 4
cat > "$mask" <<'TSV'
start_sample	end_sample	low_hz	high_hz	gain	protect	confidence	family_id	speaker_id	reason
0	32000	300	500	1.2	1	1	VOICE	SPEAKER_0001	VOICE
0	32000	2000	2400	0.25	0	1	ALARM		ALARM
TSV
"$ROOT/tools/run_rexx_pinned.sh" "$ROOT/tests/test_tf_mask_native.rex" "$in" "$mask" "$out" >/dev/null
in400=$("$ROOT/native/measure_tone" "$in" 8000 400); out400=$("$ROOT/native/measure_tone" "$out" 8000 400)
in2200=$("$ROOT/native/measure_tone" "$in" 8000 2200); out2200=$("$ROOT/native/measure_tone" "$out" 8000 2200)
awk -v a="$in400" -v b="$out400" 'BEGIN{if(!(b>a*1.10)){print "FAIL voice band not boosted",a,b;exit 1}}'
awk -v a="$in2200" -v b="$out2200" 'BEGIN{if(!(b<a*0.40)){print "FAIL alarm band not attenuated",a,b;exit 1}}'
printf 'PASS tf mask audio voice_ratio=%.6f alarm_ratio=%.6f\n' "$(awk -v a="$in400" -v b="$out400" 'BEGIN{print b/a}')" "$(awk -v a="$in2200" -v b="$out2200" 'BEGIN{print b/a}')"
