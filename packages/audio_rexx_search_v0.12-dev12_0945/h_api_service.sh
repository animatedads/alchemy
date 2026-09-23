#!/usr/bin/env bash
set -euo pipefail
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
mkdir -p "$ROOT/run"
worker_pid=''
cleanup(){
  [[ -n "$worker_pid" ]] && kill "$worker_pid" 2>/dev/null || true
  wait "$worker_pid" 2>/dev/null || true
}
trap cleanup EXIT INT TERM
"$ROOT/ensure_native_runtime.sh" >/dev/null
"$ROOT/h_api_worker.sh" --loop >>"$ROOT/run/ed209h-api-worker.log" 2>&1 &
worker_pid=$!
printf '%s\n' "$worker_pid" > "$ROOT/run/ed209h-api-worker.pid"
"$ROOT/h_api_server.sh"
