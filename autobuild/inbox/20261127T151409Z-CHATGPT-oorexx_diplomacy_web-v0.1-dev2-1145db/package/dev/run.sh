#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
: "${WIRE_ESTATE:?set WIRE_ESTATE to dependency root}"
: "${OOREXX_HOME:?set OOREXX_HOME}"
export PATH="$OOREXX_HOME/bin:$PATH" LD_LIBRARY_PATH="$OOREXX_HOME/lib:${LD_LIBRARY_PATH:-}"
export REXX_PATH="$PWD/src:$WIRE_ESTATE/wire_ui_server_v0.17/src:$WIRE_ESTATE/oorexx_queue_fabric_web_gateway_v0.2/src:$WIRE_ESTATE/oorexx_queue_fabric_v0.9-dev6/src:$WIRE_ESTATE/alchemy_objects_v0.8/src:$WIRE_ESTATE/oorexx_crypto_v0.8.3/src:$OOREXX_HOME/bin"
state=$(mktemp -d)
rpid=; wpid=
finish(){ touch "$state/stop"; [ -z "$wpid" ] || kill "$wpid" 2>/dev/null || true; [ -z "$rpid" ] || wait "$rpid" 2>/dev/null || true; rm -rf "$state"; }
trap finish EXIT INT TERM
rexx dev/backend.rex "$state/port" "$state/stop" >"$state/backend.log" 2>&1 &
rpid=$!
for i in $(seq 1 200); do [ ! -s "$state/port" ] || break; kill -0 "$rpid" 2>/dev/null || break; sleep .05; done
if [ ! -s "$state/port" ]; then cat "$state/backend.log"; exit 1; fi
node dev/web-server.mjs "$(cat "$state/port")" "$state/http" &
wpid=$!
wait "$wpid"
