#!/usr/bin/env bash
set -euo pipefail
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
NODE=ed209h
mkdir -p "$ROOT/run"
LOG="$ROOT/run/$NODE.log"; PID="$ROOT/run/$NODE.pid"; RC="$ROOT/run/$NODE.rc"
if [[ -f "$PID" ]]; then p=$(cat "$PID" 2>/dev/null || true); if [[ $p =~ ^[0-9]+$ ]] && kill -0 "$p" 2>/dev/null; then echo "RUNNING $NODE pid=$p"; exit 0; fi; fi
rm -f "$RC" "$PID"
( set +e; "$ROOT/h_refinement_worker.sh" "$NODE" >"$LOG" 2>&1; x=$?; printf '%s\n' "$x" >"$RC" ) &
echo $! > "$PID"
echo "STARTED $NODE pid=$! log=$LOG"
