#!/bin/sh
set -eu
if [ "$#" -lt 1 ] || [ "$#" -gt 4 ]; then
  echo "usage: $0 LOGICAL_WORKER [CORPUS_BASE] [OUT_DIR] [CHUNK_SECONDS]" >&2
  exit 2
fi
worker=$1
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
BASE=${2:-"$HOME/fcpaphos_originals/20231009_20231010"}
OUT=${3:-"$ROOT/run/reconstruction/workers/$worker"}
CHUNK=${4:-60}
case "$CHUNK" in ''|*[!0-9]*) echo "FAIL chunk seconds must be integer" >&2; exit 2;; esac
[ "$CHUNK" -ge 16 ] || { echo "FAIL chunk seconds must be >=16" >&2; exit 2; }
mkdir -p "$OUT/parts" "$OUT/chunks"
"$ROOT/tools/verify_corpus.sh" "$BASE"
"$ROOT/tools/prepare_runtime.sh" >/dev/null
plan="$OUT/chunks.tsv"
"$ROOT/tools/run_rexx_pinned.sh" "$ROOT/tools/plan_worker_chunks.rex" "$worker" "$CHUNK" > "$plan"
# Determine exact logical core interval from the campaign worker table.
core_line=$("$ROOT/tools/run_rexx_pinned.sh" "$ROOT/tools/plan_reconstruction_workers.rex" | awk -F '\t' -v w="$worker" '$1==w {print $0}')
[ -n "$core_line" ] || { echo "FAIL logical worker not found: $worker" >&2; exit 2; }
core_start=$(printf '%s\n' "$core_line" | awk -F '\t' '{print $2}')
core_end=$(printf '%s\n' "$core_line" | awk -F '\t' '{print $3}')
expected_total=$(printf '%s\n' "$core_line" | awk -F '\t' '{print $4}')
printf 'schema\taudio.v9.voice-recovery.reconstruction-worker/1\n' > "$OUT/WORKER.tsv"
printf 'worker\t%s\n' "$worker" >> "$OUT/WORKER.tsv"
printf 'core_start_serial\t%s\n' "$core_start" >> "$OUT/WORKER.tsv"
printf 'core_end_serial\t%s\n' "$core_end" >> "$OUT/WORKER.tsv"
printf 'expected_samples\t%s\n' "$expected_total" >> "$OUT/WORKER.tsv"
printf 'mode\tLOCAL_SPATIAL_SOFT_FUSION\n' >> "$OUT/WORKER.tsv"
printf 'halo_seconds\t4\n' >> "$OUT/WORKER.tsv"
printf 'scan_window_ms\t8000\nscan_step_ms\t2000\n' >> "$OUT/WORKER.tsv"
: > "$OUT/PARTS.tsv"
printf 'part\towned_start_serial\towned_end_serial\tsamples\tsha256\n' >> "$OUT/PARTS.tsv"
part_count=0
sum_samples=0
# Process only intervals that intersect the logical core. Four seconds on each side
# are analysis context and are always cropped away before a part becomes authoritative.
tail -n +2 "$plan" | while IFS="$(printf '\t')" read -r idx start end analysis_start analysis_end ignored_core_start ignored_core_end; do
  owned_start=$start; [ "$owned_start" -lt "$core_start" ] && owned_start=$core_start
  owned_end=$end; [ "$owned_end" -gt "$core_end" ] && owned_end=$core_end
  [ "$owned_end" -gt "$owned_start" ] || continue
  tag=$(printf '%06d' "$idx")
  cdir="$OUT/chunks/$tag"; mkdir -p "$cdir"
  samples=$(((owned_end-owned_start)*8000))
  part="$OUT/parts/$tag.f32"
  # Resume is checked before any decode or analysis work.
  if [ -f "$cdir/PART.sha256" ] && [ -f "$cdir/DONE" ] && [ -f "$part" ] && \
     [ "$(($(stat -c %s "$part")/4))" -eq "$samples" ] && (cd "$cdir" && sha256sum -c PART.sha256 >/dev/null 2>&1); then
    sha=$(sha256sum "$part" | awk '{print $1}')
    printf '%s\t%s\t%s\t%s\t%s\n' "$tag" "$owned_start" "$owned_end" "$samples" "$sha" >> "$OUT/PARTS.tsv"
    echo "PASS reconstruction resume worker=$worker chunk=$idx owned=$owned_start..$owned_end samples=$samples"
    continue
  fi
  rm -f "$part" "$cdir/DONE" "$cdir/PART.sha256"
  decode_start=$((owned_start-4)); decode_end=$((owned_end+4))
  fc="$cdir/fc.f32"; fd="$cdir/fd.f32"
  "$ROOT/tools/decode_serial_interval.sh" fc "$decode_start" "$decode_end" "$fc" "$BASE" >/dev/null
  "$ROOT/tools/decode_serial_interval.sh" fd "$decode_start" "$decode_end" "$fd" "$BASE" >/dev/null
  rendered="$cdir/rendered.f32"; rplan="$cdir/reconstruction.tsv"
  "$ROOT/tools/run_rexx_pinned.sh" "$ROOT/tools/render_reconstruction_chunk.rex" "$fc" "$fd" "$rendered" "$rplan" >/dev/null
  dd if="$rendered" of="$part" bs=4 skip=32000 count="$samples" status=none
  got=$(($(stat -c %s "$part")/4))
  [ "$got" -eq "$samples" ] || { echo "FAIL owned crop geometry worker=$worker chunk=$idx expected=$samples got=$got" >&2; exit 2; }
  sha=$(sha256sum "$part" | awk '{print $1}')
  printf '%s\t%s\t%s\t%s\t%s\n' "$tag" "$owned_start" "$owned_end" "$samples" "$sha" >> "$OUT/PARTS.tsv"
  (cd "$cdir" && sha256sum reconstruction.tsv fc.f32.decode.tsv fd.f32.decode.tsv > EVIDENCE.sha256)
  (cd "$cdir" && sha256sum "../../parts/$tag.f32" > PART.sha256)
  : > "$cdir/DONE"
  rm -f "$fc" "$fd" "$rendered"
  echo "PASS reconstruction worker=$worker chunk=$idx owned=$owned_start..$owned_end samples=$samples"
