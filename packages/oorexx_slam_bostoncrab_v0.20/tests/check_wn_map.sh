#!/bin/sh
# check_wn_map.sh - every concept wordnet/wn_map.words says was imported must
# exist in concepts_wn.src or concepts.src. A stale map makes an import that
# runs before compile.rex write references to concepts that are not there
# (v0.18 shipped the v0.17 map: "unknown concept ^drone").
# Architecture: Tom Dyer. Code: Claude (Opus 5.5).
cd "$(dirname "$0")/.."
cut -d'|' -f1 concepts.src wordnet/concepts_wn.src | grep -v '^#' | sort -u > /tmp/wnmap_have.$$
cut -d'|' -f2 wordnet/wn_map.words | sort -u > /tmp/wnmap_need.$$
missing=$(comm -13 /tmp/wnmap_have.$$ /tmp/wnmap_need.$$)
rm -f /tmp/wnmap_have.$$ /tmp/wnmap_need.$$
if [ -n "$missing" ]; then echo "FAIL wn_map.words names concepts not defined:"; echo "$missing" | head -20; exit 1; fi
echo "PASS wn_map.words matches the concept files"
