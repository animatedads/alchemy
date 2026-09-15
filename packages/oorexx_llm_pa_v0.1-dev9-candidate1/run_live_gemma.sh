#!/usr/bin/env bash
set -euo pipefail
: "${REXX:=rexx}"
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
if [[ -n "${REXX_PATH:-}" ]]; then
  export REXX_PATH="$script_dir/src:$REXX_PATH"
else
  export REXX_PATH="$script_dir/src"
fi
"$REXX" tests/test_live_gemma.rex
