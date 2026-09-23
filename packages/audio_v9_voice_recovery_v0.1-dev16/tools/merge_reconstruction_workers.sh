#!/bin/sh
set -eu
if [ "$#" -lt 1 ] || [ "$#" -gt 3 ]; then
  echo "usage: $0 OUT.ogg [WORKERS_ROOT] [QUALITY]" >&2
  exit 2
fi
out=$1
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
WROOT=${2:-"$ROOT/run/reconstruction/workers"}
QUALITY=${3:-8}
case "$QUALITY" in ''|*[!0-9]*) echo "FAIL quality must be integer" >&2; exit 2;; esac
mkdir -p "$(dirname "$out")"
plan="$WROOT/../MERGE_PLAN.txt"
"$ROOT/tools/run_rexx_pinned.sh" "$ROOT/tools/plan_reconstruction_workers.rex" --shell > "$plan"
tmp_list="$WROOT/../MERGE_INPUTS.txt"; : > "$tmp_list"
while read -r kind worker s e expected; do
  [ "$kind" = WORKER ] || continue
  dir="$WROOT/$worker"; voice="$dir/voice.f32"; complete="$dir/COMPLETE.tsv"
  [ -s "$voice" ] && [ -s "$complete" ] && [ -s "$dir/EVIDENCE.sha256" ] || { echo "FAIL reconstruction worker incomplete: $worker" >&2; exit 2; }
  (cd "$dir" && sha256sum -c EVIDENCE.sha256 >/dev/null) || { echo "FAIL worker evidence hash $worker" >&2; exit 2; }
  got=$(($(stat -c %s "$voice")/4)); [ "$got" -eq "$expected" ] || { echo "FAIL worker sample count $worker expected=$expected got=$got" >&2; exit 2; }
  printf '%s\n' "$voice" >> "$tmp_list"
done < "$plan"
# The canonical campaign is exactly 18 h at 8 kHz = 518,400,000 samples.
sum=0
while IFS= read -r f; do sum=$((sum+$(($(stat -c %s "$f")/4)))); done < "$tmp_list"
[ "$sum" -eq 518400000 ] || { echo "FAIL merged campaign samples expected=518400000 got=$sum" >&2; exit 2; }
# Encode exactly once. Keeping worker outputs as f32 avoids generational codec loss.
cat $(cat "$tmp_list") | ffmpeg -nostdin -v error -f f32le -ar 8000 -ac 1 -i pipe:0 -c:a libvorbis -q:a "$QUALITY" -metadata title="Audio V9 recovered voice" -metadata comment="FCPAPHOS-20231009-VOICE-RECOVERY-01 local spatial soft fusion" -y "$out"
[ -s "$out" ] || { echo "FAIL final OGG not created" >&2; exit 2; }
report="$out.MANIFEST.tsv"
printf 'schema\taudio.v9.voice-recovery.final/1\n' > "$report"
printf 'campaign_samples\t518400000\n' >> "$report"
printf 'sample_rate\t8000\n' >> "$report"
printf 'duration_seconds\t64800\n' >> "$report"
printf 'source_mode\tLOCAL_SPATIAL_SOFT_FUSION\n' >> "$report"
printf 'ogg_sha256\t%s\n' "$(sha256sum "$out" | awk '{print $1}')" >> "$report"
echo "PASS final reconstruction samples=518400000 seconds=64800 out=$out"
