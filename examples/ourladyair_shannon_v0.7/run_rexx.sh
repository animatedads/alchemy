#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
: "${HARDWORLD_ROOT:?set HARDWORLD_ROOT to the HardWorld package root}"
: "${LEGAL_EFFECT_ROOT:?set LEGAL_EFFECT_ROOT to the Legal Effect package root}"
: "${RUNTIME_REGISTRY_ROOT:?set RUNTIME_REGISTRY_ROOT to the Runtime Registry package root}"
: "${QUEUE_FABRIC_ROOT:?set QUEUE_FABRIC_ROOT to the Queue Fabric package root}"
: "${STRUCTURED_RELATION_ROOT:?set STRUCTURED_RELATION_ROOT to the Structured Relation package root}"
: "${NOSQLSERVER_ROOT:?set NOSQLSERVER_ROOT to the NoSQLServer package root}"
: "${WLU_ROOT:?set WLU_ROOT to the Work Load Units package root}"

if (($# < 1)); then
  echo "usage: $0 SCRIPT [ARGS...]" >&2
  exit 2
fi
SCRIPT="$1"
shift
if [[ "$SCRIPT" != /* ]]; then SCRIPT="$ROOT/$SCRIPT"; fi

export REXX_PATH="$ROOT/src:$HARDWORLD_ROOT:$HARDWORLD_ROOT/integration:$HARDWORLD_ROOT/algorithm:$LEGAL_EFFECT_ROOT/src:$RUNTIME_REGISTRY_ROOT/src:$QUEUE_FABRIC_ROOT/src:$STRUCTURED_RELATION_ROOT/src:$NOSQLSERVER_ROOT/src:$WLU_ROOT/src${REXX_PATH:+:$REXX_PATH}"

# HardWorld v0.19's upstream LegalEffectPromotionAdapter has deliberate relative
# ::REQUIRES to ../algorithm. Run from integration/ so the unmodified upstream
# adapter resolves its own package layout; Shannon does not vendor or rewrite it.
cd "$HARDWORLD_ROOT/integration"
exec rexx "$SCRIPT" "$@"
