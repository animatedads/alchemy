#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
T="$ROOT/run/test/reconstruction_processing"
rm -rf "$T"; mkdir -p "$T"
fc="$T/fc.f32"; fd="$T/fd.f32"; out="$T/out.f32"; plan="$T/plan.tsv"
"$ROOT/native/make_spatial_fixture" "$fc" "$fd" 8000 20 960
"$ROOT/tools/run_rexx_pinned.sh" "$ROOT/tools/render_reconstruction_chunk.rex" "$fc" "$fd" "$out" "$plan" >/dev/null
[ "$(stat -c %s "$out")" -eq $((20*8000*4)) ] || { echo 'FAIL processing render geometry' >&2; exit 1; }
rows=$(awk 'END{print NR-1}' "$plan")
[ "$rows" -ge 7 ] || { echo "FAIL processing plan too sparse rows=$rows" >&2; exit 1; }
awk -F '\t' 'NR>1 { if ($1 != prev && NR>2 && $1 < prev) exit 1; prev=$1; if ($6 <= 0) exit 1 } END { if (NR<2) exit 1 }' "$plan" || { echo 'FAIL processing plan invalid' >&2; exit 1; }
echo "PASS reconstruction processing samples=160000 rows=$rows"
