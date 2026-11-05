#!/bin/sh
# reimport.sh - rebuild the imported vocabulary from WordNet for every story, in order
# Architecture: Tom Dyer. Code: Claude (Opus 5.5).
cd "$(dirname "$0")/.."
: "${ALCHEMY_REPO_ROOT:?set ALCHEMY_REPO_ROOT to your animatedads/alchemy checkout}"; export ALCHEMY_REPO_ROOT
. wordnet/env.sh
: > wordnet/concepts_wn.src; : > wordnet/lexicon_wn.src; : > wordnet/wn_map.words
rexx compile.rex . >/dev/null
for f in story.txt story2/story.txt story3/story.txt story4/story.txt story5/story.txt \
         story6/story.txt story4b/story.txt story1b/story.txt story7/story.txt \
         story7/qa_vocab.txt story8/story.txt story8a/story.txt story9/story.txt \
         testimony_cases/*/story.txt qa_cases/*/story.txt orders/*/story.txt; do
  printf '%-22s' $f; rexx wordnet/wn_import.rex $f | head -1
  rexx compile.rex . >/dev/null
done
