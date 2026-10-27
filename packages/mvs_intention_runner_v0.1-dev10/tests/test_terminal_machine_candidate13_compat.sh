#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
TM_ROOT=${TERMINAL_MACHINE_ROOT:-}
OOREXX_DEB=${OOREXX_DEB:-/mnt/data/oorexx-5.3.0-13196.ubuntu1604debug.x86_64\(20261006-092552\).deb}

[[ -n "$TM_ROOT" && -f "$TM_ROOT/src/TN3270LiveSession.cls" ]] || {
  echo "BLOCKED Terminal Machine root not supplied"
  exit 2
}
WORK=${TMPDIR:-/tmp}/mvs-intention-dev9-tm-compile
rm -rf "$WORK"; mkdir -p "$WORK/oorexx" "$WORK/stub"
dpkg-deb -x "$OOREXX_DEB" "$WORK/oorexx"
REXX=$(find "$WORK/oorexx" -type f -path '*/bin/rexx' | head -1)
REXXC=$(find "$WORK/oorexx" -type f -path '*/bin/rexxc' | head -1)
RHOME=$(dirname "$(dirname "$REXX")")
cat > "$WORK/stub/AlchemyObject.cls" <<'EOF'
::class AlchemyObject public
::method init
  return self
::method registerExternalRequirement
  return self
::method registerInstrumentationPoint
  return self
::method alchemyInstrument
  return .nil
::method alchemyTouch
  return self
EOF
export LD_LIBRARY_PATH="$RHOME/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export REXX_PATH="$WORK/stub:$TM_ROOT/src"
"$REXXC" "$ROOT/tools/terminal_machine_tso_discovery.rex" "$WORK/terminal_machine_tso_discovery.orx" >/dev/null
for t in \
  test_3270_datastream.rex \
  test_3270_aids.rex \
  test_3270_extended_attributes.rex \
  test_3270_operator_input.rex \
  test_3270_structured_fields.rex \
  test_3270_partition_io.rex \
  test_tn3270_wire.rex \
  test_tn3270e_wire.rex \
  test_tn3270_wsf_wire.rex
do
  "$REXX" "$TM_ROOT/tests/$t"
done
echo "PASS Terminal Machine candidate13 compatibility slice"
