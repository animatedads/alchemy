#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
T="$ROOT/run/test/source_conditioned_complexity_continue"
rm -rf "$T"; mkdir -p "$T/fakeroot/tools" "$T/corpus" "$T/out"
cp "$ROOT/tools/run_source_conditioned_calibration_worker.sh" "$T/fakeroot/tools/"
cat > "$T/fakeroot/tools/verify_corpus.sh" <<'SH'
#!/bin/sh
exit 0
SH
cat > "$T/fakeroot/tools/prepare_runtime.sh" <<'SH'
#!/bin/sh
exit 0
SH
cat > "$T/fakeroot/tools/calibrate_edge_window.sh" <<'SH'
#!/bin/sh
set -eu
feed=$1; right=$3; edge=$4; out=$7
mkdir -p "$out"
printf '%s\n' "$edge" >> "${AV9_TEST_CALL_LOG:?}"
header='id\tfeed\tleft_file\tright_file\tedge_serial\tkind\testimator\tbundle_id\tindependent_group\tvalue_samples\tscore\tsource_family\ttdoa_change_samples\ttdoa_known\tnote'
case "$edge" in
  101)
    printf '%b\n' "$header" > "$out/source_path_evidence.tsv"
    printf 'EV101\t%s\tL\t%s\t%s\tSOURCE_PATH\tDIRECT\tB101\tG101\t-3\t1\tF101\t0\t1\ttest\n' "$feed" "$right" "$edge" >> "$out/source_path_evidence.tsv"
    exit 0 ;;
  102)
    printf 'status\tFAILED\nreason\tCALIBRATION_COMPLEXITY_EXCEEDED\nexit_code\t168\n' > "$out/FAILED.tsv"
    exit 168 ;;
  103)
    printf '%b\n' "$header" > "$out/source_path_evidence.tsv"
    printf 'EV103\t%s\tL\t%s\t%s\tSOURCE_PATH\tREFINED\tB103\tG103\t2\t1\tF103\t0\t1\ttest\n' "$feed" "$right" "$edge" >> "$out/source_path_evidence.tsv"
    exit 0 ;;
  201)
    printf 'status\tFAILED\nreason\tCALIBRATION_ACOUSTIC_FAILED\nexit_code\t42\n' > "$out/FAILED.tsv"
    exit 42 ;;
  202)
    printf '%b\n' "$header" > "$out/source_path_evidence.tsv"
    exit 0 ;;
esac
exit 99
SH
chmod +x "$T/fakeroot/tools/"*.sh

cat > "$T/plan.tsv" <<'EOF_PLAN'
worker	edge_index	feed	left_file	right_file	edge_serial	window_start_serial	window_end_serial	other_feed_edge_nearby	purpose
w1	1	fc	L1	R1	101	93	109	0	SOURCE_CONDITIONED_SEAM_AND_TDOA
w1	2	fc	L2	R2	102	94	110	0	SOURCE_CONDITIONED_SEAM_AND_TDOA
w1	3	fd	L3	R3	103	95	111	0	SOURCE_CONDITIONED_SEAM_AND_TDOA
EOF_PLAN
: > "$T/calls.log"
AV9_TEST_CALL_LOG="$T/calls.log" "$T/fakeroot/tools/run_source_conditioned_calibration_worker.sh" w1 "$T/plan.tsv" "$T/corpus" "$T/out/w1" 3 > "$T/w1.log"
[ "$(wc -l < "$T/calls.log")" -eq 3 ] || { echo 'FAIL expected all three edges to execute' >&2; exit 1; }
[ -s "$T/out/w1/edges/002/UNRESOLVED.tsv" ] || { echo 'FAIL complexity edge not governed unresolved' >&2; exit 1; }
[ -s "$T/out/w1/edges/002/COMPLEXITY_DETAIL.tsv" ] || { echo 'FAIL complexity diagnostic not preserved' >&2; exit 1; }
[ ! -e "$T/out/w1/edges/002/FAILED.tsv" ] || { echo 'FAIL governed complexity still marked FAILED' >&2; exit 1; }
grep -qx 'reason[[:space:]]CALIBRATION_COMPLEXITY_EXCEEDED' "$T/out/w1/edges/002/UNRESOLVED.tsv" || { echo 'FAIL unresolved reason' >&2; exit 1; }
grep -qx 'completed_edges[[:space:]]3' "$T/out/w1/COMPLETE.tsv" || { echo 'FAIL processed edge count' >&2; exit 1; }
grep -qx 'resolved_edges[[:space:]]2' "$T/out/w1/COMPLETE.tsv" || { echo 'FAIL resolved edge count' >&2; exit 1; }
grep -qx 'unresolved_edges[[:space:]]1' "$T/out/w1/COMPLETE.tsv" || { echo 'FAIL unresolved edge count' >&2; exit 1; }
[ "$(awk 'END{print NR-1}' "$T/out/w1/evidence/source_path_evidence.tsv")" -eq 2 ] || { echo 'FAIL evidence rollup must omit unresolved edge' >&2; exit 1; }

