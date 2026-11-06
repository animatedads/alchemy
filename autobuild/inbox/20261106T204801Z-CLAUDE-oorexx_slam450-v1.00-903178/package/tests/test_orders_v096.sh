#!/bin/bash
# test_orders_v096.sh - SLAM 450 v0.96 with Boston Crab v0.15: grid references
# as checked places, the Field in both languages, the new Ukrainian verbs
# (avoid, withdraw, refrain, report), and an order Boston Crab failed on.
# Needs CRAB_WORK (a Boston Crab v0.15+ copy with wordnet/oewn.db) and
# ALCHEMY_REPO_ROOT; skips (exit 0) without them.
# Architecture: Tom Dyer. Written by: Claude (Opus 5.5), 2026-11-05.
HERE=$(cd "$(dirname "$0")/.." && pwd)
if [ -z "$CRAB_WORK" ] || [ ! -f "$CRAB_WORK/order_check.rex" ] || [ ! -f "$CRAB_WORK/wordnet/oewn.db" ]; then
  echo "SKIP test_orders_v096: set CRAB_WORK to a Boston Crab v0.15+ copy with wordnet/oewn.db"; exit 0; fi
E="$HERE/tests/orders_v096"; T=$(mktemp -d); fails=0
rexx "$HERE/bin/crab450_situation.rex" "$T/c" 1 ruby "A1 -250 -100 30;A2 -262 -100 30;A3 150 -900 40;A4 -550 250 40;A5 -450 -850 60" > /dev/null || { echo "FAIL situation"; exit 1; }
grep -qx "The field was an area." "$T/c/story.txt" && echo "PASS the situation names the Field" || { echo "FAIL no Field sentence"; fails=$((fails+1)); }
cat "$E/orders.txt" >> "$T/c/story.txt"
bash "$HERE/bin/crab450_check.sh" "$CRAB_WORK" "$T/c" || { echo "FAIL check rc=$?"; exit 1; }
for f in orders.txt relay.txt; do
  if cmp -s "$E/expect_$f" "$T/c/out/$f"; then echo "PASS $f"
  else echo "FAIL $f"; diff "$E/expect_$f" "$T/c/out/$f"; fails=$((fails+1)); fi
done
# an order Boston Crab failed on (v0.15 writes order, fail, end NOT CHECKED):
# one relay line, NOT CHECKED, place UNABLE; every other line unchanged
mkdir -p "$T/f/out"; cp "$T/c/bind.words" "$T/c/places.words" "$T/f/"; cp "$T/c/out/orders.txt" "$T/f/out/"
cat "$T/c/out/orders.words" "$E/fail_block.words" > "$T/f/out/orders.words"
rexx "$HERE/bin/crab450_relay.rex" "$T/f" || { echo "FAIL relay on fail block"; fails=$((fails+1)); }
if cmp -s "$E/expect_fail_relay.txt" "$T/f/out/relay.txt"; then echo "PASS fail| line"
else echo "FAIL fail| line"; diff "$E/expect_fail_relay.txt" "$T/f/out/relay.txt"; fails=$((fails+1)); fi
rm -rf "$T"
exit $fails
