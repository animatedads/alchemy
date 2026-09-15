#!/usr/bin/env bash
set -euo pipefail
REXX=${REXX:-/usr/local/bin/rexx}
: "${PROFILE_SRC:?}"
: "${MANAGED_NODE_SRC:?}"
: "${WORK_BUNDLE_SRC:?}"
: "${ALLOCATOR_SRC:?}"
: "${QUEUE_SRC:?}"
: "${ALCHEMY_SRC:?}"
: "${CRYPTO_SRC:?}"
export REXX_PATH="$PROFILE_SRC:$MANAGED_NODE_SRC:$WORK_BUNDLE_SRC:$ALLOCATOR_SRC:$QUEUE_SRC:$ALCHEMY_SRC:$CRYPTO_SRC${REXX_PATH:+:$REXX_PATH}"
cd "$(dirname "$0")"
"$REXX" test_profile.rex
