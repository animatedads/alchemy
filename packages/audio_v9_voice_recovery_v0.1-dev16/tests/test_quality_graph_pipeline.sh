#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
T="$ROOT/run/test/quality_graph_pipeline"
rm -rf "$T"; mkdir -p "$T"
fc="$T/fc.f32"; fd="$T/fd.f32"; p="$T/acoustic"
"$ROOT/native/make_spatial_fixture" "$fc" "$fd" 8000 12 960
rm -f "$p.graphs.tsv"
"$ROOT/tools/run_rexx_pinned.sh" "$ROOT/tools/analyze_acoustic_chunk.rex" "$fc" "$fd" 63832500000 "$p" TEST:QUALITY_GRAPH >/dev/null
for f in "$p.characters.tsv" "$p.graph_edges.tsv" "$p.graph_paths.tsv" "$p.graph_wobble.tsv" "$p.tf_mask.tsv"; do
  [ -s "$f" ] || { echo "FAIL missing graph evidence $f" >&2; exit 1; }
done
[ ! -e "$p.graphs.tsv" ] || { echo 'FAIL graph archive written by default' >&2; exit 1; }
# Topology-only worker evidence must not fabricate ML difference scores.
awk -F '\t' 'NR>1 {if ($8 != -1) {print "FAIL topology relation has computed pattern_total",$1,$8; exit 1}}' "$p.graph_edges.tsv"
# Reconstruction rows must retain originating box identity.
awk -F '\t' 'NR>1 {n++; if (NF < 11 || $11 == "") {print "FAIL mask missing character provenance",NR; exit 1}} END {if(n<1) exit 1}' "$p.tf_mask.tsv"
sha256sum "$p.characters.tsv" "$p.graph_edges.tsv" "$p.graph_paths.tsv" "$p.graph_wobble.tsv" "$p.tf_mask.tsv" > "$T/evidence.before.sha256"
window_start=63832500000000
window_end=63832500002000
"$ROOT/tools/run_rexx_pinned.sh" "$ROOT/tools/render_quality_graphs.rex" "$p" "$T/view1" "$T/replay.graphs.tsv" "$window_start" "$window_end" >/dev/null
"$ROOT/tools/run_rexx_pinned.sh" "$ROOT/tools/render_quality_graphs.rex" "$p" "$T/view2" - "$window_start" "$window_end" >/dev/null
for view in field relations delay reconstruction; do
  a="$T/view1.$view.svg"; b="$T/view2.$view.svg"
  [ -s "$a" ] && [ -s "$b" ] || { echo "FAIL missing SVG $view" >&2; exit 1; }
  cmp "$a" "$b" >/dev/null || { echo "FAIL non-deterministic SVG replay $view" >&2; exit 1; }
done
[ -s "$T/replay.graphs.tsv" ] || { echo 'FAIL optional graph archive missing' >&2; exit 1; }
sha256sum -c "$T/evidence.before.sha256" >/dev/null || { echo 'FAIL presentation mutated semantic evidence' >&2; exit 1; }
edges=$(awk 'END{print NR-1}' "$p.graph_edges.tsv")
chars=$(awk 'END{print NR-1}' "$p.characters.tsv")
masks=$(awk 'END{print NR-1}' "$p.tf_mask.tsv")
printf 'PASS quality graph pipeline characters=%s edges=%s masks=%s replay=deterministic\n' "$chars" "$edges" "$masks"
