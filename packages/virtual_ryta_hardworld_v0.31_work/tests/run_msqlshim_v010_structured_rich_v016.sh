#!/usr/bin/env bash
set -euo pipefail
MSQL_ROOT=${1:?usage: $0 /path/to/msqlshim_v0.10 /path/to/nosqlserver_v0.71 /path/to/structured_relation_plugin_v0.5 [port]}
NOSQL_ROOT=${2:?usage: $0 /path/to/msqlshim_v0.10 /path/to/nosqlserver_v0.71 /path/to/structured_relation_plugin_v0.5 [port]}
PLUGIN_ROOT=${3:?usage: $0 /path/to/msqlshim_v0.10 /path/to/nosqlserver_v0.71 /path/to/structured_relation_plugin_v0.5 [port]}
PORT=${4:-3676}
ROOT=$(cd "$(dirname "$0")/.." && pwd)
TMP=$(mktemp -d /tmp/structured-rich-wire.XXXXXX)
DBROOT="$TMP/db"
cleanup(){ if [[ -f "$TMP/server.pid" ]]; then kill "$(cat "$TMP/server.pid")" 2>/dev/null || true; fi; rm -rf "$TMP"; }
trap cleanup EXIT
mkdir -p "$TMP/tests/src" "$TMP/tests/vendor" "$TMP/tests/fixtures" "$DBROOT/tables"
ln -s "$(realpath "$MSQL_ROOT/src/MySQLWireServer.cls")" "$TMP/tests/src/MySQLWireServer.cls"
ln -s "$(realpath "$MSQL_ROOT/src/MySQLDeflate.cls")" "$TMP/tests/src/MySQLDeflate.cls"
ln -s "$(realpath "$NOSQL_ROOT/src/NoSQLServer.cls")" "$TMP/tests/vendor/NoSQLServer.cls"
# The wire server requires NoSQLServer through the msqlshim vendor path.
if [[ -e "$MSQL_ROOT/vendor/NoSQLServer.cls" ]]; then :; fi
# Stage structured-source classes so their own relative ::requires stay valid.
for f in "$PLUGIN_ROOT"/src/*.cls; do ln -s "$(realpath "$f")" "$TMP/tests/$(basename "$f")"; done
for f in "$PLUGIN_ROOT"/tests/fixtures/orders.xml "$PLUGIN_ROOT"/tests/fixtures/orders.edi "$PLUGIN_ROOT"/tests/fixtures/purchase_order.x12; do ln -s "$(realpath "$f")" "$TMP/tests/fixtures/$(basename "$f")"; done
ln -s "$ROOT/algorithm" "$TMP/algorithm"
ln -s "$ROOT/integration" "$TMP/integration"
cp "$ROOT/tests/mysql_wire_structured_rich_v016_server.rex" "$TMP/tests/"
cat > "$DBROOT/database.yaml" <<'YAML'
name: structured_rich_v016
formatVersion: 1
tables: []
YAML
# Rebind the shim's vendor NoSQLServer for this staged server.
mkdir -p "$TMP/vendor"
ln -s "$(realpath "$NOSQL_ROOT/src/NoSQLServer.cls")" "$TMP/vendor/NoSQLServer.cls"
# MySQLWireServer's relative vendor path is ../vendor from src symlink target in
# the original package, so create a temporary msql source copy with vendor binding.
mkdir -p "$TMP/msql/src" "$TMP/msql/vendor"
cp "$MSQL_ROOT/src/MySQLWireServer.cls" "$TMP/msql/src/"
cp "$MSQL_ROOT/src/MySQLDeflate.cls" "$TMP/msql/src/"
ln -s "$(realpath "$NOSQL_ROOT/src/NoSQLServer.cls")" "$TMP/msql/vendor/NoSQLServer.cls"
rm "$TMP/tests/src/MySQLWireServer.cls" "$TMP/tests/src/MySQLDeflate.cls"
ln -s "$TMP/msql/src/MySQLWireServer.cls" "$TMP/tests/src/MySQLWireServer.cls"
ln -s "$TMP/msql/src/MySQLDeflate.cls" "$TMP/tests/src/MySQLDeflate.cls"
cd "$TMP/tests"
(rexx mysql_wire_structured_rich_v016_server.rex "$PORT" "$DBROOT" > "$TMP/server.log" 2>&1 & echo $! > "$TMP/server.pid")
pid=$(cat "$TMP/server.pid")
for _ in $(seq 1 100); do
  grep -q 'MSQL V010 STRUCTURED RICH V016 READY' "$TMP/server.log" && break
  kill -0 "$pid" 2>/dev/null || { cat "$TMP/server.log"; exit 1; }
  sleep 0.1
done
cat "$TMP/server.log"
python3 "$ROOT/tests/mysql_wire_structured_rich_v016_client.py" "$PORT"
