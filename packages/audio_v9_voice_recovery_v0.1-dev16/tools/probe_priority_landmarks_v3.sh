#!/bin/sh
set -eu
if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
  echo 'usage: probe_priority_landmarks_v3.sh OUT_ROOT [CORPUS_BASE]' >&2
  exit 2
fi
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
OUT=$1; BASE=${2:-"$HOME/fcpaphos_originals/20231009_20231010"}
mkdir -p "$OUT"
INDEX="$OUT/LANDMARK_PROBE_INDEX.tsv"
printf 'landmark_id\tout_dir\tstatus\n' > "$INDEX"
for ID in LMK-20231010-041646400-CALIBRATION LMK-20231010-FC-071312-PHONE; do
  DIR="$OUT/$ID"
  "$ROOT/tools/probe_search_landmark.sh" "$ID" "$DIR" "$BASE"
  printf '%s\t%s\tPASS\n' "$ID" "$DIR" >> "$INDEX"
done
find "$OUT" -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum > "$OUT/SHA256SUMS"
echo "PASS priority landmark v3 probes out=$OUT"
