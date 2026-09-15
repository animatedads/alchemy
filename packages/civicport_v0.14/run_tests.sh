#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"

# Interpreter resolution is explicit but installation-prefix neutral.
# - REXX may name an exact executable.
# - OOREXX_ROOT may name a non-standard installation prefix.
# - otherwise use the rexx visible in PATH (for example /usr/bin/rexx).
if [[ -n "${REXX:-}" ]]; then
  REXX_BIN="$REXX"
elif [[ -n "${OOREXX_ROOT:-}" ]]; then
  REXX_BIN="$OOREXX_ROOT/bin/rexx"
elif command -v rexx >/dev/null 2>&1; then
  REXX_BIN="$(command -v rexx)"
elif [[ -x /usr/local/bin/rexx ]]; then
  REXX_BIN="/usr/local/bin/rexx"
else
  echo "ooRexx executable not found; set REXX or OOREXX_ROOT, or place rexx in PATH" >&2
  exit 2
fi

if [[ ! -x "$REXX_BIN" ]]; then
  echo "ooRexx executable not executable: $REXX_BIN" >&2
  exit 2
fi

REXX="$REXX_BIN"
REXX_DIR="$(cd "$(dirname "$REXX")" && pwd)"
export PATH="$REXX_DIR:$PATH"
if [[ -n "${OOREXX_ROOT:-}" && -d "$OOREXX_ROOT/lib" ]]; then
  export LD_LIBRARY_PATH="$OOREXX_ROOT/lib:${LD_LIBRARY_PATH:-}"
fi
ALCHEMY_OBJECTS_ROOT="${ALCHEMY_OBJECTS_ROOT:-}"
OOREXX_CRYPTO_ROOT="${OOREXX_CRYPTO_ROOT:-}"
if [[ -z "$ALCHEMY_OBJECTS_ROOT" || ! -f "$ALCHEMY_OBJECTS_ROOT/src/AlchemyObject.cls" ]]; then
  echo "Alchemy Objects root not found; set ALCHEMY_OBJECTS_ROOT to a compatible Alchemy Objects package (v0.4.3 or later)" >&2
  exit 2
fi
if [[ -z "$OOREXX_CRYPTO_ROOT" || ! -f "$OOREXX_CRYPTO_ROOT/src/crypto.cls" ]]; then
  echo "ooRexx crypto root not found; set OOREXX_CRYPTO_ROOT to a compatible ooRexx Crypto package (v0.1 or later)" >&2
  exit 2
fi
export REXX_PATH="$REXX_DIR:$HERE/src:$HERE/tests:$ALCHEMY_OBJECTS_ROOT/src:$OOREXX_CRYPTO_ROOT/src${REXX_PATH:+:$REXX_PATH}"
cd "$HERE/tests"
"$HERE/tests/test_runtime_dependency_guard.sh"
"$HERE/tests/test_queue_boundary_v012.sh"
"$HERE/tests/test_notam_boundary_v013.sh"
"$HERE/tests/test_notam_surface_boundary_v014.sh"
if [[ -n "${RUNTIME_REGISTRY_ROOT:-}" ]]; then
  "$HERE/tests/check_runtime_registry_root.sh" "$RUNTIME_REGISTRY_ROOT" "0.14"
