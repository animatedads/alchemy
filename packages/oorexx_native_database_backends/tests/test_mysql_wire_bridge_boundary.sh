#!/bin/sh
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
# Source implementation must not depend on or invoke the inbound wire bridge.
if grep -RniE '::requires[[:space:]]+.*(msqlshim|mysql_wire_bridge)|mysql_wire_bridge~|msqlshim~' "$root/src" "$root/mysql" "$root/postgres" "$root/gis"; then
  echo 'MYSQL WIRE BRIDGE BOUNDARY: FAIL: outbound implementation depends on inbound bridge' >&2
  exit 1
fi
# Historical name is allowed only in documentation/compatibility explanation, not as canonical identity.
grep -q 'mysql_wire_bridge' "$root/README.md"
grep -q 'mysql_wire_bridge' "$root/WIRE_BRIDGE_BOUNDARY.md"
echo 'MYSQL WIRE BRIDGE BOUNDARY: PASS'
