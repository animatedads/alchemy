#!/usr/bin/env bash
set -euo pipefail
REXX_BIN="${REXX_BIN:-rexx}"
cd "$(dirname "$0")/.."
for t in \
  tests/test_capacity_domains.rex \
  tests/test_catalogue.rex \
  tests/test_transfer_safety.rex \
  tests/test_disposable_lifecycle.rex \
  tests/test_locality_placement.rex \
  tests/test_node_inventory.rex \
  tests/test_fleet_placement_matrix.rex \
  tests/test_provider_contracts.rex \
  tests/test_posix_probe.rex \
  tests/test_local_scan.rex \
  tests/test_namespace_views.rex \
  tests/test_route_write_semantics.rex \
  tests/test_environment_overlays.rex \
  tests/test_namespace_inheritance_list.rex \
  tests/test_removable_provider.rex \
  tests/test_alias_views.rex \
  tests/test_union_search_path.rex \
  tests/test_environment_journal.rex \
  tests/test_streaming_transfer.rex \
  tests/test_streaming_checkpoint.rex \
  tests/test_google_drive_protocol.rex \
  tests/test_google_drive_http_adapter.rex \
  tests/test_google_drive_streaming_sink.rex \
  tests/test_google_drive_resume_reconcile.rex
do
  "$REXX_BIN" "$t"
done
if [[ -n "${STORAGE_API_CLIENT_SRC:-}" ]]; then
  REXX_PATH="${STORAGE_API_CLIENT_SRC}${REXX_PATH:+:${REXX_PATH}}" "$REXX_BIN" tests/test_api_client_bridge.rex
  echo "PASS optional Storage -> API Client bridge"
fi
echo "PASS ALL STORAGE FABRIC v0.1-dev7 CORE TESTS"
