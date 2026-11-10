#!/bin/sh
# run_stories.sh - compile, read every story, answer the quizzes, and compare
# with the expected outputs in tests/expected. Any difference fails.
# Architecture: Tom Dyer. Code: Claude (Opus 5.5).
cd "$(dirname "$0")/.."
: "${ALCHEMY_REPO_ROOT:?set ALCHEMY_REPO_ROOT to your animatedads/alchemy checkout}"; export ALCHEMY_REPO_ROOT
. wordnet/env.sh
rexx compile.rex . > /dev/null || exit 1
fails=0
for d in . story1b story2 story3 story4 story4b story5 story6 story7 story8 story8a story9 story10; do
  [ "$d" = . ] || cp concepts.words lexicon.words rules.words $d/
  rexx read_story.rex $d $d/out > /dev/null || { echo "FAIL $d: read_story stopped"; fails=$((fails+1)); continue; }
  if [ -f $d/questions.txt ]; then rexx qa.rex $d > /dev/null || { echo "FAIL $d: qa stopped"; fails=$((fails+1)); }; fi
  e=tests/expected/$d
  for f in realised.txt findings.txt unread.txt answers.txt; do
    [ -f $e/$f ] || continue
    if cmp -s $e/$f $d/out/$f; then :; else echo "FAIL $d/$f"; diff $e/$f $d/out/$f | head -10; fails=$((fails+1)); fi
  done
  echo "read $d"
done
[ $fails -eq 0 ] && echo "PASS all stories" 
exit $fails
