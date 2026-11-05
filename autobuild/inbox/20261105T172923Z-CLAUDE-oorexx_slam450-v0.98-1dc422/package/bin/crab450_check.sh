#!/bin/bash
# crab450_check.sh CRAB DIR - SLAM 450 v0.94: Boston Crab checks the orders in DIR
# CRAB: a private working copy of oorexx_slam_bostoncrab (v0.8+); its WordNet
# import learns new words into that copy, never into the published package.
# Architecture: Tom Dyer. Written by: Claude (Opus 5.5), 2026-11-05.
CRAB=$(cd "$1" && pwd); D=$(cd "$2" && pwd)
SLAMBIN=$(cd "$(dirname "$0")" && pwd)
: "${ALCHEMY_REPO_ROOT:?set ALCHEMY_REPO_ROOT}"; export ALCHEMY_REPO_ROOT
cd "$CRAB" && . wordnet/env.sh || exit 2
# v0.97: compile a fresh copy once before its first import. Boston Crab
# v0.18 as shipped writes "drone|noun|^drone|" on an import before any
# compile, and the compile then fails (unknown concept ^drone).
if [ ! -f .slam450_compiled ]; then rexx compile.rex . > /dev/null || exit 4; touch .slam450_compiled; fi
rexx wordnet/wn_import.rex "$D/story.txt" > "$D/import.txt" 2>&1 || exit 3
rexx compile.rex . > /dev/null || exit 4
cp concepts.words lexicon.words rules.words "$D/" && mkdir -p "$D/out"
rexx order_check.rex "$D" > /dev/null 2> "$D/out/check_err.txt" || exit 5
rexx "$SLAMBIN/crab450_relay.rex" "$D" 2> "$D/out/relay_err.txt" || exit 6
exit 0
