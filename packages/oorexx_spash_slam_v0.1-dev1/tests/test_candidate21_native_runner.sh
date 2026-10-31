#!/bin/sh
# SPASH Candidate21 source-only admission checks; no intercepted or private audio.
set -eu
cd "$(dirname "$0")/.."
RUNNER="$PWD/tools/run_spash_candidate21_native.sh"
[ -f "$RUNNER" ] || exit 1
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT HUP INT TERM
printf 'synthetic placeholder, not audio\n' > "$work/fixture.ogg"
mkdir -p "$work/owner/build"
printf '#!/bin/sh\nexit 0\n' > "$work/owner/build/av9_multipath_spectral_track"
printf '#!/bin/sh\nexit 0\n' > "$work/owner/build/av9_virtual_mic_dynamic"
chmod +x "$work/owner/build/av9_multipath_spectral_track" "$work/owner/build/av9_virtual_mic_dynamic"
refuse() {
  label=$1
  expected=$2
  shift 2
  set +e
  sh "$RUNNER" "$@" > "$work/out" 2>&1
  rc=$?
  set -e
  if [ "$rc" -eq 0 ]; then
    echo "FAIL: invalid input admitted: $label" >&2
    exit 1
  fi
  if ! grep -Fq "$expected" "$work/out"; then
    echo "FAIL: wrong refusal for $label (expected $expected)" >&2
    cat "$work/out" >&2
    exit 1
  fi
  echo "PASS: refusal $label (exit=$rc)"
}
refuse missing-args 'usage:' 
refuse invalid-feed 'FAIL feed' "$work/fixture.ogg" WRONG 0 0 "$work/owner" /bin/true "$work/out1"
refuse invalid-offset 'FAIL offset' "$work/fixture.ogg" FC abc 0 "$work/owner" /bin/true "$work/out2"
refuse invalid-channel 'FAIL channel' "$work/fixture.ogg" FC 0 17 "$work/owner" /bin/true "$work/out3"
refuse no-original 'FAIL original missing' "$work/absent.ogg" FC 0 0 "$work/owner" /bin/true "$work/out4"
refuse no-ooRexx 'FAIL ooRexx missing' "$work/fixture.ogg" FC 0 0 "$work/owner" "$work/not-rexx" "$work/out5"
mkdir "$work/already"
refuse no-overwrite 'FAIL output exists' "$work/fixture.ogg" FC 0 0 "$work/owner" /bin/true "$work/already"
echo 'SPASH Candidate21 source admission: 7/7 expected rejections PASS'