done
# Validate authoritative parts after the subshell loop completes.
prev=$core_start
sum=0
while IFS="$(printf '\t')" read -r tag s e n sha; do
  [ "$tag" = part ] && continue
  [ "$s" -eq "$prev" ] || { echo "FAIL reconstruction part gap/overlap worker=$worker expected_start=$prev got=$s" >&2; exit 2; }
  f="$OUT/parts/$tag.f32"; [ -s "$f" ] || { echo "FAIL reconstruction part missing: $f" >&2; exit 2; }
  [ "$(sha256sum "$f" | awk '{print $1}')" = "$sha" ] || { echo "FAIL reconstruction part hash: $f" >&2; exit 2; }
  [ "$(($(stat -c %s "$f")/4))" -eq "$n" ] || { echo "FAIL reconstruction part sample count: $f" >&2; exit 2; }
  sum=$((sum+n)); prev=$e
done < "$OUT/PARTS.tsv"
[ "$prev" -eq "$core_end" ] || { echo "FAIL reconstruction worker does not reach core end worker=$worker end=$prev expected=$core_end" >&2; exit 2; }
[ "$sum" -eq "$expected_total" ] || { echo "FAIL reconstruction worker sample total worker=$worker got=$sum expected=$expected_total" >&2; exit 2; }
voice="$OUT/voice.f32"
: > "$voice"
for f in "$OUT"/parts/*.f32; do cat "$f" >> "$voice"; done
[ "$(($(stat -c %s "$voice")/4))" -eq "$expected_total" ] || { echo "FAIL worker voice geometry" >&2; exit 2; }
(cd "$OUT" && sha256sum voice.f32 PARTS.tsv > EVIDENCE.sha256)
printf 'status\tCOMPLETE\nworker\t%s\nsamples\t%s\nsha256\t%s\n' "$worker" "$expected_total" "$(sha256sum "$voice" | awk '{print $1}')" > "$OUT/COMPLETE.tsv"
echo "PASS reconstruction worker complete worker=$worker samples=$expected_total out=$voice"
