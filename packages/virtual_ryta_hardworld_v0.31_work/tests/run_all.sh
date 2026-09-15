#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
for test_file in *.rex; do
    case "$test_file" in
        test_queue_authority_execution_v021.rex|\
        test_retained_authority_revalidation_v025.rex|\
        test_legal_v010_retained_authority_v025.rex|\
        test_queue_authority_lifetime_v026.rex|\
        test_legal_v010_authority_lifetime_v026.rex|\
        test_algorithm_relation_camera_integration.rex|\
        test_camera_nosql_v068_external_engine.rex|\
        mysql_wire_algrel_v068_external_server.rex|\
        mysql_wire_table_feed_v068_server.rex|\
        mysql_wire_algrel_v069_cursor_server.rex|\
        mysql_wire_algrel_v070_cursor_server.rex|\
        mysql_wire_structured_rich_v016_server.rex)
            # Environment/staging-dependent integration fixtures have dedicated runners.
            continue
            ;;
    esac
    echo "=== ${test_file} ==="
    rexx "${test_file}"
done

echo "=== static_guard_no_result_variable ==="
ROOT="$(cd .. && pwd)"
if grep -RInE '(^|[[:space:]])result[[:space:]]*=' "$ROOT" --include='*.cls' --include='*.rex'; then
    echo "STATIC GUARD FAILED: RESULT/result used as persistent local variable" >&2
    exit 1
fi
echo "STATIC GUARD NO RESULT VARIABLE: OK"


echo "=== static_guard_no_legacy_determinism ==="
ROOT="$(cd .. && pwd)"
if grep -RIn 'DETERMINISTIC_SNAPSHOT' "$ROOT" --include='*.cls' --include='*.rex'; then
    echo "STATIC GUARD FAILED: legacy DETERMINISTIC_SNAPSHOT claim remains" >&2
    exit 1
fi
echo "STATIC GUARD NO LEGACY DETERMINISM: OK"

echo "=== librarian_salvage_delta ==="
python3 test_librarian_salvage_delta.py
python3 test_librarian_hardened_core_audit.py
python3 test_librarian_assertion_contract.py

echo "=== librarian_special_variable_audit ==="
python3 test_librarian_special_variable_audit.py


echo "=== static_guard_no_global_nosql_transport_classes ==="
ADAPTER="$ROOT/integration/NoSQLServerAlgorithmRelationExternalEngine.cls"
if grep -nE '\.(DatabaseTableMetadata|DatabaseRow|DatabaseResult|TableDefinition)' "$ADAPTER"; then
    echo "STATIC GUARD FAILED: external adapter directly references host NoSQLServer transport class" >&2
    exit 1
fi
echo "STATIC GUARD NO GLOBAL NOSQL TRANSPORT CLASSES: OK"

echo "=== static_guard_no_global_legal_verification_snapshot_class ==="
for LEGAL_ADAPTER in "$ROOT/integration/LegalEffectV06PromotionAdapter.cls" "$ROOT/integration/LegalEffectV07PromotionAdapter.cls"; do
    if grep -nE '\.LegalVerificationEvidenceSnapshot' "$LEGAL_ADAPTER"; then
        echo "STATIC GUARD FAILED: legal adapter constructs upstream verification snapshot by global class name: $LEGAL_ADAPTER" >&2
        exit 1
    fi
done
echo "STATIC GUARD NO GLOBAL LEGAL VERIFICATION SNAPSHOT CLASS: OK"

echo "=== static_guard_v07_runtime_not_authority ==="
LEGAL_V07_ADAPTER="$ROOT/integration/LegalEffectV07PromotionAdapter.cls"
if grep -nE "authority[[:space:]]*=.*(artifactId|generationState|runtimeEvidence)" "$LEGAL_V07_ADAPTER"; then
    echo "STATIC GUARD FAILED: Runtime Registry provenance appears in v0.7 legal authority construction" >&2
    exit 1
fi
if ! grep -q "LEGAL_EFFECT/0.7/" "$LEGAL_V07_ADAPTER"; then
    echo "STATIC GUARD FAILED: native v0.7 authority namespace missing" >&2
    exit 1
fi
echo "STATIC GUARD V0.7 RUNTIME NOT LEGAL AUTHORITY: OK"
