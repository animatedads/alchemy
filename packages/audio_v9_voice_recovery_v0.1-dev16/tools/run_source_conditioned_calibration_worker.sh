#!/bin/sh
set -eu
if [ "$#" -lt 1 ] || [ "$#" -gt 5 ]; then
  echo "usage: $0 WORKER [JOB_PLAN.tsv] [CORPUS_BASE] [OUT_DIR] [MIN_BOXES]" >&2
  exit 2
fi
worker=$1
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
PLAN=${2:-"$ROOT/run/calibration/SOURCE_CONDITIONED_JOBS.tsv"}
BASE=${3:-"$HOME/fcpaphos_originals/20231009_20231010"}
OUT=${4:-"$ROOT/run/calibration/workers/$worker"}
MIN_BOXES=${5:-3}
[ -s "$PLAN" ] || { echo "FAIL job plan missing: $PLAN" >&2; exit 2; }
mkdir -p "$OUT/edges" "$OUT/evidence"
header=$(head -1 "$PLAN")
expected=$(printf 'worker\tedge_index\tfeed\tleft_file\tright_file\tedge_serial\twindow_start_serial\twindow_end_serial\tother_feed_edge_nearby\tpurpose')
[ "$header" = "$expected" ] || { echo 'FAIL unexpected source-conditioned job-plan schema' >&2; exit 2; }
count=0
# A worker owns a job by the first field only.  All nodes have the full source corpus.
# Materialise the owned rows and redirect the loop from a file.  Do not use a
# pipeline here: POSIX shells may execute a pipeline while-loop in a subshell,
# which makes state/error handling needlessly shell-dependent.
owned="$OUT/.owned_jobs.$$.tsv"
trap 'rm -f "$owned"' EXIT HUP INT TERM
awk -F '\t' -v w="$worker" 'NR==1 || $1==w' "$PLAN" > "$owned"
assigned=$(awk 'END{print NR-1}' "$owned")
[ "$assigned" -gt 0 ] || { echo "FAIL no source-conditioned jobs assigned to worker=$worker" >&2; exit 2; }
# Expensive readiness follows identity/ownership validation, so a typo cannot
# trigger a full corpus hash before failing.
"$ROOT/tools/verify_corpus.sh" "$BASE"
"$ROOT/tools/prepare_runtime.sh" >/dev/null
{
  IFS= read -r owned_header || true
  [ "$owned_header" = "$expected" ] || { echo 'FAIL unexpected owned job-plan schema' >&2; exit 2; }
  while IFS="$(printf '\t')" read -r owner idx feed left right edge ws we nearby purpose; do
    [ -n "$owner" ] || continue
    [ "$owner" = "$worker" ] || { echo "FAIL foreign worker row owner=$owner expected=$worker" >&2; exit 2; }
    tag=$(printf '%03d' "$idx"); edir="$OUT/edges/$tag"
    if [ -s "$edir/COMPLETE.tsv" ] || [ -s "$edir/UNRESOLVED.tsv" ]; then continue; fi

    # Resume-aware governance: a previous sealed-dev9 run may already have
    # stopped this logical worker on the known bounded complexity outcome.
    # Promote only the exact fail-closed condition; every other prior/runtime
    # failure remains fatal and must not be silently converted.
    if [ -s "$edir/FAILED.tsv" ] &&
       grep -qx 'reason[[:space:]]CALIBRATION_COMPLEXITY_EXCEEDED' "$edir/FAILED.tsv" &&
       grep -qx 'exit_code[[:space:]]168' "$edir/FAILED.tsv"; then
      mv "$edir/FAILED.tsv" "$edir/COMPLEXITY_DETAIL.tsv"
      printf 'status\tUNRESOLVED\nreason\tCALIBRATION_COMPLEXITY_EXCEEDED\nexit_code\t168\nworker\t%s\nedge_index\t%s\nfeed\t%s\nright_file\t%s\nedge_serial\t%s\n' \
        "$worker" "$idx" "$feed" "$right" "$edge" > "$edir/UNRESOLVED.tsv"
      continue
    fi

    set +e
    "$ROOT/tools/calibrate_edge_window.sh" "$feed" "$left" "$right" "$edge" "$ws" "$we" "$edir" "$BASE" "$MIN_BOXES" 8
    rc=$?
    set -e
    if [ "$rc" -eq 0 ]; then
      printf 'worker\t%s\nedge_index\t%s\nfeed\t%s\nright_file\t%s\nedge_serial\t%s\n' "$worker" "$idx" "$feed" "$right" "$edge" > "$edir/COMPLETE.tsv"
      continue
    fi
    if [ "$rc" -eq 168 ] && [ -s "$edir/FAILED.tsv" ] &&
       grep -qx 'reason[[:space:]]CALIBRATION_COMPLEXITY_EXCEEDED' "$edir/FAILED.tsv" &&
       grep -qx 'exit_code[[:space:]]168' "$edir/FAILED.tsv"; then
      mv "$edir/FAILED.tsv" "$edir/COMPLEXITY_DETAIL.tsv"
      printf 'status\tUNRESOLVED\nreason\tCALIBRATION_COMPLEXITY_EXCEEDED\nexit_code\t168\nworker\t%s\nedge_index\t%s\nfeed\t%s\nright_file\t%s\nedge_serial\t%s\n' \
        "$worker" "$idx" "$feed" "$right" "$edge" > "$edir/UNRESOLVED.tsv"
      continue
    fi
    echo "FAIL edge calibration worker=$worker edge=$idx rc=$rc" >&2
    exit "$rc"
  done
} < "$owned"
rm -f "$owned"
trap - EXIT HUP INT TERM
# Deterministic worker roll-up in numeric edge order.  Governed unresolved
# edges own their seam result but contribute no clock evidence.
first=1
resolved=0
unresolved=0
processed=0
: > "$OUT/evidence/source_path_evidence.tsv"
for edir in "$OUT"/edges/[0-9][0-9][0-9]; do
  [ -d "$edir" ] || continue
  if [ -s "$edir/UNRESOLVED.tsv" ]; then
    unresolved=$((unresolved+1)); processed=$((processed+1)); continue
  fi
  [ -s "$edir/COMPLETE.tsv" ] || continue
  processed=$((processed+1)); resolved=$((resolved+1))
  f="$edir/source_path_evidence.tsv"
  [ -s "$f" ] || { echo "FAIL completed edge missing source evidence: $edir" >&2; exit 2; }
  if [ "$first" -eq 1 ]; then cat "$f" > "$OUT/evidence/source_path_evidence.tsv"; first=0; else tail -n +2 "$f" >> "$OUT/evidence/source_path_evidence.tsv"; fi
done
[ "$processed" -eq "$assigned" ] || { echo "FAIL worker roll-up incomplete worker=$worker assigned=$assigned processed=$processed resolved=$resolved unresolved=$unresolved" >&2; exit 2; }
[ "$first" -eq 0 ] || printf 'id\tfeed\tleft_file\tright_file\tedge_serial\tkind\testimator\tbundle_id\tindependent_group\tvalue_samples\tscore\tsource_family\ttdoa_change_samples\ttdoa_known\tnote\n' > "$OUT/evidence/source_path_evidence.tsv"
(cd "$OUT" && sha256sum evidence/source_path_evidence.tsv > EVIDENCE.sha256)
printf 'worker\t%s\ncompleted_edges\t%s\nresolved_edges\t%s\nunresolved_edges\t%s\n' "$worker" "$processed" "$resolved" "$unresolved" > "$OUT/COMPLETE.tsv"
echo "PASS source-conditioned worker=$worker completed_edges=$processed resolved_edges=$resolved unresolved_edges=$unresolved out=$OUT"
