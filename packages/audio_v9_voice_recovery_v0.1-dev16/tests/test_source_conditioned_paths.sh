#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
T="$ROOT/run/test/source_conditioned_paths"; rm -rf "$T"; mkdir -p "$T/masks"
"$ROOT/native/make_edge_calibration_fixture" "$T/fc.f32" "$T/fd.f32" 8000 16
n=$((16*8000)); edge=63832482018; ws=$((edge-8)); left=20231009_202339_tp00002_original.ogg; right=20231009_210018_tp00003_original.ogg
printf 'start_sample\tend_sample\tlow_hz\thigh_hz\tweight\n0\t%s\t160\t900\t1\n' "$n" > "$T/masks/A.fc.select.tsv"; cp "$T/masks/A.fc.select.tsv" "$T/masks/A.fd.select.tsv"
printf 'start_sample\tend_sample\tlow_hz\thigh_hz\tweight\n0\t%s\t1050\t2700\t1\n' "$n" > "$T/masks/B.fc.select.tsv"; cp "$T/masks/B.fc.select.tsv" "$T/masks/B.fd.select.tsv"
cat > "$T/masks/groups.tsv" <<EOF2
group_id	kind	families	fc_before	fc_after	fd_before	fd_after	score	fc_mask	fd_mask
SRC_A	FAMILY	FAM_A	10	10	10	10	20	$T/masks/A.fc.select.tsv	$T/masks/A.fd.select.tsv
SRC_B	FAMILY	FAM_B	10	10	10	10	20	$T/masks/B.fc.select.tsv	$T/masks/B.fd.select.tsv
EOF2
"$ROOT/tools/run_rexx_pinned.sh" "$ROOT/tools/extract_source_conditioned_paths.rex" "$T/fc.f32" "$T/fd.f32" "$T/masks/groups.tsv" fc "$left" "$right" "$edge" "$ws" "$T/points.tsv" "$T/tmp" > "$T/points.log"
points=$(awk 'END{print NR-1}' "$T/points.tsv"); [ "$points" -eq 36 ] || { echo "FAIL 16s trajectory point count=$points" >&2; exit 1; }
for path in DIRECT REFINED; do
  before=$(awk -F '\t' -v p="$path" '$7==p && $9=="BEFORE" {n++} END{print n+0}' "$T/points.tsv")
  after=$(awk -F '\t' -v p="$path" '$7==p && $9=="AFTER" {n++} END{print n+0}' "$T/points.tsv")
  [ "$before" -eq 6 ] || { echo "FAIL $path BEFORE trajectory count=$before" >&2; exit 1; }
  [ "$after" -eq 6 ] || { echo "FAIL $path AFTER trajectory count=$after" >&2; exit 1; }
done
"$ROOT/tools/run_rexx_pinned.sh" "$ROOT/tools/observe_source_conditioned_edges.rex" "$T/points.tsv" "$T/evidence.tsv" 2 > "$T/evidence.log"
# Coarse 80-sample envelope paths must never become exact clock evidence.
if awk -F '\t' 'NR>1 && $8 ~ /ENVELOPE/ {found=1} END{exit found?0:1}' "$T/evidence.tsv"; then echo 'FAIL envelope estimator gained sample-exact authority' >&2; exit 1; fi
# Broadband SRC_A independently recovers the fixture's true 10 -> 7 sample step.
count=$(awk -F '\t' '$12=="SRC_A" && $10==-3 {n++} END{print n+0}' "$T/evidence.tsv"); [ "$count" -eq 2 ] || { echo "FAIL SRC_A exact path evidence count=$count" >&2; exit 1; }
"$ROOT/tools/run_rexx_pinned.sh" "$ROOT/tools/solve_file_edges_v2.rex" "$T/map.tsv" "$T/evidence.tsv" > "$T/map.log"
status=$(awk -F '\t' -v r="$right" '$3==r {print $11}' "$T/map.tsv")
[ "$status" = CLOCK_CANDIDATE ] || { echo "FAIL conflicting independent source must not measure clock status=$status" >&2; exit 1; }
echo 'PASS source-conditioned path extraction 16s trajectory assertions=8'
