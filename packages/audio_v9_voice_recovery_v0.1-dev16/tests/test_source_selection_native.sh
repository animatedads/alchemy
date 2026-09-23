#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
T="$ROOT/run/test/source_selection_native"; rm -rf "$T"; mkdir -p "$T"
"$ROOT/native/make_tf_mask_fixture" "$T/in.f32" 8000 2
samples=$((2*8000))
printf 'start_sample\tend_sample\tlow_hz\thigh_hz\tweight\n0\t%s\t280\t520\t1\n' "$samples" > "$T/select.tsv"
cat > "$T/render.rex" <<'REXX'
numeric digits 30
parse arg inPath maskPath outPath
root=value('AUDIO_V9_VOICE_ROOT',,'ENVIRONMENT'); if root='' then root='.'
p=.AudioV9SpatialNativeProvider~new(root||'/run/native/av9_spatial.bridge.json')
p~renderSelection(inPath,maskPath,outPath,8000,256,64)
say 'PASS selection render bytes='||stream(outPath,'C','QUERY SIZE')
::requires 'AudioV9SpatialNativeProvider.cls'
REXX
"$ROOT/tools/run_rexx_pinned.sh" "$T/render.rex" "$T/in.f32" "$T/select.tsv" "$T/out.f32" >/dev/null
[ "$(stat -c %s "$T/in.f32")" -eq "$(stat -c %s "$T/out.f32")" ] || { echo 'FAIL selection geometry' >&2; exit 1; }
a400=$("$ROOT/native/measure_tone" "$T/out.f32" 8000 400)
a2200=$("$ROOT/native/measure_tone" "$T/out.f32" 8000 2200)
awk -v keep="$a400" -v reject="$a2200" 'BEGIN { if (!(keep > .05 && reject < .005)) { print "FAIL source selection amplitudes",keep,reject > "/dev/stderr"; exit 1 } }'
echo "PASS source selection native keep=$a400 reject=$a2200"
