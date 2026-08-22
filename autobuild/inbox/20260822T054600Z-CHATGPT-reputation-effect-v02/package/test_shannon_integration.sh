#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
REP_ROOT="$ROOT/prepared/reputation_effect_v0.2"
SHANNON_ROOT="${SHANNON_ROOT:-/home/hc3/alchemy/ourladyair_shannon_v0.5}"

for d in "$REP_ROOT" "$SHANNON_ROOT" /home/hc3/alchemy/virtual_ryta_hardworld /home/hc3/alchemy/legal_effect /home/hc3/alchemy/runtime_registry /home/hc3/alchemy/oorexx_queue_fabric /home/hc3/alchemy/structured_relation_plugin /home/hc3/alchemy/nosqlserver /home/hc3/alchemy/oorexx_work_load_units "${REPUTATION_FEED_ROOT:-/home/hc3/alchemy/reputation_feed}"; do
  [[ -d "$d" ]] || { echo "FAIL REQUIRED_ROOT_MISSING root=$d"; exit 1; }
done

export HARDWORLD_ROOT=/home/hc3/alchemy/virtual_ryta_hardworld
export LEGAL_EFFECT_ROOT=/home/hc3/alchemy/legal_effect
export RUNTIME_REGISTRY_ROOT=/home/hc3/alchemy/runtime_registry
export QUEUE_FABRIC_ROOT=/home/hc3/alchemy/oorexx_queue_fabric
export STRUCTURED_RELATION_ROOT=/home/hc3/alchemy/structured_relation_plugin
export NOSQLSERVER_ROOT=/home/hc3/alchemy/nosqlserver
export WLU_ROOT=/home/hc3/alchemy/oorexx_work_load_units
export REPUTATION_EFFECT_ROOT="$REP_ROOT"
export REPUTATION_FEED_ROOT="${REPUTATION_FEED_ROOT:-/home/hc3/alchemy/reputation_feed}"

for test in test_shannon_reputation_gate.rex test_shannon_reputation_communication.rex test_shannon_reputation_feed.rex; do
  echo "== $test =="
  "$SHANNON_ROOT/run_rexx.sh" "$SHANNON_ROOT/tests/$test" "$SHANNON_ROOT"
done

echo 'PASS SHANNON_REPUTATION_V02_SOURCE_INTEGRATION'
