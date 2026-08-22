#!/bin/sh
set -eu

ROOT="${SHANNON_ROOT:-/home/hc3/alchemy/ourladyair_shannon_v0.5}"

echo '== Shannon reputation dependency probe =='
echo "shannon_root=$ROOT"
printf 'rexx='; command -v rexx || true
rexx --version 2>&1 | head -4 || true

if [ ! -d "$ROOT" ]; then
  echo "FAIL SHANNON_ROOT_NOT_FOUND root=$ROOT"
  exit 1
fi

for f in \
  "$ROOT/run_tests.sh" \
  "$ROOT/tests/test_shannon_reputation_gate.rex" \
  "$ROOT/tests/test_shannon_reputation_communication.rex"
do
  if [ ! -f "$f" ]; then
    echo "FAIL REQUIRED_FILE_MISSING file=$f"
    exit 1
  fi
done

echo '== reputation references in Shannon harness =='
grep -nE 'reputation_effect|reputation\.effect|REPUTATION' "$ROOT/run_tests.sh" "$ROOT/tests/test_shannon_reputation_gate.rex" "$ROOT/tests/test_shannon_reputation_communication.rex" || true

echo '== gate source =='
sed -n '1,220p' "$ROOT/tests/test_shannon_reputation_gate.rex"

echo '== communication source head =='
sed -n '1,120p' "$ROOT/tests/test_shannon_reputation_communication.rex"

echo '== locally visible reputation package candidates =='
find /home/hc3/alchemy -maxdepth 3 \( -type d -o -type f \) -name 'reputation_effect_v0.*' -print 2>/dev/null | sort || true

echo '== API strings in visible ReputationEffect.cls files =='
find /home/hc3/alchemy -maxdepth 5 -type f -name 'ReputationEffect.cls' -print 2>/dev/null | while IFS= read -r f; do
  echo "--- $f"
  grep -nE 'reputation\.effect/0\.[0-9]+|API_VERSION|VERSION' "$f" | head -30 || true
done

old_gate=0
new_surface=0
if grep -q 'reputation.effect/0.1' "$ROOT/tests/test_shannon_reputation_gate.rex"; then old_gate=1; fi
if grep -q 'ReputationCommunicationFailure' "$ROOT/tests/test_shannon_reputation_communication.rex"; then new_surface=1; fi

echo "old_gate=$old_gate new_communication_surface=$new_surface"
if [ "$old_gate" -eq 1 ] && [ "$new_surface" -eq 1 ]; then
  echo 'PASS SHANNON_REPUTATION_VERSION_MISMATCH_CONFIRMED required=reputation.effect/0.2 gate=reputation.effect/0.1'
  exit 0
fi

echo 'FAIL EXPECTED_MISMATCH_NOT_CONFIRMED state_has_changed=1'
exit 1
