# env.sh - paths for the WordNet store. Source it: . wordnet/env.sh
# ALCHEMY_REPO_ROOT points at a checkout of animatedads/alchemy.
# Architecture: Tom Dyer. Code: Claude (Opus 5.5).
HERE=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE:-$0}")" && pwd)
: "${ALCHEMY_REPO_ROOT:?set ALCHEMY_REPO_ROOT to your animatedads/alchemy checkout}"
P="$ALCHEMY_REPO_ROOT/packages"
export REXX_PATH="$HERE:$P/oorexx_native_database_backends_v0.1/src:$P/oorexx_rexxsql_backend_v0.1/src:$P/oorexx_reasoned_thought_v0.1/src${REXX_PATH:+:$REXX_PATH}"
export LD_LIBRARY_PATH="$HERE/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
