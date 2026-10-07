#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
SRC="$ROOT/rexx/https_server.cls"
grep -q "::method registerFirewallProtection" "$SRC"
grep -q "firewall registration requires protected management source(s)" "$SRC"
grep -q "server~preflightRequestHead" "$SRC"
grep -q "ignored=server~responseSent" "$SRC"
if grep -E 'use strict arg.*=.*~' "$SRC" >/dev/null; then
  echo 'FAIL method-call expression used as use strict arg default' >&2
  exit 1
fi
echo 'PASS HTTPS firewall registration static qualification'
