#!/bin/sh
# run_scramble.sh - the gloss-scramble test on every kind of story: plain
# narration, the quiz story, counting, witness statements and orders. It
# proves reasoning never reads a gloss.
# Architecture: Tom Dyer. Code: Claude (Opus 5.5).
cd "$(dirname "$0")/.."
: "${ALCHEMY_REPO_ROOT:?set ALCHEMY_REPO_ROOT to your animatedads/alchemy checkout}"; export ALCHEMY_REPO_ROOT
. wordnet/env.sh
rexx compile.rex . > /dev/null || exit 1
fails=0
for s in . story7 story8a story9 story10 orders/light_brigade orders/light_brigade_map orders/tenerife; do
  if rexx scramble_test.rex 42 $s | tail -1 | grep -q '^PASS'; then echo "PASS scramble $s"
  else echo "FAIL scramble $s"; fails=$((fails+1)); fi
done
exit $fails
