#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
T="$ROOT/run/test/source_calibration_masks"; rm -rf "$T"; mkdir -p "$T"
P="$T/acoustic"; edge=63832482018; em=$((edge*1000)); ws=$((edge-10))
cat > "$P.appearances.tsv" <<'TSV'
family_id	track_id	start_ms	end_ms	members
FAMILY_1	T1	0	0	6
FAMILY_2	T2	0	0	6
FAMILY_3	T3	0	0	6
FAMILY_4	T4	0	0	6
TSV
cat > "$P.speakers.tsv" <<'TSV'
speaker_id	family_id
SPEAKER_1	FAMILY_1
SPEAKER_1	FAMILY_2
TSV
printf 'track_id\tcharacter_id\tstart_ms\tend_ms\tfeed\tband\n' > "$P.track_members.tsv"
printf 'id\tstart_ms\tend_ms\tfeed\tband\tcenter_hz\tmotion\tturn\tactive\tcoherence\tratio_db\tcrest\tlag_abs_ms\n' > "$P.characters.tsv"
for spec in 'T1 FC 5 600' 'T2 FD 6 720' 'T3 FC 8 1200' 'T4 FD 9 1320'; do
  set -- $spec; trk=$1; feed=$2; band=$3; center=$4
  for off in -4000 -3000 -2000 1000 2000 3000; do
    st=$((em+off)); en=$((st+500)); id="$feed-$trk-$off"
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$trk" "$id" "$st" "$en" "$feed" "$band" >> "$P.track_members.tsv"
    printf '%s\t%s\t%s\t%s\t%s\t%s\t1\t1\t.8\t.9\t0\t3\t10\n' "$id" "$st" "$en" "$feed" "$band" "$center" >> "$P.characters.tsv"
  done
done
"$ROOT/tools/run_rexx_pinned.sh" "$ROOT/tools/build_source_calibration_masks.rex" "$P" "$edge" "$ws" "$T/masks" 3 8 > "$T/run.log"
rows=$(awk 'END{print NR-1}' "$T/masks/groups.tsv")
[ "$rows" -eq 1 ] || { echo "FAIL expected one four-quadrant source group got=$rows" >&2; exit 1; }
awk -F '\t' 'NR==2 {if($1!="SPEAKER_1" || $2!="SPEAKER" || $3!="FAMILY_1,FAMILY_2" || $4!=3 || $5!=3 || $6!=3 || $7!=3) exit 1}' "$T/masks/groups.tsv" || { echo 'FAIL speaker-family collapse/quadrant counts' >&2; exit 1; }
[ "$(wc -l < "$T/masks/SPEAKER_1.fc.select.tsv")" -eq 7 ] || { echo 'FAIL FC mask rows' >&2; exit 1; }
[ "$(wc -l < "$T/masks/SPEAKER_1.fd.select.tsv")" -eq 7 ] || { echo 'FAIL FD mask rows' >&2; exit 1; }
echo 'PASS source calibration masks assertions=4'
