#!/bin/bash
# test_orders_v094.sh - SLAM 450 v0.94: SLAM writes the situation from the
# world, Boston Crab checks fixed orders, the relay says what each craft does.
# Needs CRAB_WORK (a private copy of oorexx_slam_bostoncrab v0.8+ with its
# WordNet store built) and ALCHEMY_REPO_ROOT; skips (exit 0) without them.
# Architecture: Tom Dyer. Written by: Claude (Opus 5.5), 2026-11-05.
HERE=$(cd "$(dirname "$0")/.." && pwd)
if [ -z "$CRAB_WORK" ] || [ ! -f "$CRAB_WORK/order_check.rex" ] || [ ! -f "$CRAB_WORK/wordnet/oewn.db" ]; then
  echo "SKIP test_orders_v094: set CRAB_WORK to a Boston Crab v0.8+ copy with wordnet/oewn.db"; exit 0; fi
T=$(mktemp -d)
rexx "$HERE/bin/crab450_situation.rex" "$T/c" 1 ruby "A1 -250 -100 30;A2 -262 -100 30;A3 150 -900 40;A4 -550 250 40;A5 -450 -850 60" > /dev/null || { echo "FAIL situation"; exit 1; }
cat "$HERE/tests/orders_v094/orders.txt" >> "$T/c/story.txt"
bash "$HERE/bin/crab450_check.sh" "$CRAB_WORK" "$T/c" || { echo "FAIL check rc=$?"; exit 1; }
fails=0
for f in orders.txt relay.txt; do
  if cmp -s "$HERE/tests/orders_v094/expect_$f" "$T/c/out/$f"; then echo "PASS $f"
  else echo "FAIL $f"; diff "$HERE/tests/orders_v094/expect_$f" "$T/c/out/$f"; fails=$((fails+1)); fi
done
# the same situation, Tom Dyer's Ukrainian exchange: no translation, the
# checks and the relay work on concepts (Boston Crab v0.13+ lexicon_uk.src)
rexx "$HERE/bin/crab450_situation.rex" "$T/u" 1 ruby "A1 -250 -100 30;A2 -262 -100 30;A3 150 -900 40;A4 -550 250 40;A5 -450 -850 60" > /dev/null || { echo "FAIL situation uk"; exit 1; }
cat "$HERE/tests/orders_v094/orders_uk.txt" >> "$T/u/story.txt"
bash "$HERE/bin/crab450_check.sh" "$CRAB_WORK" "$T/u" || { echo "FAIL check uk rc=$?"; exit 1; }
for f in orders.txt relay.txt; do
  if cmp -s "$HERE/tests/orders_v094/expect_uk_$f" "$T/u/out/$f"; then echo "PASS uk $f"
  else echo "FAIL uk $f"; diff "$HERE/tests/orders_v094/expect_uk_$f" "$T/u/out/$f"; fails=$((fails+1)); fi
done
rm -rf "$T"
exit $fails
