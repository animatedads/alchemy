#!/usr/bin/env bash
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
: "${SSCS_ROOT:?set SSCS_ROOT to current Semantic Source Store root}"
: "${NOSQLSERVER_ROOT:?set NOSQLSERVER_ROOT to real NoSQLServer v0.85 root}"
: "${ALCHEMY_ROOT:?set ALCHEMY_ROOT to current compatible Alchemy Objects root}"
: "${CRYPTO_ROOT:?set CRYPTO_ROOT to ooRexx Crypto root}"
: "${REXX:?set REXX to ooRexx r13196 rexx binary}"
REXXC=${REXXC:-"$(dirname "$REXX")/rexxc"}
"$REXX" -v | head -1 | grep -q '5.3.0 r13196' || { echo 'FAIL local SSCS qualification requires r13196' >&2; exit 3; }
grep -q 'NoSQLServer v0.85' "$NOSQLSERVER_ROOT/README.md" || { echo 'FAIL NOSQLSERVER_ROOT is not v0.85' >&2; exit 4; }

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
DB="$WORK/sscs"
P='qualification/dev10.rex'

"$HERE/run_local_sscs.sh" "$DB" BOOTSTRAP
"$HERE/run_local_sscs.sh" "$DB" PING | tee "$WORK/ping.txt"
grep -q '^BACKEND|nosqlserver$' "$WORK/ping.txt"

"$HERE/run_local_sscs.sh" "$DB" CREATE_PACKAGE "$P"
"$HERE/run_local_sscs.sh" "$DB" CREATE_CLASS "$P" LocalCapabilityDemo 10
"$HERE/run_local_sscs.sh" "$DB" ADD_ATTRIBUTE "$P" LocalCapabilityDemo value 20
"$HERE/run_local_sscs.sh" "$DB" ADD_METHOD "$P" LocalCapabilityDemo current 30
printf 'expose value\nreturn value\n' > "$WORK/body.rex"
"$HERE/run_local_sscs.sh" "$DB" WRITE_METHOD "$P" LocalCapabilityDemo current "$WORK/body.rex"
"$HERE/run_local_sscs.sh" "$DB" VIEW_METHOD LocalCapabilityDemo current > "$WORK/view.txt"
grep -q '^SOURCE_HEX|' "$WORK/view.txt"
"$HERE/run_local_sscs.sh" "$DB" MATERIALISE "$P" "$WORK/materialised.rex"
"$REXXC" "$WORK/materialised.rex" >/dev/null
grep -q '^::class LocalCapabilityDemo$' "$WORK/materialised.rex"
grep -q '^  return value$' "$WORK/materialised.rex"
echo 'PASS local SSCS semantic write/view/materialise on NoSQLServer v0.85'

# Run the backend's own precision forcing regression in the same dependency environment.
STDLIB=$(cd "$(dirname "$REXX")" && pwd)
export REXX_PATH="$NOSQLSERVER_ROOT/src:$NOSQLSERVER_ROOT/tests:$ALCHEMY_ROOT/src:$CRYPTO_ROOT/src:$STDLIB${REXX_PATH:+:$REXX_PATH}"
"$REXXC" "$NOSQLSERVER_ROOT/tests/v085_integer_precision_smoke.rex" >/dev/null
(
  cd "$NOSQLSERVER_ROOT/tests"
  "$REXX" v085_integer_precision_smoke.rex
)
echo 'PASS NoSQLServer v0.85 exact 10-digit INTEGER qualification in Development Desk dependency stack'
