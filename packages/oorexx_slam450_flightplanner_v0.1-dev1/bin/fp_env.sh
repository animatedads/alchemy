# fp_env.sh - SLAM 450 Flight Planner: source this before running any planner tool.
#   . packages/oorexx_slam450_flightplanner_v0.1-dev1/bin/fp_env.sh
# Sets REXX_PATH, LD_LIBRARY_PATH and the API Client settings from the
# checkout this file sits in; nothing outside the checkout is assumed.
# Architecture: Tom Dyer. Written by: Claude (Opus 5.5), 2026-11-07.
_fp_here=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE:-$0}")/.." && pwd)
export ALCHEMY_ROOT="${ALCHEMY_ROOT:-$(CDPATH= cd -- "$_fp_here/../.." && pwd)}"
_p="$ALCHEMY_ROOT/packages"
export FP_HOME="$_fp_here"
export FP_NODE="${FP_NODE:-$(hostname 2>/dev/null)}"
export FP_API_BRIDGE="${FP_API_BRIDGE:-$_p/oorexx_api_client_v0.4.1/bridge}"
export FP_CA_FILE="${FP_CA_FILE:-/etc/ssl/certs/ca-certificates.crt}"
export REXX_PATH="$_fp_here/src:$_fp_here/tools:$_p/oorexx_api_client_v0.4.1/src:$_p/oorexx_foreign_runtime_v0.22.6/rexx:$_p/oorexx_crypto_v0.8.3/src:$_p/runtime_reference_v0.4/src:$_p/oorexx_moonsault_v0.1/src:$_p/oorexx_maths/rexx:$_p/oorexx_logging_v0.7/src${REXX_PATH:+:$REXX_PATH}"
export LD_LIBRARY_PATH="$_p/oorexx_foreign_runtime_v0.22.6/build:$_p/oorexx_crypto_v0.8.3/native:$FP_API_BRIDGE${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
unset _fp_here _p
