#!/bin/sh
# run.sh - every QA case; the score line must be full marks
# Architecture: Tom Dyer. Code: Claude (Opus 5.5).
cd "$(dirname "$0")/.."
: "${ALCHEMY_REPO_ROOT:?set ALCHEMY_REPO_ROOT to your animatedads/alchemy checkout}"; export ALCHEMY_REPO_ROOT
. wordnet/env.sh
rexx compile.rex . > /dev/null || exit 1
fails=0
for d in qa_cases/*/; do
  d=${d%/}
  cp concepts.words lexicon.words rules.words $d/
  n=$(grep -c '^Q|' $d/questions.txt)
  line=$(rexx qa.rex $d | grep '^score against key')
  case "$line" in
    "score against key: $n of $n"*) echo "PASS $d  $line";;
    *) echo "FAIL $d  $line"; rexx qa.rex $d | grep -A3 '^1\.'; fails=$((fails+1));;
  esac
done
exit $fails
