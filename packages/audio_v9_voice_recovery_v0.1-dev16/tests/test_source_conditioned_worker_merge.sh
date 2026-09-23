#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
T="$ROOT/run/test/source_conditioned_worker_merge"
rm -rf "$T"; mkdir -p "$T/workers"
header='id\tfeed\tleft_file\tright_file\tedge_serial\tkind\testimator\tbundle_id\tindependent_group\tvalue_samples\tscore\tsource_family\ttdoa_change_samples\ttdoa_known\tnote'
i=0
for worker in ed209a ed209b ed209c ed209d ed209e ed209h ed209i; do
  i=$((i+1)); wd="$T/workers/$worker"; d="$wd/evidence"; mkdir -p "$d"
  printf '%b\n' "$header" > "$d/source_path_evidence.tsv"
  printf 'EV%02d\tfc\tL\tR\t%d\tSOURCE_PATH\tDIRECT\tB%02d\tG%02d\t-3\t0.9\tF%02d\t0\t1\ttest\n' "$i" "$i" "$i" "$i" "$i" >> "$d/source_path_evidence.tsv"
  printf 'worker\t%s\ncompleted_edges\t1\n' "$worker" > "$wd/COMPLETE.tsv"
  (cd "$wd" && sha256sum evidence/source_path_evidence.tsv > EVIDENCE.sha256)
done
"$ROOT/tools/merge_source_conditioned_workers.sh" "$T/workers" "$T/merged.tsv" "$T/merged.sha256" > "$T/run.log"
rows=$(awk 'END{print NR-1}' "$T/merged.tsv")
[ "$rows" -eq 7 ] || { echo "FAIL merge rows=$rows" >&2; exit 1; }
order=$(awk -F '\t' 'NR>1{printf "%s%s",sep,$1; sep=","}END{print ""}' "$T/merged.tsv")
[ "$order" = 'EV01,EV02,EV03,EV04,EV05,EV06,EV07' ] || { echo "FAIL merge order=$order" >&2; exit 1; }
sha256sum --check "$T/merged.sha256" >/dev/null || { echo 'FAIL merge manifest' >&2; exit 1; }
rm "$T/workers/ed209h/evidence/source_path_evidence.tsv"
if "$ROOT/tools/merge_source_conditioned_workers.sh" "$T/workers" "$T/should_fail.tsv" >/dev/null 2>&1; then
  echo 'FAIL missing-worker evidence accepted' >&2; exit 1
fi
# Recreate evidence but corrupt its hash authority: merger must still fail closed.
wd="$T/workers/ed209h"; mkdir -p "$wd/evidence"; printf '%b\n' "$header" > "$wd/evidence/source_path_evidence.tsv"
printf 'BAD\tfc\tL\tR\t1\tSOURCE_PATH\tDIRECT\tB\tG\t0\t1\tF\t0\t1\ttest\n' >> "$wd/evidence/source_path_evidence.tsv"
printf '0000000000000000000000000000000000000000000000000000000000000000  evidence/source_path_evidence.tsv\n' > "$wd/EVIDENCE.sha256"
if "$ROOT/tools/merge_source_conditioned_workers.sh" "$T/workers" "$T/should_fail_hash.tsv" >/dev/null 2>&1; then
  echo 'FAIL corrupted worker evidence accepted' >&2; exit 1
fi
echo 'PASS source-conditioned worker merge assertions=5'
