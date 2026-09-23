#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
BASE=${1:-}
. "$ROOT/tools/runtime_common.sh"
[ "$(uname -m)" = x86_64 ] || { echo "FAIL architecture $(uname -m)" >&2; exit 2; }
REXX=$(av9_find_rexx) || { echo 'FAIL ooRexx executable not found' >&2; exit 2; }; av9_check_rexx "$REXX"
for c in unzip sha256sum ffmpeg; do command -v "$c" >/dev/null 2>&1 || { echo "FAIL required command missing: $c" >&2; exit 2; }; done
"$ROOT/tools/prepare_runtime.sh" >/dev/null
[ -f "$ROOT/run/deployment/foreign-runtime.tsv" ] || { echo 'FAIL missing Foreign Runtime deployment evidence' >&2; exit 3; }
[ -f "$ROOT/run/deployment/spatial-provider.tsv" ] || { echo 'FAIL missing spatial provider deployment evidence' >&2; exit 3; }
if [ -n "$BASE" ]; then "$ROOT/tools/verify_corpus.sh" "$BASE" >/dev/null; corpus='verified'; else corpus='not-requested'; fi
mkdir -p "$ROOT/run/deployment"
"$ROOT/tools/discover_worker.sh" > "$ROOT/run/deployment/discovery.tsv"
{
 printf 'schema\taudio.v9.worker.readiness/1\nstatus\tREADY\ncorpus\t%s\n' "$corpus"
 printf 'oorexx\t%s\n' "$($REXX -v 2>&1 | sed -n '1p')"
 printf 'foreign_runtime_action\t%s\n' "$(awk -F '\t' '$1=="action" {print $2}' "$ROOT/run/deployment/foreign-runtime.tsv")"
 printf 'spatial_provider_action\t%s\n' "$(awk -F '\t' '$1=="action" {print $2}' "$ROOT/run/deployment/spatial-provider.tsv")"
} > "$ROOT/run/deployment/READY.tsv"
echo "READY audio-v9-worker corpus=$corpus"
