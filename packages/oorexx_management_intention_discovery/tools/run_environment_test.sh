#!/usr/bin/env bash
set -euo pipefail

HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(cd -- "$HERE/.." && pwd)
REXX_BIN=${REXX_BIN:-rexx}

fail() { printf 'FAIL %s\n' "$*" >&2; exit 1; }
pass() { printf 'PASS %s\n' "$*"; }

command -v "$REXX_BIN" >/dev/null 2>&1 || fail "ooRexx interpreter not found: $REXX_BIN"

export REXX_PATH="$ROOT/src:$ROOT/vendor/mvs-intentions:$ROOT/vendor/mvs-intentions/intention:$ROOT/vendor/generalized-compute:$ROOT/vendor/network-transport:$ROOT/vendor/socket-provider:$ROOT/vendor/xtp${REXX_PATH:+:$REXX_PATH}"

printf '%s\n' '== interpreter =='
"$REXX_BIN" -v | head -4

printf '%s\n' '== architecture guards =='
if grep -RniE 'cloudctl\.sh|sshnode\.sh|az vm|gcloud compute|aws ec2|oci compute|api\.vultr\.com' "$ROOT/src" "$ROOT/tests" "$ROOT/vendor/network-transport" >/tmp/management-intention-forbidden.$$; then
  cat /tmp/management-intention-forbidden.$$ >&2
  rm -f /tmp/management-intention-forbidden.$$
  fail 'provider/shortcut execution knowledge leaked into Management implementation/tests'
fi
rm -f /tmp/management-intention-forbidden.$$
pass 'no provider CLI/shortcut execution knowledge in Management implementation/tests'

printf '%s\n' '== syntax/load =='
(
  cd "$ROOT/tests"
  "$REXX_BIN" test_non_authority_contract.rex
  "$REXX_BIN" test_management_discovery.rex
  "$REXX_BIN" test_real_mvs_surface.rex
  "$REXX_BIN" test_machine_service_surfaces.rex
  "$REXX_BIN" test_cross_domain_composition.rex
  "$REXX_BIN" test_relationship_discovery.rex
  "$REXX_BIN" test_relationship_intention_explorer.rex
  "$REXX_BIN" test_related_surface_advertisement.rex
  "$REXX_BIN" test_network_transport_advertisement.rex
  "$REXX_BIN" test_network_path_multicast_advertisement.rex
)

pass 'management intention discovery dev7 environment qualification'
