#!/usr/bin/env python3
"""Read-only RX2CPP upstream tree comparison. Never promotes a pin.

Input snapshots contain Git tree entry SHA identifiers, NOT a certificate that
GitHub or a local checkout was consulted. The caller must retain provenance.
"""
from __future__ import annotations
import argparse
import json
from pathlib import Path
import re

API = 'plan42.rx2cpp.upstream-audit/0.1'
HEX = re.compile(r'^[0-9a-f]{40}$')


def audit(pin: dict, candidate: dict) -> dict:
    required = pin.get('required_interfaces')
    revision = pin.get('observed_commit')
    assertive = {'promoted': False, 'executed': False, 'published': False,
                 'native_qualification': 'NOT_RUN', 'pin_changed': False}
    if (not isinstance(required, list) or len(required) != 7 or
        len(set(required)) != len(required) or
        not all(isinstance(x, str) and x.startswith('oorexx2cpp/') and '..' not in Path(x).parts for x in required) or
        not isinstance(revision, str) or not HEX.fullmatch(revision)):
        return {'schema': API, 'ok': False, 'status': 'PIN_INVALID', **assertive}
    if (not isinstance(candidate, dict) or candidate.get('repository') != pin.get('repository') or
        not isinstance(candidate.get('commit'), str) or not HEX.fullmatch(candidate['commit']) or
        candidate.get('compiler_version') != pin.get('version') or
        not isinstance(candidate.get('blobs'), dict)):
        return {'schema': API, 'ok': False, 'status': 'SNAPSHOT_INVALID', **assertive}
    blobs = candidate['blobs']
    if set(blobs) != set(required) or not all(isinstance(v, str) and HEX.fullmatch(v) for v in blobs.values()):
        return {'schema': API, 'ok': False, 'status': 'INTERFACES_INCOMPLETE', **assertive}
    previous = candidate.get('baseline_blobs', {})
    if set(previous) != set(required) or not all(isinstance(v, str) and HEX.fullmatch(v) for v in previous.values()):
        return {'schema': API, 'ok': False, 'status': 'BASELINE_INCOMPLETE', **assertive}
    if candidate.get('baseline_commit') != revision:
        return {'schema': API, 'ok': False, 'status': 'BASELINE_MISMATCH', **assertive}
    changed = sorted(x for x in required if previous[x] != blobs[x])
    unchanged = sorted(x for x in required if previous[x] == blobs[x])
    return {'schema': API, 'ok': True,
            'status': 'REVIEW_REQUIRED' if candidate['commit'] != revision else 'PIN_UNCHANGED',
            'repository': pin['repository'], 'pinned_commit': revision,
            'candidate_commit': candidate['commit'], 'compiler_version': pin['version'],
            'changed_interfaces': changed, 'unchanged_interfaces': unchanged,
            'interface_count': len(required),
            'snapshot_authenticity': 'NOT_ATTESTED_BY_THIS_TOOL',
            'decision': 'NO_AUTO_REPIN', **assertive}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--pin', required=True)
    parser.add_argument('--snapshot', required=True)
    args = parser.parse_args()
    try:
        value = audit(json.loads(Path(args.pin).read_text()), json.loads(Path(args.snapshot).read_text()))
    except (OSError, ValueError, TypeError) as exc:
        value = {'schema': API, 'ok': False, 'status': 'INPUT_REFUSED',
                 'reason': str(exc), 'promoted': False, 'executed': False, 'published': False}
    print(json.dumps(value, indent=2, sort_keys=True))
    return 0 if value['ok'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
