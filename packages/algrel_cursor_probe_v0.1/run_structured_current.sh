#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
STRUCTURED="${1:?usage: run_structured_current.sh STRUCTURED_ROOT HARDWORLD_ROOT MSQLSHIM_ROOT NOSQLSERVER_ROOT ALCHEMY_ROOT CRYPTO_ROOT FIXTURE [port]}"
HARDWORLD="${2:?}"
MSQL="${3:?}"
NOSQL="${4:?}"
ALCHEMY="${5:?}"
CRYPTO="${6:?}"
FIXTURE="${7:?}"
PORT="${8:-3696}"
EXPECTED_EXTERNAL_INTEGRATION="${9:-${EXPECTED_EXTERNAL_INTEGRATION:-}}"
OOREXX_ROOT="${OOREXX_ROOT:-/usr/local}"
REXX="$OOREXX_ROOT/bin/rexx"
TMP="$(mktemp -d /tmp/algrel_structured_current.XXXXXX)"
trap '[[ -f "$TMP/pid" ]] && kill "$(cat "$TMP/pid")" 2>/dev/null || true; rm -rf "$TMP"' EXIT
mkdir -p "$TMP/tests/src" "$TMP/integration" "$TMP/db/tables"
ln -s "$(realpath "$MSQL/src/MySQLWireServer.cls")" "$TMP/tests/src/MySQLWireServer.cls"
ln -s "$(realpath "$MSQL/src/MySQLDeflate.cls")" "$TMP/tests/src/MySQLDeflate.cls"
ln -s "$(realpath "$HARDWORLD/algorithm")" "$TMP/algorithm"
for f in "$HARDWORLD"/integration/*.cls; do ln -s "$(realpath "$f")" "$TMP/integration/$(basename "$f")"; done
cp "$HERE/structured_server.rex" "$TMP/tests/structured_server.rex"
cat > "$TMP/db/database.yaml" <<'YAML'
name: structured_algrel_cursor_probe
formatVersion: 1
tables: []
YAML
export LD_LIBRARY_PATH="$OOREXX_ROOT/lib:${LD_LIBRARY_PATH:-}"
export PATH="$OOREXX_ROOT/bin:$PATH"
export TERM="${TERM:-xterm}"
export REXX_PATH="$HARDWORLD:$HARDWORLD/algorithm:$HARDWORLD/integration:$STRUCTURED/src:$NOSQL/src:$ALCHEMY/src:$CRYPTO/src:$OOREXX_ROOT/bin${REXX_PATH:+:$REXX_PATH}"
cd "$TMP/tests"
("$REXX" structured_server.rex "$PORT" "$TMP/db" "$FIXTURE" "$HARDWORLD" >"$TMP/server.log" 2>&1 & echo $! >"$TMP/pid")
for _ in $(seq 1 200); do
  grep -q 'STRUCTURED ALGREL CURSOR READY' "$TMP/server.log" && break
  kill -0 "$(cat "$TMP/pid")" 2>/dev/null || { cat "$TMP/server.log"; exit 1; }
  sleep .05
done
cat "$TMP/server.log"
python3 "$HERE/structured_client.py" "$PORT" "$EXPECTED_EXTERNAL_INTEGRATION"
