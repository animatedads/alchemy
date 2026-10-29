from pathlib import Path
src = (Path(__file__).resolve().parents[1] / 'src' / 'ClusterObjectXtpQueueBinding.cls').read_text()
checks = {
    'api': 'cluster.object.xtp-binding/0.1' in src,
    'cluster_api': 'cluster.object.peer/0.2' in src,
    'protected_wire': '.QueueXtpSessionWire~new' in src,
    'durable_receipt_gate': '.QueueXtpReceiptGate~new' in src,
    'queue_channel': '.QueueChannelFabric~new' in src,
    'existing_cluster_client': '.ClusterObjectQueueFabricClientTransport~new' in src,
    'route_provider_fence': 'MEMORY_PROVIDER_ROUTE_MISMATCH' in src,
    'default_deny': 'ClusterObjectXtpDenyReadiness' in src and "lastFailure='XTP_ROUTE_NOT_READY'" in src,
    'no_clear_fallback': 'REQUIRED_PROTECTION "encrypt"' in src,
    'no_payload_materialise': 'materializeAll' not in src and 'materialiseAll' not in src,
    'move_uncertain_delegate': 'QUEUE_XTP_REQUEST_UNCERTAIN' in src,
}
failed = [k for k,v in checks.items() if not v]
if failed:
    raise SystemExit('FAIL: ' + ', '.join(failed))
print('PASS static contract:', ', '.join(checks))
