#!/usr/bin/env bash
set -euo pipefail
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
MANIFEST="$ROOT/SAMPLES.sha256"
MASK="$ROOT/exclusions/campaign0945_cctv_alarm_source_master.tsv"
SRC="$ROOT/campaign_audio/campaign0945_source_094030_094930.wav"
CMP="$ROOT/campaign_audio/campaign0945_companion_094015_094945.wav"
PARENT_SRC="$ROOT/sample/campaign0945_source_094330_094630.wav"
PARENT_CMP="$ROOT/alignment_reference/campaign0945_companion_094315_094645.wav"
REQUIRE_MATCH=${CCTV_ALARM_REQUIRE_MATCH:-1}

command -v sha256sum >/dev/null 2>&1 || { echo 'FAIL: sha256sum required on controller' >&2; exit 2; }
command -v ffprobe >/dev/null 2>&1 || { echo 'FAIL: ffprobe required on controller' >&2; exit 2; }
[[ -s "$MANIFEST" ]] || { echo 'FAIL: SAMPLES.sha256 missing; run prepare_samples.sh first' >&2; exit 4; }

# A prepared fixture is an immutable controller input.  Refuse stale/tampered
# WAV/TSV material before any node is contacted.
(cd "$ROOT" && sha256sum -c SAMPLES.sha256 >/dev/null) || {
  echo 'FAIL: prepared campaign SHA-256 verification failed; rerun prepare_samples.sh' >&2
  exit 5
}

check_samples() {
  local file=$1 seconds=$2 label=$3 got want
  [[ -s "$file" ]] || { echo "FAIL: missing prepared $label: $file" >&2; exit 4; }
  got=$(ffprobe -v error -select_streams a:0 -show_entries stream=duration_ts -of default=nw=1:nk=1 "$file")
  want=$(awk -v sec="$seconds" 'BEGIN{printf "%.0f",sec*16000}')
  [[ "$got" == "$want" ]] || { echo "FAIL: $label samples=$got expected=$want" >&2; exit 5; }
}
check_samples "$SRC" 540 source-master
check_samples "$CMP" 570 companion-master
check_samples "$PARENT_SRC" 180 parent-source
check_samples "$PARENT_CMP" 210 parent-companion
check_samples "$ROOT/reference/prepared/quality_target_01_whatsapp_16k_mono_pcm16.wav" 46.5 quality-target-1
check_samples "$ROOT/reference/prepared/quality_target_02_upspeak_16k_mono_pcm16.wav" 56.81925 quality-target-2
check_samples "$ROOT/reference/prepared/quality_target_03_quiet_voice_16k_mono_pcm16.wav" 48 quality-target-3
check_samples "$ROOT/reference/prepared/quality_target_04_high_register_16k_mono_pcm16.wav" 48 quality-target-4

CORPUS="$ROOT/reference/QUALITY_CORPUS.tsv"
[[ -s "$CORPUS" ]] || { echo 'FAIL: quality corpus manifest missing' >&2; exit 5; }
grep -qx '# audio.quality.corpus/2' "$CORPUS" || { echo 'FAIL: quality corpus schema mismatch' >&2; exit 5; }
mapfile -t corpus_paths < <(awk -F '\t' '!/^#/ && NF {print $1}' "$CORPUS")
(( ${#corpus_paths[@]} == 4 )) || { echo "FAIL: expected 4 V2 quality references, got ${#corpus_paths[@]}" >&2; exit 5; }
declare -A corpus_hash_seen=()
for rel in "${corpus_paths[@]}"; do
  [[ "$rel" == prepared/* && "$rel" != *..* && "$rel" != /* ]] || { echo "FAIL: unsafe quality corpus path $rel" >&2; exit 5; }
  q="$ROOT/reference/$rel"; [[ -s "$q" ]] || { echo "FAIL: missing quality corpus reference $rel" >&2; exit 5; }
  h=$(sha256sum "$q" | awk '{print $1}')
  [[ -z "${corpus_hash_seen[$h]:-}" ]] || { echo "FAIL: duplicate prepared quality reference hash $h ($rel and ${corpus_hash_seen[$h]})" >&2; exit 5; }
  corpus_hash_seen[$h]="$rel"
done

[[ -s "$MASK" ]] || { echo 'FAIL: CCTV alarm exclusion manifest missing' >&2; exit 5; }
grep -qx '# schema=cctv.alarm.exclusion/1' "$MASK" || { echo 'FAIL: CCTV alarm exclusion schema mismatch' >&2; exit 5; }
grep -qx $'start_sec\tend_sec\treason\tprovenance\thot_frames\tpeak_dbfs_max\trms_dbfs_max' "$MASK" || {
  echo 'FAIL: CCTV alarm exclusion manifest header mismatch' >&2; exit 5;
}
# Validate finite ordered source-local intervals within the exact 540 s primary
# master and refuse overlap/backtracking.  A known campaign alarm is mandatory
# by default; CCTV_ALARM_REQUIRE_MATCH=0 is an explicit diagnostic override only.
count_file=$(mktemp); trap 'rm -f "$count_file"' EXIT
awk -F '\t' '
  BEGIN{prev=-1; n=0}
  /^#/ || $1=="start_sec" {next}
  NF!=7 {exit 10}
  $3!="cctv_alarm" {exit 11}
  $1!~/^[0-9]+([.][0-9]+)?$/ || $2!~/^[0-9]+([.][0-9]+)?$/ {exit 12}
  {s=$1+0; e=$2+0; if(!(s>=0 && e>s && e<=540)) exit 13; if(prev>=0 && s<prev) exit 14; prev=e; n++}
  END{print n+0}
' "$MASK" > "$count_file" || {
  rc=$?; rm -f "$count_file"; echo "FAIL: invalid CCTV alarm exclusion manifest rc=$rc" >&2; exit 5;
}
intervals=$(cat "$count_file"); rm -f "$count_file"; trap - EXIT
if [[ "$REQUIRE_MATCH" == 1 && "$intervals" -lt 1 ]]; then
  echo 'FAIL: CCTV-ALARM-EXCLUSION-V1 required but detector produced zero intervals' >&2
  exit 6
fi

# Parent-local provenance manifests are derived from the source mask. Recompute
# them and compare byte-for-byte so a stale projection cannot survive while the
# master mask itself remains valid.
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
awk -F '\t' 'BEGIN{OFS="\t"} /^#/ {next} $1=="start_sec" {print;next} {s=$1-180;e=$2-180;if(e<=0||s>=180)next;if(s<0)s=0;if(e>180)e=180;$1=s;$2=e;print}' "$MASK" > "$tmp/source.tsv"
awk -F '\t' 'BEGIN{OFS="\t"} /^#/ {next} $1=="start_sec" {print;next} {s=$1+15-180;e=$2+15-180;if(e<=0||s>=210)next;if(s<0)s=0;if(e>210)e=210;$1=s;$2=e;print}' "$MASK" > "$tmp/companion.tsv"
cmp -s "$tmp/source.tsv" "$ROOT/exclusions/campaign0945_parent_source.tsv" || { echo 'FAIL: parent-source exclusion projection is stale/inconsistent' >&2; exit 5; }
cmp -s "$tmp/companion.tsv" "$ROOT/exclusions/campaign0945_parent_companion.tsv" || { echo 'FAIL: parent-companion exclusion projection is stale/inconsistent' >&2; exit 5; }

echo "PASS verified prepared 09:45 campaign hashes/samples/exclusions intervals=$intervals"
