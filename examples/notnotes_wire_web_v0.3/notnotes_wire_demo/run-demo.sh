#!/usr/bin/env bash
set -euo pipefail
HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
# shellcheck source=env.sh
source "$HERE/env.sh"
# ooRexx package-relative ::requires entries resolve from the package root.
cd "$ROOT"
command -v node >/dev/null || { echo 'Node.js 22+ is required for the browser gateway' >&2; exit 2; }
"$OOREXX_HOME/bin/rexx" -v | head -n 1
STATE=$(mktemp -d "${TMPDIR:-/tmp}/notnotes-wire-run-XXXXXX")
NOTNOTES_DATA_DIR=${NOTNOTES_DATA_DIR:-"${HOME:?}/.local/share/notnotes-wire-demo"}
mkdir -p "$NOTNOTES_DATA_DIR"
echo "NotNotes database directory: $NOTNOTES_DATA_DIR (retained across restarts)"
rm -f "$HERE/port" "$HERE/http-port"
REXX_PID='' WEB_PID=''
finish(){
  # INT/TERM can also trigger EXIT; cleanup is deliberately single-shot.
  trap - EXIT INT TERM
  if [ -d "$STATE" ]; then printf 'stop\n' > "$STATE/stop"; fi
  if [ -n "$WEB_PID" ]; then kill "$WEB_PID" 2>/dev/null || true; wait "$WEB_PID" 2>/dev/null || true; fi
  if [ -n "$REXX_PID" ]; then kill "$REXX_PID" 2>/dev/null || true; wait "$REXX_PID" 2>/dev/null || true; fi
  rm -f "$HERE/port" "$HERE/http-port"
  rm -rf "$STATE"
}
trap finish EXIT INT TERM
"$OOREXX_HOME/bin/rexx" "$HERE/NotNotesWireBackend.rex" "$HERE/port" "$STATE/stop" "$STATE/receipt.json" "$NOTNOTES_DATA_DIR" > "$STATE/backend.log" 2>&1 &
REXX_PID=$!
for _ in $(seq 1 200); do [ -s "$HERE/port" ] && break; kill -0 "$REXX_PID" 2>/dev/null || break; sleep 0.05; done
if [ ! -s "$HERE/port" ]; then cat "$STATE/backend.log"; echo 'ooRexx NotNotes backend failed to start' >&2; exit 3; fi
node "$HERE/web-server.mjs" > "$STATE/web.log" 2>&1 &
WEB_PID=$!
for _ in $(seq 1 200); do [ -s "$HERE/http-port" ] && break; kill -0 "$WEB_PID" 2>/dev/null || break; sleep 0.05; done
if [ ! -s "$HERE/http-port" ]; then cat "$STATE/web.log"; echo 'Wire Web Gateway failed to start' >&2; exit 4; fi
WEBPORT=$(cat "$HERE/http-port")
echo "NotNotes LIVE Wire browser entry: http://127.0.0.1:$WEBPORT/live.html"
echo 'This is a loopback-only local development demonstration, not a public deployment.'
echo 'Press Ctrl-C to stop. Use a local Chrome/Firefox browser to interact.'
echo 'New and edited NotNotes documents persist in the database directory above.'
while kill -0 "$WEB_PID" 2>/dev/null && kill -0 "$REXX_PID" 2>/dev/null; do sleep 0.5; done
echo 'A service stopped unexpectedly. Backend log:' >&2
cat "$STATE/backend.log" >&2
cat "$STATE/web.log" >&2
exit 5
