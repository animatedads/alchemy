#!/usr/bin/env bash
set -euo pipefail
HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(cd -- "$HERE/.." && pwd)
REXX_BIN=${REXX_BIN:-rexx}
fail(){ printf 'FAIL %s\n' "$*" >&2; exit 1; }
pass(){ printf 'PASS %s\n' "$*"; }
command -v "$REXX_BIN" >/dev/null 2>&1 || fail "ooRexx interpreter not found: $REXX_BIN"
export REXX_PATH="$ROOT/src:$ROOT/vendor/instrumentation-mesh${REXX_PATH:+:$REXX_PATH}"
printf '%s\n' '== interpreter =='
"$REXX_BIN" -v | head -4
printf '%s\n' '== architecture guards =='
if grep -RniE 'cloudctl\.sh|sshnode\.sh|handleCommand|commandTarget|InstrumentationCodec~command|az vm|gcloud compute|aws ec2|oci compute' "$ROOT/src" "$ROOT/tests" >/tmp/instrumentation-intentions-forbidden.$$; then
  cat /tmp/instrumentation-intentions-forbidden.$$ >&2
  rm -f /tmp/instrumentation-intentions-forbidden.$$
  fail 'mutation/provider shortcut knowledge leaked into Instrumentation Intentions'
fi
rm -f /tmp/instrumentation-intentions-forbidden.$$
pass 'read-only instrumentation intention boundary'
printf '%s\n' '== tests =='
(cd "$ROOT/tests" && "$REXX_BIN" test_instrumentation_intentions.rex && "$REXX_BIN" test_instrumentation_history.rex && "$REXX_BIN" test_socket_telemetry_mesh_adapter.rex)
pass 'instrumentation intentions dev2 environment qualification'
