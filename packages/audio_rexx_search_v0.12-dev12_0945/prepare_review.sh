#!/usr/bin/env bash
set -euo pipefail
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
COLLECTED=${1:-$ROOT/collected_results}
OUT=${2:-$COLLECTED/review}
PAIR_COUNT=${PAIR_COUNT:-20}
mkdir -p "$OUT"
CAT="$OUT/review_candidates.tsv"
TMP="$OUT/.candidates.tmp"
: > "$TMP"
found=0
for f in "$COLLECTED"/ed209*/review_candidates.tsv; do
  [[ -f "$f" ]] || continue
  found=1
  node=$(basename "$(dirname "$f")")
  awk -F '\t' -v OFS='\t' -v n="$node" 'NR==1{next} { $5=n "/" $5; print }' "$f" >> "$TMP"
done
(( found == 1 )) || { echo "FAIL: no review_candidates.tsv under $COLLECTED" >&2; rm -f "$TMP"; exit 2; }
printf 'candidate_id\tlane_id\trank\tscore\tmaterial_ref\tpcm_hash64\tobjective_id\tchain\n' > "$CAT"
sort -t $'\t' -k4,4g -k1,1 "$TMP" >> "$CAT"
rm -f "$TMP"

PAIRS="$OUT/review_pairs.tsv"
printf 'pair_id\tleft_candidate_id\tright_candidate_id\tleft_material_ref\tright_material_ref\n' > "$PAIRS"
tail -n +2 "$CAT" | awk -F '\t' -v OFS='\t' -v limit="$PAIR_COUNT" '
  { id[NR]=$1; material[NR]=$5 }
  END {
    n=NR; p=0
    for(i=1;i<n && p<limit;i+=2){p++; printf "PAIR-%03d\t%s\t%s\t%s\t%s\n",p,id[i],id[i+1],material[i],material[i+1]}
    for(i=1;i<=int(n/2) && p<limit;i++){j=n-i+1; if(i==j) continue; p++; printf "PAIR-%03d\t%s\t%s\t%s\t%s\n",p,id[i],id[j],material[i],material[j]}
  }
' >> "$PAIRS"

J="$OUT/judgements.tsv"
printf 'judgement_id\treviewer_id\tleft_candidate_id\tright_candidate_id\tpreference\tconfidence\trationale\tevidence_ref\n' > "$J"
tail -n +2 "$PAIRS" | awk -F '\t' -v OFS='\t' '{print $1,"",$2,$3,"","","",""}' >> "$J"
cat > "$OUT/README.txt" <<EOF
Blind pairwise review workspace.

1. Listen to left_material_ref and right_material_ref from review_pairs.tsv without consulting review_candidates.tsv scores.
2. Fill reviewer_id, preference (LEFT|RIGHT|TIE|UNDECIDABLE), confidence, rationale and evidence_ref in judgements.tsv.
3. Run:
   /usr/local/bin/rexx $ROOT/bin/AudioObjectiveCalibration.rex $CAT $J $OUT/calibration

Default qualification policy is >=5 comparable judgements and >=0.70 objective/human agreement.
The current 18/40 artefact penalty weights remain experimental until this evidence passes an explicit policy.
EOF
printf 'PREPARED review candidates=%s pairs=%s out=%s\n' "$(( $(wc -l < "$CAT") - 1 ))" "$(( $(wc -l < "$PAIRS") - 1 ))" "$OUT"
