#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
cd "$ROOT"
sha256sum -c qualification/MANIFEST.sha256 >/dev/null
: "${GOPHER:?set GOPHER to LLM Gopher v0.19-dev1+}"
"$GOPHER" --profile layered-audio context layered-audio --full > /tmp/layered-audio-context.$$
grep -q 'arch.layered-audio.ownership' /tmp/layered-audio-context.$$
grep -q 'arch.layered-audio.intentions' /tmp/layered-audio-context.$$
grep -q 'arch.layered-audio.graph-offload' /tmp/layered-audio-context.$$
grep -q 'arch.layered-audio.memory-local-execution' /tmp/layered-audio-context.$$
for q in downmix streaming quantization ForeignTensor ASR allocator horizon resident intention Management object-preserving; do
  "$GOPHER" --profile layered-audio search "$q" --sphere layered-audio > /tmp/layered-audio-search.$$
  grep -q '"class": "FOUND"' /tmp/layered-audio-search.$$
done
rm -f /tmp/layered-audio-context.$$ /tmp/layered-audio-search.$$
echo 'PASS LAYERED AUDIO SPHERE v0.3'
