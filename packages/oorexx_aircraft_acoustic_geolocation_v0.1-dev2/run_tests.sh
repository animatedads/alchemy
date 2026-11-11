#!/bin/sh
set -eu
cd "$(dirname "$0")"
rexx tests/physics_test.rex
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT HUP INT TERM
rexx src/CoarsePairMatcher.rex fixtures/predicted.synthetic.tsv fixtures/observations.synthetic.tsv 5 5 > "$tmpdir/coarse.tsv"
if ! grep -q 'CELL_A' "$tmpdir/coarse.tsv"; then echo 'FAIL: missing true candidate'; exit 1; fi
if grep -q 'CELL_B' "$tmpdir/coarse.tsv"; then echo 'FAIL: bad interval admitted'; exit 1; fi
if ! grep -q 'CELL_C' "$tmpdir/coarse.tsv"; then echo 'FAIL: plausible alternative missing'; exit 1; fi
first=$(sed -n 2p "$tmpdir/coarse.tsv" | cut -f1)
[ "$first" = 'CELL_A' ] || { echo "FAIL: ranking returned $first"; exit 1; }
echo 'PASS coarse pair filter/ranking'
rexx src/BuildCandidateEvents.rex fixtures/receiver_relative.synthetic.tsv > "$tmpdir/catalog.tsv"
rexx src/CoarsePairMatcher.rex "$tmpdir/catalog.tsv" fixtures/observations.synthetic.tsv 5 5 > "$tmpdir/pairs.tsv"
first=$(sed -n 2p "$tmpdir/pairs.tsv" | cut -f1)
[ "$first" = 'CELL_A' ] || { echo "FAIL: precompute ranking returned $first"; exit 1; }
if grep -q '^CELL_B' "$tmpdir/pairs.tsv"; then echo 'FAIL: bad flight admitted'; exit 1; fi
if ! grep -q '^CELL_C' "$tmpdir/pairs.tsv"; then echo 'FAIL: alternative missing'; exit 1; fi
echo 'PASS precompute and ranking'
rexx src/DopplerTrackPredictor.rex fixtures/doppler_track.synthetic.tsv > "$tmpdir/track.tsv"
rexx tests/doppler_prediction_test.rex "$tmpdir/track.tsv"
if rexx src/DopplerTrackPredictor.rex fixtures/doppler_duplicate.synthetic.tsv > "$tmpdir/bad1.txt" 2>&1; then
  echo 'FAIL: duplicate emission timestamp admitted'; exit 1
fi
if rexx src/DopplerTrackPredictor.rex fixtures/doppler_supersonic.synthetic.tsv > "$tmpdir/bad2.txt" 2>&1; then
  echo 'FAIL: non-causal radial velocity admitted'; exit 1
fi
if rexx src/DopplerTrackPredictor.rex fixtures/doppler_track.synthetic.tsv 0 > "$tmpdir/bad3.txt" 2>&1; then
  echo 'FAIL: invalid sound speed admitted'; exit 1
fi
echo 'PASS fail-closed negative tests (3)'
