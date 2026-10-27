#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
PATH_SEP=:

find_rexx_path_file() {
  wanted=$1
  oldifs=$IFS
  IFS=$PATH_SEP
  for dir in ${REXX_PATH:-}; do
    [ -n "$dir" ] || continue
    if [ -f "$dir/$wanted" ]; then
      IFS=$oldifs
      return 0
    fi
  done
  IFS=$oldifs
  return 1
}

command -v rexx >/dev/null 2>&1 || { echo "FAIL rexx not found" >&2; exit 1; }
command -v rexxc >/dev/null 2>&1 || { echo "FAIL rexxc not found" >&2; exit 1; }

for required in InstrumentationMesh.cls InstrumentationAnalysis.cls InstrumentationServiceAdapters.cls InstrumentationRelationshipAdapters.cls InstrumentationCorrelation.cls; do
  [ -f "$ROOT/src/$required" ] || { echo "FAIL internal source missing: $required" >&2; exit 1; }
done

# Full estate qualification dependencies are explicit and fail closed.  The
# package core itself does not require them at runtime.
for required in ObjectQueueFabric.cls ObjectQueueChannels.cls MemoryFabric.cls StorageFabric.cls RexxOSGridInstrumentation.cls RexxOSGridEstateController.cls IdentityPeerFabric.cls ManagementRelationships.cls SmtpCore.cls StorageInstrumentationMesh.cls; do
  if ! find_rexx_path_file "$required"; then
    echo "FAIL unresolved qualification dependency: $required" >&2
    exit 1
  fi
done

for source in "$ROOT"/src/*.cls "$ROOT"/tests/*.rex; do
  rexxc "$source" >/dev/null
done

cd "$ROOT"
rexx tests/test_instrumentation_mesh.rex
rexx tests/test_publication_collector.rex
rexx tests/test_dimensions_and_analysis.rex
rexx tests/test_freshness_and_gauges.rex
rexx tests/test_operation_observer.rex
rexx tests/test_registry_source_shapes.rex
rexx tests/test_smtp_service_adapter.rex
rexx tests/test_fabric_adapters.rex
rexx tests/test_queue_rexx_binding.rex
rexx tests/test_relationship_collector.rex
rexx tests/test_event_timeline.rex
rexx tests/test_correlation_view.rex
rexx tests/test_storage_dev3_event_path.rex
rexx tests/test_relationship_adapters.rex
rexx tests/test_rto_relationship_adapter.rex

echo "PASS oorexx-instrumentation-mesh 0.1-dev8 qualification"
