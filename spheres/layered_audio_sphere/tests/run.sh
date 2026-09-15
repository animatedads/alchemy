#!/bin/sh
set -eu
: "${GOPHER:?set GOPHER to LLM Gopher v0.19-dev1+}"
"$GOPHER" --profile layered-audio context layered-audio --full > /tmp/layered-audio-context.$$
grep -q 'arch.layered-audio.ownership' /tmp/layered-audio-context.$$
grep -q 'arch.layered-audio.graph-offload' /tmp/layered-audio-context.$$
for q in downmix streaming quantization ForeignTensor ASR allocator; do
  "$GOPHER" --profile layered-audio search "$q" --sphere layered-audio > /tmp/layered-audio-search.$$
  grep -q '"class": "FOUND"' /tmp/layered-audio-search.$$
done
rm -f /tmp/layered-audio-context.$$ /tmp/layered-audio-search.$$
echo 'PASS LAYERED AUDIO SPHERE v0.1'