fi
"$REXX" test_alchemy_base_v08.rex
"$REXX" test_allowlist.rex
"$REXX" test_document_fixture.rex
"$REXX" test_json_decode.rex
"$REXX" test_json_pointer.rex
"$REXX" test_query_template_v010.rex
"$REXX" test_postcode_mapping.rex
"$REXX" test_company_mapping_v09.rex
"$REXX" test_metar_mapping_v010.rex
"$REXX" test_catalog_v011.rex
"$REXX" test_catalog_negotiation_v011.rex
"$REXX" test_credentials_v09.rex
"$REXX" test_companies_house_sandbox_v013.rex
"$REXX" test_redirect_document.rex
"$REXX" test_curl_transport_fake.rex
"$REXX" test_failure_boundaries.rex
"$REXX" test_cache_key.rex
"$REXX" test_cache_user_agent_v010.rex
"$REXX" test_cache_credential_v09.rex
"$REXX" test_cache_boundaries.rex
"$REXX" test_etag_revalidation.rex
"$REXX" test_cache_refresh.rex
"$REXX" test_cache_stale.rex
"$REXX" test_rate_limit_stale.rex
"$REXX" test_access_state_v07.rex
"$REXX" test_queue_journal_v012.rex
"$REXX" test_journal_recovery.rex
"$REXX" test_journal_v08_compat_v09.rex
"$REXX" test_journal_integrity.rex
"$REXX" test_journal_orphan_skip.rex
"$REXX" test_304_without_entity.rex
"$REXX" test_json_number_journal.rex
"$REXX" test_capabilities_v03.rex
"$REXX" test_capabilities_v04.rex
"$REXX" test_capabilities_v05.rex
"$REXX" test_capabilities_v07.rex
"$REXX" test_capabilities_v08.rex
"$REXX" test_capabilities_v09.rex
"$REXX" test_capabilities_v010.rex
"$REXX" test_capabilities_v011.rex
"$REXX" test_capabilities_v012.rex
"$REXX" test_capabilities_v013.rex
"$REXX" test_capabilities_v014.rex
if [[ -n "${STRUCTURED_RELATION_ROOT:-}" ]]; then
  if [[ ! -f "$STRUCTURED_RELATION_ROOT/src/XmlNativeSource.cls" ]]; then
    echo "Structured Relation root invalid: $STRUCTURED_RELATION_ROOT (missing src/XmlNativeSource.cls)" >&2
    exit 2
  fi
  export REXX_PATH="$REXX_PATH:$STRUCTURED_RELATION_ROOT/src"
fi
if [[ -n "${RUNTIME_REGISTRY_ROOT:-}" ]]; then
  export REXX_PATH="$REXX_PATH:$RUNTIME_REGISTRY_ROOT/src"
  "$REXX" test_runtime_contract_v08.rex
  "$REXX" test_runtime_registry_pin_v012.rex
  "$REXX" test_runtime_company_v09.rex
  "$REXX" test_runtime_company_sandbox_v013.rex
  "$REXX" test_runtime_metar_v010.rex
  "$REXX" test_catalog_runtime_v011.rex
  if [[ -n "${STRUCTURED_RELATION_ROOT:-}" ]]; then
    "$REXX" test_runtime_notam_v014.rex
  else
    echo "SKIP NOTAM Runtime contract integration (also set STRUCTURED_RELATION_ROOT)"
  fi
else
  echo "SKIP Runtime Registry API-contract integration (set RUNTIME_REGISTRY_ROOT; v0.14 targets v0.14)"
fi
if [[ -n "${NOSQLSERVER_ROOT:-}" ]]; then
  export REXX_PATH="$REXX_PATH:$NOSQLSERVER_ROOT/src:$NOSQLSERVER_ROOT/tests"
  "$REXX" test_relation_nosql_v074.rex
  "$REXX" test_relation_invalid_v074.rex
  "$REXX" test_relation_revalidated_v074.rex
  "$REXX" test_relation_degraded_v075.rex
  "$REXX" test_relation_company_v077.rex
  "$REXX" test_relation_company_sandbox_v013.rex
  "$REXX" test_relation_metar_v077.rex
  if [[ -n "${STRUCTURED_RELATION_ROOT:-}" ]]; then
    "$REXX" test_relation_notam_v014.rex
  else
    echo "SKIP NOTAM relation integration (also set STRUCTURED_RELATION_ROOT)"
  fi
else
  echo "SKIP NoSQLServer relation integration (set NOSQLSERVER_ROOT; v0.14 validated with v0.79)"
fi
if [[ -n "${HARDWORLD_ROOT:-}" ]]; then
  export REXX_PATH="$REXX_PATH:$HARDWORLD_ROOT:$HARDWORLD_ROOT/algorithm:$HARDWORLD_ROOT/integration"
  "$REXX" test_alchemy_base_hardworld_v07.rex
  "$REXX" test_hardworld_observation_v019.rex
  "$REXX" test_civic_observation_invalid_v019.rex
  "$REXX" test_civic_promotion_v019.rex
  "$REXX" test_civic_numeric_promotion_v019.rex
  "$REXX" test_civic_promotion_conflict_v019.rex
  "$REXX" test_civic_revalidated_promotion_v019.rex
  "$REXX" test_civic_stale_promotion_guard_v019.rex
  "$REXX" test_civic_access_hardworld_v023.rex
  "$REXX" test_company_hardworld_v09.rex
  "$REXX" test_metar_hardworld_v010.rex
