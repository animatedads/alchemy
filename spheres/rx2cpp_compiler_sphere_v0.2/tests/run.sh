#!/bin/sh
set -eu
: "${GOPHER:?set GOPHER to LLM Gopher v0.21+}"
T=${TMPDIR:-/tmp}/rx2cpp-sphere.$$
"$GOPHER" --profile rx2cpp context rx2cpp --full > $T.ctx
for id in rx2cpp.start rx2cpp.build-and-run rx2cpp.qualification rx2cpp.lanes rx2cpp.epoch \
          rx2cpp.environment-symbols rx2cpp.security-managers rx2cpp.performance \
          rx2cpp.known-differences rx2cpp.interpreter-bugs rx2cpp.people-and-upstream; do
    grep -q "\"$id\"" $T.ctx || { echo "FAIL context lacks $id"; exit 1; }
done
for term in baseline 'security manager' epoch 'fixed point' trunk pbench2 plan42; do
    "$GOPHER" --profile rx2cpp search "$term" --sphere rx2cpp > $T.s
    grep -q '"class": "FOUND"' $T.s || { echo "FAIL search $term"; exit 1; }
done
rm -f $T.ctx $T.s
echo "PASS RX2CPP SPHERE v0.2"
