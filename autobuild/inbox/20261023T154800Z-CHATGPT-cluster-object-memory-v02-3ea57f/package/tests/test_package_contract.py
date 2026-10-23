from pathlib import Path
root = Path(__file__).resolve().parents[1]
src = (root/'src'/'ClusterObjectMemoryFabricTransport.cls').read_text()
test = (root/'tests'/'test_memory_fabric_queue_transport.rex').read_text()
deps = (root/'DEPENDENCIES.json').read_text()
checks = {
    'api': 'cluster.object.peer/0.2' in src,
    'memory_api': 'memory.fabric/0.1' in deps,
    'memory_ref': 'MEMORY_REF_SCHEMA' in src,
    'move_uncertain': 'MOVE_UNCERTAIN' in src,
    'queue_transport': 'ClusterObjectQueueFabricClientTransport' in src,
    'resident_payload_exclusion': 'MOVE graph does not carry resident audio bytes' in test,
    'provider_reincarnation_fence': 'provider B reincarnated' in test,
}
failed=[k for k,v in checks.items() if not v]
if failed:
    raise SystemExit('FAIL package contract: '+', '.join(failed))
print('PASS package contract:', ', '.join(checks))
