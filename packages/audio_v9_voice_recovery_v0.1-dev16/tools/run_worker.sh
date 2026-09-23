#!/bin/sh
set -eu
if [ "$#" -lt 1 ] || [ "$#" -gt 4 ]; then
  echo "usage: $0 WORKER [CORPUS_BASE] [OUT_DIR] [spatial|quality|full]" >&2
  exit 2
fi
worker=$1
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
BASE=${2:-"$HOME/fcpaphos_originals/20231009_20231010"}
OUT=${3:-"$ROOT/run/workers/$worker"}
STAGE=${4:-${AV9_WORKER_STAGE:-spatial}}
case "$STAGE" in
  spatial|quality|full) ;;
  *) echo "FAIL stage must be spatial, quality or full: $STAGE" >&2; exit 2 ;;
esac
mkdir -p "$OUT/chunks" "$OUT/evidence"
"$ROOT/tools/verify_corpus.sh" "$BASE"
"$ROOT/tools/prepare_runtime.sh" >/dev/null
plan="$OUT/chunks.tsv"
"$ROOT/tools/run_rexx_pinned.sh" "$ROOT/tools/plan_worker_chunks.rex" "$worker" 60 > "$plan"
printf 'worker\t%s\n' "$worker" > "$OUT/WORKER.meta.tsv"
printf 'corpus_base\t%s\n' "$BASE" >> "$OUT/WORKER.meta.tsv"
printf 'stage\t%s\n' "$STAGE" >> "$OUT/WORKER.meta.tsv"
printf 'manifest_sha256\t%s\n' "$(sha256sum "$ROOT/MANIFEST.sha256" 2>/dev/null | awk '{print $1}' || printf 'UNSEALED')" >> "$OUT/WORKER.meta.tsv"
printf 'corpus_authority_sha256\t%s\n' "$(sha256sum "$ROOT/campaign/FCPAPHOS_ORIGINALS_SHA256SUMS" | awk '{print $1}')" >> "$OUT/WORKER.meta.tsv"
# Preserve all per-minute evidence. Final semantic merge is coordinator-owned.
tail -n +2 "$plan" | while IFS="$(printf '\t')" read -r idx start end analysis_start analysis_end core_start core_end; do
  tag=$(printf '%06d' "$idx")
  chunk="$OUT/chunks/$tag"; mkdir -p "$chunk"
  fc="$chunk/fc.f32"; fd="$chunk/fd.f32"
  decode_end=$((end+4))
  [ -s "$fc" ] || "$ROOT/tools/decode_serial_interval.sh" fc "$start" "$decode_end" "$fc" "$BASE" >/dev/null
  [ -s "$fd" ] || "$ROOT/tools/decode_serial_interval.sh" fd "$start" "$decode_end" "$fd" "$BASE" >/dev/null
  spatial="$chunk/spatial.tsv"
  "$ROOT/tools/run_rexx_pinned.sh" "$ROOT/tools/scan_chunk.rex" "$fc" "$fd" "$start" "$core_start" "$core_end" "$spatial" 60000 >/dev/null
  evidence_files="$spatial $fc.decode.tsv $fd.decode.tsv"
  if [ "$STAGE" = quality ] || [ "$STAGE" = full ]; then
    acoustic="$chunk/acoustic"
    "$ROOT/tools/run_rexx_pinned.sh" "$ROOT/tools/analyze_acoustic_chunk.rex" "$fc" "$fd" "$start" "$acoustic" "$worker:$tag" >/dev/null
    qf32="$chunk/quality.f32"; qplan="$chunk/reconstruction.tsv"; qmask="$acoustic.tf_mask.tsv"; qogg="$chunk/quality_preview.ogg"
    "$ROOT/tools/run_rexx_pinned.sh" "$ROOT/tools/render_quality_chunk.rex" "$fc" "$fd" "$qf32" "$qplan" "$qmask" >/dev/null
    ffmpeg -nostdin -v error -f f32le -ar 8000 -ac 1 -i "$qf32" -t 60 -c:a libvorbis -q:a 8 -y "$qogg"
    evidence_files="$evidence_files $qplan $qmask $acoustic.characters.tsv $acoustic.tracks.tsv $acoustic.track_members.tsv $acoustic.families.tsv $acoustic.appearances.tsv $acoustic.speakers.tsv $acoustic.graph_edges.tsv $acoustic.graph_paths.tsv $acoustic.graph_wobble.tsv"
    if [ -s "$acoustic.graphs.tsv" ]; then evidence_files="$evidence_files $acoustic.graphs.tsv"; fi
    if [ "${AV9_KEEP_QUALITY_F32:-0}" != 1 ]; then rm -f "$qf32"; fi
  fi
  if [ "$STAGE" = full ]; then
    "$ROOT/tools/run_rexx_pinned.sh" "$ROOT/tools/analyze_spectral_chunk.rex" fc "$fc" "$start" "$core_start" "$core_end" "$chunk/fc" 60000 >/dev/null
    "$ROOT/tools/run_rexx_pinned.sh" "$ROOT/tools/analyze_spectral_chunk.rex" fd "$fd" "$start" "$core_start" "$core_end" "$chunk/fd" 60000 >/dev/null
    evidence_files="$evidence_files $chunk/fc.segments.tsv $chunk/fc.boxes.tsv $chunk/fd.segments.tsv $chunk/fd.boxes.tsv"
  fi
  sha256sum $evidence_files > "$chunk/EVIDENCE.sha256"
  rm -f "$fc" "$fd"
  echo "PASS worker=$worker chunk=$idx start=$start end=$end"
done
# Deterministic roll-up: lexical chunk order and file-local order.
{
  first=1
  for f in "$OUT"/chunks/*/spatial.tsv; do
    if [ "$first" -eq 1 ]; then cat "$f"; first=0; else tail -n +3 "$f"; fi
  done
} > "$OUT/evidence/spatial.tsv"
if [ "$STAGE" = full ]; then
  for kind in fc.segments fc.boxes fd.segments fd.boxes; do
    : > "$OUT/evidence/$kind.tsv"; first=1
    for f in "$OUT"/chunks/*/$kind.tsv; do
      if [ "$first" -eq 1 ]; then cat "$f" > "$OUT/evidence/$kind.tsv"; first=0; else tail -n +2 "$f" >> "$OUT/evidence/$kind.tsv"; fi
    done
  done
fi
sha256sum "$OUT/evidence"/*.tsv > "$OUT/EVIDENCE.sha256"
echo "PASS worker complete worker=$worker stage=$STAGE out=$OUT"
