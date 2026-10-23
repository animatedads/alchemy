#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
: "${BOSH_ROOT:?BOSH_ROOT is required}"
: "${MESSAGING_PRESENCE_ROOT:?MESSAGING_PRESENCE_ROOT is required}"
REXX=${REXX:-rexx}
export REXX_PATH="$ROOT/src:$BOSH_ROOT/src:$MESSAGING_PRESENCE_ROOT/src:$MESSAGING_PRESENCE_ROOT/providers/xmpp${REXX_PATH:+:$REXX_PATH}"
"$REXX" "$ROOT/tests/test_xmpp_bosh_adapter.rex"
"$REXX" "$ROOT/tests/test_fail_closed_security.rex"
