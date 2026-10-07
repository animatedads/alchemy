#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap '[[ -n "${PID:-}" ]] && kill "$PID" 2>/dev/null || true; rm -rf "$TMP"' EXIT
python3 "$HERE/tests/fixtures/fake_openai_server.py" --port 0 --port-file "$TMP/port" & PID=$!
for _ in $(seq 1 50); do [[ -s "$TMP/port" ]] && break; sleep .05; done
[[ -s "$TMP/port" ]] || { echo 'FAIL fixture server did not start'; exit 1; }
PORT="$(cat "$TMP/port")"
DF_WORKER_RUN_ROOT="$TMP/run" LLAMA_CPP_ENDPOINT="http://127.0.0.1:$PORT/v1/chat/completions" "$HERE/run_worker.sh" llama tiny-fixture-model | tee "$TMP/out"
grep -q '^outcome=OK$' "$TMP/out"
grep -q '^second_bite=REPLACE$' "$TMP/out"
grep -q '^final_stdout=HELLO WORLD$' "$TMP/out"
grep -q '^wlu_spent=2200000$' "$TMP/out"
grep -q '^PASS autonomous Development Floor live HelloWorld$' "$TMP/out"
grep -q 'say "HELLO WORLD"' "$TMP/run/workspace/hello.rex"
echo 'PASS live llama-compatible autonomous worker over HTTP'