# Resume must not rerun completed or governed-unresolved edges.
rm -f "$T/out/w1/COMPLETE.tsv" "$T/out/w1/EVIDENCE.sha256"
: > "$T/calls.log"
AV9_TEST_CALL_LOG="$T/calls.log" "$T/fakeroot/tools/run_source_conditioned_calibration_worker.sh" w1 "$T/plan.tsv" "$T/corpus" "$T/out/w1" 3 > "$T/w1-resume.log"
[ ! -s "$T/calls.log" ] || { echo 'FAIL resume reran terminal edge outcomes' >&2; exit 1; }

# A sealed-dev9 pre-hotfix complexity FAILED marker is promoted without rerun.
cat > "$T/plan_pre.tsv" <<'EOF_PRE'
worker	edge_index	feed	left_file	right_file	edge_serial	window_start_serial	window_end_serial	other_feed_edge_nearby	purpose
wpre	1	fc	L	R	102	94	110	0	SOURCE_CONDITIONED_SEAM_AND_TDOA
EOF_PRE
mkdir -p "$T/out/wpre/edges/001"
printf 'status\tFAILED\nreason\tCALIBRATION_COMPLEXITY_EXCEEDED\nexit_code\t168\n' > "$T/out/wpre/edges/001/FAILED.tsv"
: > "$T/calls.log"
AV9_TEST_CALL_LOG="$T/calls.log" "$T/fakeroot/tools/run_source_conditioned_calibration_worker.sh" wpre "$T/plan_pre.tsv" "$T/corpus" "$T/out/wpre" 3 > "$T/wpre.log"
[ ! -s "$T/calls.log" ] || { echo 'FAIL existing complexity result rerun during promotion' >&2; exit 1; }
[ -s "$T/out/wpre/edges/001/UNRESOLVED.tsv" ] || { echo 'FAIL existing complexity result not promoted' >&2; exit 1; }

# A genuine runtime failure must still terminate the worker before the next edge.
cat > "$T/plan_fatal.tsv" <<'EOF_FATAL'
worker	edge_index	feed	left_file	right_file	edge_serial	window_start_serial	window_end_serial	other_feed_edge_nearby	purpose
wf	1	fc	L1	R1	201	193	209	0	SOURCE_CONDITIONED_SEAM_AND_TDOA
wf	2	fc	L2	R2	202	194	210	0	SOURCE_CONDITIONED_SEAM_AND_TDOA
EOF_FATAL
: > "$T/calls.log"
set +e
AV9_TEST_CALL_LOG="$T/calls.log" "$T/fakeroot/tools/run_source_conditioned_calibration_worker.sh" wf "$T/plan_fatal.tsv" "$T/corpus" "$T/out/wf" 3 > "$T/wf.log" 2>&1
rc=$?
set -e
[ "$rc" -eq 42 ] || { echo "FAIL fatal rc changed: $rc" >&2; exit 1; }
[ "$(wc -l < "$T/calls.log")" -eq 1 ] || { echo 'FAIL worker continued after genuine failure' >&2; exit 1; }
[ ! -e "$T/out/wf/COMPLETE.tsv" ] || { echo 'FAIL fatal worker marked complete' >&2; exit 1; }

echo 'PASS source-conditioned complexity continuation assertions=15'
