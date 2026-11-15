#!/bin/sh
# regress.sh - recompile, reread every story, compare with a baseline folder
# Usage: sh regress.sh [basedir]
# Architecture: Tom Dyer. Code: Claude (Opus 5.5).
cd "$(dirname "$0")"
: "${ALCHEMY_REPO_ROOT:?set ALCHEMY_REPO_ROOT to your animatedads/alchemy checkout}"; export ALCHEMY_REPO_ROOT
. wordnet/env.sh
BASE=${1:-/tmp/base}
rexx compile.rex . | tail -1
for d in . story1b story2 story3 story4 story4b story5 story6 story7 story8 story8a story9 story10; do
  [ "$d" = . ] || cp concepts.words lexicon.words rules.words $d/
  printf '%-8s ' "$d"; rexx read_story.rex $d $d/out | tail -1
  if [ -d "$BASE/$d" ]; then
    for f in realised.txt findings.txt unread.txt; do
      cmp -s "$BASE/$d/$f" "$d/out/$f" || echo "         changed: $f"
    done
  fi
done
