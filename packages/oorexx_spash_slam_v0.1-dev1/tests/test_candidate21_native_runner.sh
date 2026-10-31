#!/bin/sh
# SPASH Candidate21 runner admission smoke test; no private recordings or owner SDK.
set -eu
cd "$(dirname "$0")/.."
RUNNER="$PWD/tools/run_spash_candidate21_native.sh"
[ -f "$RUNNER" ] || exit 1
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT HUP INT TERM
printf 'synthetic placeholder, not audio\n' > "$work/fixture.ogg"
refuse() {
  label=$1
  shift
  set +e
  sh "$RUNNER" "$@" > "$work/out" 2>&1
  rc=$?
  set -e
  if [ "$rc" -eq 0 ]; then
    echo "FAIL: invalid input admitted: $label" >&2
    exit 1
  fi
  echo "PASS: refusal $label (exit=$rc)"
}
refuse missing-args
refuse invalid-feed "$work/fixture.ogg" WRONG 0 0 "$work/owner" /bin/true "$work/out1"
refuse invalid-offset "$work/fixture.ogg" FC abc 0 "$work/owner" /bin/true "$work/out2"
refuse invalid-channel "$work/fixture.ogg" FC 0 17 "$work/owner" /bin/true "$work/out3"
refuse no-original "$work/absent.ogg" FC 0 0 "$work/owner" /bin/true "$work/out4"
refuse no-ooRexx "$work/fixture.ogg" FC 0 0 "$work/owner" "$work/not-rexx" "$work/out5"
mkdir "$work/already"
refuse no-overwrite "$work/fixture.ogg" FC 0 0 "$work/owner" /bin/true "$work/already"
echo 'SPASH Candidate21 source admission: 7/7 expected rejections PASS'
