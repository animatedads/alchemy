#!/bin/bash
# test_orders_v098.sh - SLAM 450 v0.98 with Boston Crab v0.18: a conditional ("якщо ...") is never flown,
# swearing is a tone line, a bare "ні" is no order, a grid beats the Field;
# Boston Crab v0.19: "without stop", "не" on one verb, the hostile drones, and a
# craft named in an order is its object, not a place. Red's 3v3 situation.
# Needs CRAB_WORK (a Boston Crab v0.18+ copy with wordnet/oewn.db) and
# ALCHEMY_REPO_ROOT; skips (exit 0) without them.
# Architecture: Tom Dyer. Written by: Claude (Opus 5.5), 2026-11-05.
HERE=$(cd "$(dirname "$0")/.." && pwd)
if [ -z "$CRAB_WORK" ] || [ ! -f "$CRAB_WORK/order_check.rex" ] || [ ! -f "$CRAB_WORK/wordnet/oewn.db" ]; then
  echo "SKIP test_orders_v098: set CRAB_WORK to a Boston Crab v0.18+ copy with wordnet/oewn.db"; exit 0; fi
E="$HERE/tests/orders_v098"; T=$(mktemp -d); fails=0
rexx "$HERE/bin/crab450_situation.rex" "$T/c" 1 ruby "A1 -250 -100 30;A2 -262 -100 30;A3 150 -900 40;A4 -550 250 40;A5 -450 -850 60;A6 180 -650 42|A1 A4 A6" > /dev/null || { echo "FAIL situation"; exit 1; }
cat "$E/orders.txt" >> "$T/c/story.txt"
bash "$HERE/bin/crab450_check.sh" "$CRAB_WORK" "$T/c" || { echo "FAIL check rc=$?"; exit 1; }
for f in orders.txt relay.txt; do
  if cmp -s "$E/expect_$f" "$T/c/out/$f"; then echo "PASS $f"
  else echo "FAIL $f"; diff "$E/expect_$f" "$T/c/out/$f"; fails=$((fails+1)); fi
done
grep -q "^tone|2|frustration|" "$T/c/out/orders.words" && echo "PASS tone line" || { echo "FAIL no tone line"; fails=$((fails+1)); }
rm -rf "$T"
exit $fails
