#!/bin/sh
set -eu
: "${GOPHER:?GOPHER must name an installed LLM Gopher executable}"
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
# The runner must provide profile/PACKS resolution; no claim of local Gopher availability.
cd "$root"
"$GOPHER" --profile rpc-invocation context rpc-invocation --full
"$GOPHER" --profile rpc-invocation search registry --sphere rpc-invocation
