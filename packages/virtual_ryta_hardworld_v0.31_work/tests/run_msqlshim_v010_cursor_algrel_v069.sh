#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MSQL_ROOT="${1:-}"
NOSQL_CLS="${2:-}"
PORT="${3:-3640}"
if [[ -z "$MSQL_ROOT" || ! -f "$MSQL_ROOT/src/MySQLWireServer.cls" ]]; then
  echo "usage: $0 /path/to/msqlshim_v0.10 /path/to/nosqlserver_v0.69/src/NoSQLServer.cls [port]" >&2
  exit 2
fi
if [[ -z "$NOSQL_CLS" || ! -f "$NOSQL_CLS" ]]; then
  echo "NoSQLServer.cls not found: $NOSQL_CLS" >&2
  exit 2
fi
TMP="$(mktemp -d /tmp/virtual_ryta_cursor_v012.XXXXXX)"
DBROOT="$TMP/db"
cleanup(){
  if [[ -f "$TMP/server.pid" ]]; then kill "$(cat "$TMP/server.pid")" 2>/dev/null || true; fi
  rm -rf "$TMP"
}
trap cleanup EXIT
mkdir -p "$TMP/tests/src" "$TMP/tests/vendor" "$DBROOT/tables"
ln -s "$(realpath "$MSQL_ROOT/src/MySQLWireServer.cls")" "$TMP/tests/src/MySQLWireServer.cls"
ln -s "$(realpath "$MSQL_ROOT/src/MySQLDeflate.cls")" "$TMP/tests/src/MySQLDeflate.cls"
ln -s "$(realpath "$NOSQL_CLS")" "$TMP/tests/vendor/NoSQLServer.cls"
ln -s "$ROOT/algorithm" "$TMP/algorithm"
ln -s "$ROOT/integration" "$TMP/integration"
ln -s "$ROOT/VirtualRYTA.cls" "$TMP/VirtualRYTA.cls"
ln -s "$ROOT/HardWorld.cls" "$TMP/HardWorld.cls"
ln -s "$ROOT/RYTAStateRules.cls" "$TMP/RYTAStateRules.cls"
ln -s "$ROOT/plugins" "$TMP/plugins"
ln -s "$ROOT/algorithm/AlgorithmRelation.cls" "$TMP/tests/AlgorithmRelation.cls"
ln -s "$ROOT/algorithm/AlgorithmIntegrity.cls" "$TMP/tests/AlgorithmIntegrity.cls"
ln -s "$ROOT/HardWorld.cls" "$TMP/tests/HardWorld.cls"
ln -s "$ROOT/RYTAStateRules.cls" "$TMP/tests/RYTAStateRules.cls"
ln -s "$ROOT/plugins" "$TMP/tests/plugins"
cp "$ROOT/tests/mysql_wire_algrel_v069_cursor_server.rex" "$TMP/tests/"
cat > "$DBROOT/database.yaml" <<'YAML'
name: msqlshim_algrel_v069_cursor
formatVersion: 1
tables: []
YAML
cd "$TMP/tests"
(rexx mysql_wire_algrel_v069_cursor_server.rex "$PORT" "$DBROOT" > "$TMP/server.log" 2>&1 & echo $! > "$TMP/server.pid")
pid="$(cat "$TMP/server.pid")"
for _ in $(seq 1 100); do
  grep -q 'MSQL V010 ALGREL CURSOR READY' "$TMP/server.log" && break
  kill -0 "$pid" 2>/dev/null || { cat "$TMP/server.log"; exit 1; }
  sleep 0.1
done
cat "$TMP/server.log"
python3 "$ROOT/tests/mysql_wire_algrel_v069_cursor_client.py" "$PORT"
