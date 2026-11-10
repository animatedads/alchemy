#!/bin/sh
# run.sh - every testimony case against its expected verdicts
# Architecture: Tom Dyer. Code: Claude (Opus 5.5).
cd "$(dirname "$0")/.."
: "${ALCHEMY_REPO_ROOT:?set ALCHEMY_REPO_ROOT to your animatedads/alchemy checkout}"; export ALCHEMY_REPO_ROOT
. wordnet/env.sh
rexx compile.rex . > /dev/null || exit 1
fails=0
for d in testimony_cases/*/; do
  d=${d%/}
  cp concepts.words lexicon.words rules.words $d/
  mkdir -p $d/out
  rexx testimony.rex $d | awk '/^AT\./ { v=$0; sub(/^[^ ]+ +[^ ]+ +[^ ]+ +/, "", v); print $1 "|" v }' > $d/out/verdicts.txt
  if cmp -s $d/expect.txt $d/out/verdicts.txt; then echo "PASS $d"
  else echo "FAIL $d"; diff $d/expect.txt $d/out/verdicts.txt; fails=$((fails+1)); fi
done
exit $fails