else
  echo "SKIP HardWorld promotion integration (set HARDWORLD_ROOT; v0.14 validated with v0.31 work)"
fi
if [[ -n "${STRUCTURED_RELATION_ROOT:-}" ]]; then
  if [[ ! -f "$STRUCTURED_RELATION_ROOT/src/XmlNativeSource.cls" ]]; then
    echo "Structured Relation root invalid: $STRUCTURED_RELATION_ROOT (missing src/XmlNativeSource.cls)" >&2
    exit 2
  fi
  export REXX_PATH="$REXX_PATH:$STRUCTURED_RELATION_ROOT/src"
  "$REXX" test_swim_xml_v012.rex
  "$REXX" test_notam_runway_closure_v013.rex
  "$REXX" test_notam_fail_closed_v013.rex
  "$REXX" test_notam_journal_v014.rex
else
  echo "SKIP SWIM rich-XML integration (set STRUCTURED_RELATION_ROOT; v0.14 validated with Structured Relation v0.9)"
fi
if [[ -n "${QUEUE_FABRIC_ROOT:-}" || -n "${JMS_QUEUE_BRIDGE_ROOT:-}" ]]; then
  if [[ -z "${QUEUE_FABRIC_ROOT:-}" || -z "${JMS_QUEUE_BRIDGE_ROOT:-}" ]]; then
    echo "Queue ingress requires both QUEUE_FABRIC_ROOT and JMS_QUEUE_BRIDGE_ROOT" >&2
    exit 2
  fi
  if [[ ! -f "$QUEUE_FABRIC_ROOT/src/ObjectQueueFabric.cls" ]]; then
    echo "Queue Fabric root invalid: $QUEUE_FABRIC_ROOT (missing src/ObjectQueueFabric.cls)" >&2
    exit 2
  fi
  if [[ ! -f "$JMS_QUEUE_BRIDGE_ROOT/src/JMSQueueBridge.cls" ]]; then
    echo "JMS Queue Bridge root invalid: $JMS_QUEUE_BRIDGE_ROOT (missing src/JMSQueueBridge.cls)" >&2
    exit 2
  fi
  if ! grep -q '::constant VERSION "0.1-dev7-fb1"' "$JMS_QUEUE_BRIDGE_ROOT/src/JMSQueueBridge.cls"; then
    echo "JMS Queue Bridge dependency error: CivicPort v0.14 requires consolidated bridge 0.1-dev7-fb1" >&2
    exit 2
  fi
  if [[ ! -f "$JMS_QUEUE_BRIDGE_ROOT/src/JMSQueueBridgeSecrets.cls" ]]; then
    echo "JMS Queue Bridge dependency error: missing Secret Broker credential adapter JMSQueueBridgeSecrets.cls" >&2
    exit 2
  fi
  export REXX_PATH="$REXX_PATH:$QUEUE_FABRIC_ROOT/src:$JMS_QUEUE_BRIDGE_ROOT/src"
  "$REXX" test_queue_ingress_v012.rex
  if [[ -n "${STRUCTURED_RELATION_ROOT:-}" ]]; then
    "$REXX" test_swim_queue_end_to_end_v012.rex
    "$REXX" test_swim_notam_end_to_end_v013.rex
  else
    echo "SKIP SWIM queue end-to-end integration (also set STRUCTURED_RELATION_ROOT)"
  fi
else
  echo "SKIP Queue Fabric/JMS bridge ingress integration (set QUEUE_FABRIC_ROOT and JMS_QUEUE_BRIDGE_ROOT)"
fi
"$REXX" test_live_optional.rex
"$REXX" test_companies_house_live_optional.rex
"$REXX" test_companies_house_sandbox_live_optional.rex
"$REXX" test_aviationweather_live_optional.rex
