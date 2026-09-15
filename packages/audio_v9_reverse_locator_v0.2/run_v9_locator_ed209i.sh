#!/usr/bin/env bash
set -euo pipefail

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
MODE=${1:-all}
case "$MODE" in
  all|--seed-only|--index-only|--salvage-v1) ;;
  *) echo "usage: $0 [--seed-only|--index-only|--salvage-v1]" >&2; exit 2 ;;
esac
PYTHON=${PYTHON:-python3}
SNIPPETS=${V9_SNIPPETS:-"$HOME/fcpaphos_project_v9_snippets"}
ORIGINALS=${V9_ORIGINALS:-"$HOME/fcpaphos_originals/20231009_20231010"}
OUT=${V9_LOCATOR_OUT:-"$ROOT/run/v9_locator"}
INDEX=${V9_LOCATOR_INDEX:-"$OUT/v9_originals_landmarks.v9idx"}
V1_INDEX=${V9_LOCATOR_V1_SQLITE:-"$HOME/audio_v9_reverse_locator_v0.1/run/v9_locator/v9_originals_landmarks.sqlite"}
if [[ ! -f "$V1_INDEX" && -f "$OUT/v9_originals_landmarks.sqlite" ]]; then
  V1_INDEX="$OUT/v9_originals_landmarks.sqlite"
fi
GENERATIONS=${V9_GENERATIONS:-"$ROOT/reference/V9_SNIPPET_GENERATIONS.tsv"}
EVENTS=${V9_EVENTS:-"$ROOT/reference/V9_GEN3_EVENTS.jsonl"}

mkdir -p "$OUT"

for d in \
  "$SNIPPETS/single_feed" \
  "$SNIPPETS/dual_feed" \
  "$ORIGINALS/camera_fc" \
  "$ORIGINALS/camera_fd"
do
  test -d "$d" || { echo "REFUSE: required directory missing: $d" >&2; exit 3; }
done

command -v ffmpeg >/dev/null || { echo 'REFUSE: ffmpeg not found' >&2; exit 3; }
command -v ffprobe >/dev/null || { echo 'REFUSE: ffprobe not found' >&2; exit 3; }
"$PYTHON" - <<'PY' >/dev/null
import numpy
PY

"$PYTHON" "$ROOT/tools/locate_v9_snippets.py" inventory \
  --snippets "$SNIPPETS" \
  --originals "$ORIGINALS" \
  --generations "$GENERATIONS" \
  --expect-snippets 671 \
  --expect-single 89 \
  --expect-dual 582 \
  --expect-originals 120 \
  | tee "$OUT/inventory.json"

"$PYTHON" "$ROOT/tools/locate_v9_snippets.py" seed-report \
  --snippets "$SNIPPETS" \
  --originals "$ORIGINALS" \
  --events "$EVENTS" \
  --generations "$GENERATIONS" \
  --seed-generation gen3_current801 \
  --output "$OUT/gen3_metadata_seeds.tsv"

if [[ "$MODE" == "--seed-only" ]]; then
  printf '\nSeed-only complete: %s\n' "$OUT/gen3_metadata_seeds.tsv"
  exit 0
fi


if [[ "$MODE" == "--salvage-v1" ]]; then
  test -f "$V1_INDEX" || { echo "REFUSE: v0.1 SQLite postings DB not found: $V1_INDEX" >&2; exit 3; }
  rm -rf "$INDEX"
  "$PYTHON" "$ROOT/tools/locate_v9_snippets.py" convert-sqlite \
    --sqlite "$V1_INDEX" \
    --originals "$ORIGINALS" \
    --index "$INDEX" \
    --expect-originals 120
  printf '\nSalvaged v0.1 postings into CSR index: %s\n' "$INDEX"
  exit 0
fi

if [[ ${V9_REBUILD_INDEX:-0} == 1 ]]; then
  rm -rf "$INDEX"
fi
if [[ ! -f "$INDEX/meta.json" ]]; then
  "$PYTHON" "$ROOT/tools/locate_v9_snippets.py" build-index \
    --originals "$ORIGINALS" \
    --index "$INDEX" \
    --expect-originals 120
fi

if [[ "$MODE" == "--index-only" ]]; then
  printf '\nIndex-only complete: %s\n' "$INDEX"
  exit 0
fi

"$PYTHON" "$ROOT/tools/locate_v9_snippets.py" locate \
  --snippets "$SNIPPETS" \
  --originals "$ORIGINALS" \
  --index "$INDEX" \
  --generations "$GENERATIONS" \
  --events "$EVENTS" \
  --seed-generation gen3_current801 \
  --output-tsv "$OUT/locations.tsv" \
  --output-jsonl "$OUT/locations.jsonl"

printf '\nV9 locator complete\n'
printf '  inventory: %s\n' "$OUT/inventory.json"
printf '  gen3 seeds: %s\n' "$OUT/gen3_metadata_seeds.tsv"
printf '  locations: %s\n' "$OUT/locations.tsv"
printf '  evidence: %s\n' "$OUT/locations.jsonl"
