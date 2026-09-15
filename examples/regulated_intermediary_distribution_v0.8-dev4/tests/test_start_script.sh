#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
PORT="${RID_START_TEST_PORT:-18082}"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/rid-start-test.XXXXXX")"
PID=""
cleanup(){ [[ -n "$PID" ]] && kill "$PID" 2>/dev/null || true; [[ -n "$PID" ]] && wait "$PID" 2>/dev/null || true; rm -rf "$TMP"; }
trap cleanup EXIT INT TERM

bash -n "$HERE/start.sh"
node --check "$HERE/tools/rid-ui-server.mjs"
"$HERE/start.sh" --preview --port "$PORT" >"$TMP/server.log" 2>&1 & PID=$!
for _ in $(seq 1 100); do
  if curl -fsS "http://127.0.0.1:${PORT}/" >"$TMP/page" 2>/dev/null; then break; fi
  sleep 0.05
done
grep -q 'Federation' "$TMP/page"
grep -qi 'static sample data' "$TMP/page"
curl -fsS "http://127.0.0.1:${PORT}/rid.css" >/dev/null
kill "$PID"; wait "$PID" || true; PID=""

echo "PASS package-root start.sh preview uses Node and serves Federation UI"
