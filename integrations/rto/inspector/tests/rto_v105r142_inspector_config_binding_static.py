#!/usr/bin/env python3
"""REX10: only configured trace requests may contribute installed-hook evidence.

These tests are adversarial *local evidence admission* tests. They cannot prove
that a remote ooRexx object was actually called or that a host signed a report.
"""
import hashlib
import importlib.util
import json
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MODULE = importlib.util.spec_from_file_location('rto_inspector_import', ROOT / 'tools/rto_inspector_import.py')
assert MODULE and MODULE.loader
inspector = importlib.util.module_from_spec(MODULE)
MODULE.loader.exec_module(inspector)


def write(path: Path, obj: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(obj, sort_keys=True) + '\n', encoding='utf-8')


def receipt(name: str = 'approved', source: str = 'approved.json') -> dict:
    return {
        'schema': inspector.RECEIPT_SCHEMA, 'trace_request': source,
        'status': 'loaded', 'loaded_rules': 1, 'classes': ['RTOCOMMAND'],
    }


def main() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp)
        live = root / 'live'
        live.mkdir()
        config_dir = root / inspector.TRACE_DIR
        config_dir.mkdir(parents=True)
        request = config_dir / 'approved.json'
        write(request, {'schema': 'alchemy.inspector.trace-request.v1', 'enabled': True,
                        'requests': [{'kind': 'method_trace', 'class': 'RTOCOMMAND', 'method': 'RUN'}]})
        expected = hashlib.sha256(request.read_bytes()).hexdigest()
        write(live / '.approved.receipt.json', receipt())
        ok = inspector.summarize_live(root, live)
        assert ok['ok'] and ok['receipt_stems'] == ['approved'], ok
        assert ok['configured_trace_sha256']['approved'] == expected
        assert ok['host_attestation'] == 'NOT_VERIFIED'
        assert 'UNATTESTED' in ok['receipt_binding']

        # Known filename is not enough: the source cannot be retargeted to /tmp.
        for bad in ('../approved.json', '/tmp/approved.json',
                    'other/approved.json', 'data/inspector-trace-requests/../approved.json'):
            write(live / '.approved.receipt.json', receipt(source=bad))
            result = inspector.summarize_live(root, live)
            assert not result['ok'] and not result['receipt_stems'], (bad, result)
        write(live / '.approved.receipt.json', receipt(source='data/inspector-trace-requests/approved.json'))
        assert inspector.summarize_live(root, live)['ok']

        # A previously unknown receipt cannot lend credibility to a new operation.
        write(live / '.unknown.receipt.json', receipt(name='unknown', source='unknown.json'))
        bad = inspector.summarize_live(root, live)
        assert not bad['ok'] and 'unknown' not in bad['receipt_stems'], bad
        (live / '.unknown.receipt.json').unlink()

        # Trace-load acknowledgements share the same project namespace boundary.
        write(live / 'rto-inspector-trace-request-loaded-001.json', {
            'schema': inspector.LOAD_SCHEMA, 'status': 'loaded', 'trace_request': '/tmp/approved.json'})
        bad = inspector.summarize_live(root, live)
        assert not bad['ok'] and not bad['loaded_trace_stems'], bad
        (live / 'rto-inspector-trace-request-loaded-001.json').unlink()

        # The inspected request itself cannot be a symlink, even with a valid body.
        request.unlink()
        external = root / 'external.json'
        write(external, {'schema': 'alchemy.inspector.trace-request.v1'})
        request.symlink_to(external)
        bad = inspector.summarize_live(root, live)
        assert not bad['ok'] and 'approved' not in bad['configured_trace_stems'], bad
        request.unlink()

        # Reject absent/invalid configuration instead of taking the receipt at face value.
        bad = inspector.summarize_live(root, live)
        assert not bad['ok'] and not bad['receipt_stems'], bad
        write(request, {'schema': 'something-else'})
        bad = inspector.summarize_live(root, live)
        assert not bad['ok'] and not bad['receipt_stems'], bad
    print('PASS RTO Inspector r142 configured-rule binding and provenance limits')


if __name__ == '__main__':
    main()