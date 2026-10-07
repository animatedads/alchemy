#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
export EXPECT_SECRET=AZURE-TEST-KEY-DO-NOT-LOG
export AZURE_FIXTURE_COUNTER="$TMP/count"
export AZURE_OPENAI_CURL="$HERE/tests/fixtures/fake_azure_curl.sh"
export AZURE_CLI="$HERE/tests/fixtures/fake_az.sh"
DF_WORKER_RUN_ROOT="$TMP/run" "$HERE/run_worker.sh" azure luna | tee "$TMP/out"
grep -q '^Development Floor live worker: Azure selector=luna account=fixture-ai deployment=tiny-luna model=tiny-luna$' "$TMP/out"
grep -q '^outcome=OK$' "$TMP/out"
grep -q '^second_bite=REPLACE$' "$TMP/out"
grep -q '^final_stdout=HELLO WORLD$' "$TMP/out"
grep -q '^wlu_spent=2200000$' "$TMP/out"
grep -q '^PASS autonomous Development Floor live HelloWorld$' "$TMP/out"
[[ "$(cat "$TMP/count")" == 2 ]]
grep -q 'say "HELLO WORLD"' "$TMP/run/workspace/hello.rex"
echo 'PASS live Azure autonomous worker through az discovery + Secret Broker + Responses API'
