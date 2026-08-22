#!/usr/bin/env bash
set -euo pipefail

PKG_ROOT="$(cd "$(dirname "$0")" && pwd)"
SHANNON_ROOT="${SHANNON_ROOT:-/home/hc3/alchemy/ourladyair_shannon_v0.5}"
LIVE_REPUTATION_EFFECT_ROOT="${LIVE_REPUTATION_EFFECT_ROOT:-/home/hc3/alchemy/reputation_effect}"

for d in "$SHANNON_ROOT" "$LIVE_REPUTATION_EFFECT_ROOT" \
  /home/hc3/alchemy/virtual_ryta_hardworld \
  /home/hc3/alchemy/legal_effect \
  /home/hc3/alchemy/runtime_registry \
  /home/hc3/alchemy/oorexx_queue_fabric \
  /home/hc3/alchemy/structured_relation_plugin \
  /home/hc3/alchemy/nosqlserver \
  /home/hc3/alchemy/oorexx_work_load_units \
  /home/hc3/alchemy/reputation_feed; do
  [[ -d "$d" ]] || { echo "FAIL REQUIRED_ROOT_MISSING root=$d"; exit 1; }
done

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
STAGED="$tmp/reputation_effect"
cp -a "$LIVE_REPUTATION_EFFECT_ROOT" "$STAGED"

patch -d "$STAGED" -p0 < "$PKG_ROOT/patches/reputation_effect_src_v01_to_v02.patch"
patch -d "$STAGED" -p0 < "$PKG_ROOT/patches/reputation_runtime_v01_to_v02.patch"
printf '0.2\n' > "$STAGED/VERSION.txt"

echo '== staged reputation API =='
grep -nE 'constant (VERSION|API_VERSION)' "$STAGED/src/ReputationEffect.cls"
grep -n 'REPUTATION-EFFECT-V0.2' "$STAGED/runtime/ReputationRuntimeModule.cls"

export HARDWORLD_ROOT=/home/hc3/alchemy/virtual_ryta_hardworld
export LEGAL_EFFECT_ROOT=/home/hc3/alchemy/legal_effect
export RUNTIME_REGISTRY_ROOT=/home/hc3/alchemy/runtime_registry
export QUEUE_FABRIC_ROOT=/home/hc3/alchemy/oorexx_queue_fabric
export STRUCTURED_RELATION_ROOT=/home/hc3/alchemy/structured_relation_plugin
export NOSQLSERVER_ROOT=/home/hc3/alchemy/nosqlserver
export WLU_ROOT=/home/hc3/alchemy/oorexx_work_load_units
export REPUTATION_EFFECT_ROOT="$STAGED"
export REPUTATION_FEED_ROOT=/home/hc3/alchemy/reputation_feed

run_shannon_test() {
  local name="$1"
  echo "== $name =="
  "$SHANNON_ROOT/run_rexx.sh" "$SHANNON_ROOT/tests/$name" "$SHANNON_ROOT"
}

run_shannon_test test_shannon_reputation_gate.rex
run_shannon_test test_shannon_reputation_communication.rex
run_shannon_test test_shannon_reputation_feed.rex

echo 'PASS SHANNON_REPUTATION_V02_STAGED_INTEGRATION'
