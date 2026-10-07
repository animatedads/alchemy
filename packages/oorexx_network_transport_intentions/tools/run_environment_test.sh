#!/usr/bin/env bash
set -euo pipefail
HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(cd -- "$HERE/.." && pwd)
REXX_BIN=${REXX_BIN:-rexx}
fail(){ printf 'FAIL %s\n' "$*" >&2; exit 1; }
pass(){ printf 'PASS %s\n' "$*"; }
command -v "$REXX_BIN" >/dev/null 2>&1 || fail "ooRexx interpreter not found: $REXX_BIN"
export REXX_PATH="$ROOT/src:$ROOT/vendor/socket-provider:$ROOT/vendor/xtp${MANAGEMENT_INTENTION_ROOT:+:$MANAGEMENT_INTENTION_ROOT/src}${REXX_PATH:+:$REXX_PATH}"
printf '%s\n' '== interpreter =='
"$REXX_BIN" -v | head -4
printf '%s\n' '== non-execution architecture guards =='
if grep -RniE 'address command|xtp-admin|~sender\(|~listener\(|cloudctl\.sh|sshnode\.sh|az vm|gcloud compute|aws ec2|oci compute|curl .*api\.vultr' "$ROOT/src" "$ROOT/tests" >/tmp/network-transport-forbidden.$$; then
  cat /tmp/network-transport-forbidden.$$ >&2
  rm -f /tmp/network-transport-forbidden.$$
  fail 'execution/probing shortcut leaked into Network Transport Intentions'
fi
rm -f /tmp/network-transport-forbidden.$$
pass 'no execution/probing shortcut in Network Transport Intentions implementation/tests'
(
  cd "$ROOT/tests"
  "$REXX_BIN" test_network_transport_intentions.rex
  "$REXX_BIN" test_network_transport_relationships.rex
  "$REXX_BIN" test_dynamic_transport_discovery.rex
)
pass 'network transport intentions dev1 environment qualification'
