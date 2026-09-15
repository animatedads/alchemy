#!/usr/bin/env bash
set -euo pipefail
REXX=${REXX:-/usr/local/bin/rexx}
: "${CRYPTO_SRC:?}"
: "${WORK_BUNDLE_SRC:?}"
: "${ALLOCATOR_SRC:?}"
: "${QUEUE_SRC:?}"
: "${ALCHEMY_SRC:?}"
export REXX_PATH="$(cd "$(dirname "$0")/../src" && pwd):$WORK_BUNDLE_SRC:$ALLOCATOR_SRC:$QUEUE_SRC:$ALCHEMY_SRC:$CRYPTO_SRC${REXX_PATH:+:$REXX_PATH}"
cd "$(dirname "$0")"
"$REXX" test_managed_node.rex
"$REXX" test_result_retry.rex
"$REXX" test_personality_boundaries.rex
