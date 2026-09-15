#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
export REXX_PATH="$ROOT/packages/alchemy_transport_v0.4/src:$ROOT/packages/alchemy_repository_lease_v0.2/src:$ROOT/packages/alchemy_core_component_v0.1/src:$ROOT/packages/alchemy_objects_v0.4.3/src:$ROOT/packages/oorexx_crypto_v0.1/src${REXX_PATH:+:$REXX_PATH}"
exec rexx "$ROOT/install_core.rex" "$@"
