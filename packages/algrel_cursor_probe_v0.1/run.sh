#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
RYTA="${1:?usage: run.sh /path/virtual_ryta_hardworld_v0.11 /path/msqlshim_v0.10 /path/nosqlserver_v0.69/src/NoSQLServer.cls [port]}"
MSQL="${2:?}"
NOSQL="${3:?}"
PORT="${4:-3681}"
TMP="$(mktemp -d /tmp/algrel_cursor_probe.XXXXXX)"
trap '[[ -f "$TMP/pid" ]] && kill "$(cat "$TMP/pid")" 2>/dev/null || true; rm -rf "$TMP"' EXIT
mkdir -p "$TMP/tests/src" "$TMP/tests/vendor" "$TMP/db/tables"
ln -s "$(realpath "$MSQL/src/MySQLWireServer.cls")" "$TMP/tests/src/MySQLWireServer.cls"
ln -s "$(realpath "$MSQL/src/MySQLDeflate.cls")" "$TMP/tests/src/MySQLDeflate.cls"
ln -s "$(realpath "$NOSQL")" "$TMP/tests/vendor/NoSQLServer.cls"
ln -s "$(realpath "$RYTA/algorithm")" "$TMP/algorithm"
mkdir -p "$TMP/integration"
  for f in "$RYTA"/integration/*.cls; do ln -s "$(realpath "$f")" "$TMP/integration/$(basename "$f")"; done
  rm "$TMP/integration/NoSQLServerAlgorithmRelationExternalEngine.cls"
  ln -s "$(realpath "$HERE/integration_patch/NoSQLServerAlgorithmRelationExternalEngine.cls")" "$TMP/integration/NoSQLServerAlgorithmRelationExternalEngine.cls"
ln -s "$(realpath "$RYTA/VirtualRYTA.cls")" "$TMP/VirtualRYTA.cls"
ln -s "$(realpath "$RYTA/HardWorld.cls")" "$TMP/HardWorld.cls"
ln -s "$(realpath "$RYTA/RYTAStateRules.cls")" "$TMP/RYTAStateRules.cls"
ln -s "$(realpath "$RYTA/plugins")" "$TMP/plugins"
cp "$HERE/server.rex" "$TMP/tests/server.rex"
cat > "$TMP/db/database.yaml" <<'YAML'
name: algrel_cursor_probe
formatVersion: 1
tables: []
YAML
cd "$TMP/tests"
(rexx server.rex "$PORT" "$TMP/db" >"$TMP/server.log" 2>&1 & echo $! >"$TMP/pid")
for _ in $(seq 1 100); do
  grep -q 'MSQL ALGREL EXTERNAL READY' "$TMP/server.log" && break
  kill -0 "$(cat "$TMP/pid")" 2>/dev/null || { cat "$TMP/server.log"; exit 1; }
  sleep .1
done
cat "$TMP/server.log"
python3 "$HERE/client.py" "$PORT"
