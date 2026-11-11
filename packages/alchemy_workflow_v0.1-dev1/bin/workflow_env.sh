# workflow_env.sh - Alchemy Workflow v0.1-dev1: source this before running bin/workflow.rex.
#   . packages/alchemy_workflow_v0.1-dev1/bin/workflow_env.sh
# Sets REXX_PATH and LD_LIBRARY_PATH from the checkout this file sits in. Nothing outside the checkout is
# assumed, except REXXSQL_LIBDIR: a directory holding librexxsql.so, which KitRun (Body Slam) needs.
# Architecture: Tom Dyer. Written by: Claude (Opus 5.5), 2026-11-11.
_wf_here=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE:-$0}")/.." && pwd)
export ALCHEMY_ROOT="${ALCHEMY_ROOT:-$(CDPATH= cd -- "$_wf_here/../.." && pwd)}"
_p="$ALCHEMY_ROOT/packages"
export REXX_PATH="$_wf_here/src:$_wf_here/src/steps:$_p/oorexx_logging_v0.7/src:$_p/oorexx_crypto_v0.8.3/src:$_p/runtime_reference_v0.4/src:$_p/oorexx_foreign_runtime_v0.22.6/rexx:$_p/oorexx_slam_v0.1/src:$_p/oorexx_slam_v0.1/vendor/rx2cpp:$_p/oorexx_rexxsql_backend_v0.1/src:$_p/oorexx_native_database_backends_v0.1/src"
export LD_LIBRARY_PATH="$_p/oorexx_foreign_runtime_v0.22.6/build:$_p/oorexx_crypto_v0.8.3/native${REXXSQL_LIBDIR:+:$REXXSQL_LIBDIR}${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
unset _wf_here _p
