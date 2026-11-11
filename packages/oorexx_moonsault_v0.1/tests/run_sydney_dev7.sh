#!/bin/sh
# Execute synthetic and (when supplied) real Sydney evidence through ooRexx.
# Set REXX and LD_LIBRARY_PATH to the ooRexx r13196/native-media locations.
set -eu
root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
media="$root/../oorexx_media_object_access_v0.1-dev1"
runner=${REXX:-rexx}
cd "$media/tests"
"$runner" test_similarity_registration.rex
"$runner" negative_gate_probe.rex
cd "$root/tests"
"$runner" test_fullres_revisit.rex
if [ "${SYDNEY_SCREENSHOT_ROOT:-}" != "" ]; then
  mkdir -p "$root/tests/results"
  cd "$media/tests"
  "$runner" test_sydney_six_similarity.rex "$SYDNEY_SCREENSHOT_ROOT" "$root/tests/results/sydney_six_similarity.tsv"
  cd "$root/tests"
  "$runner" test_sydney_220842_fullres.rex "$SYDNEY_SCREENSHOT_ROOT" \
    "$SYDNEY_SCREENSHOT_ROOT/sydney_6frame_mask_6.pgm" "$root/tests/results/sydney_220842_fullres_candidates.tsv"
  "$runner" test_sydney_four_qualified_stars.rex "$SYDNEY_SCREENSHOT_ROOT" \
    "$root/tests/results/sydney_four_qualified_candidates.tsv"
fi