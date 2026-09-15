#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
export REXX_PATH="$ROOT/packages/alchemy_autobuild_service_v0.4/src:$ROOT/packages/alchemy_inbox_v0.3/src:$ROOT/packages/alchemy_autobuild_evidence_v0.3/src:$ROOT/packages/alchemy_orchestrator_v0.5/src:$ROOT/packages/alchemy_publisher_v0.4/src:$ROOT/packages/alchemy_executor_v0.4/src:$ROOT/packages/alchemy_dependency_floor_v0.5/src:$ROOT/packages/alchemy_package_model_v0.3/src:$ROOT/packages/alchemy_transport_v0.4/src:$ROOT/packages/alchemy_repository_lease_v0.2/src:$ROOT/packages/alchemy_core_component_v0.1/src:$ROOT/packages/alchemy_objects_v0.4.3/src:$ROOT/packages/oorexx_crypto_v0.1/src${REXX_PATH:+:$REXX_PATH}"
exec rexx "$ROOT/install_runtime.rex" "$@"
