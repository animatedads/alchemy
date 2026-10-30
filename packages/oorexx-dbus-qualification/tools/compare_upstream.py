#!/usr/bin/env python3
"""Content diff of two ZIP source snapshots after bounded archive preflight.

Never extracts files or executes archived code. Paths compare exactly: an added
wrapper directory appears as a path change, not silently as source equality.
"""
import argparse
import hashlib
import json
import pathlib
import sys
import zipfile

from audit_archive import audit


def inventory(path, **limits):
    path = pathlib.Path(path)
    structural = audit(path, **limits)
    if structural['status'] != 'PASS':
        raise ValueError(f'Unsafe/invalid archive {path}: {structural["findings"]}')
    files = {}
    with zipfile.ZipFile(path) as z:
        for entry in z.infolist():
            if entry.is_dir():
                continue
            digest = hashlib.sha256()
            with z.open(entry) as stream:
                while chunk := stream.read(65536):
                    digest.update(chunk)
            files[entry.filename.replace('\\', '/')] = {
                'sha256': digest.hexdigest(), 'size': entry.file_size}
    digest = hashlib.sha256()
    with path.open('rb') as stream:
        while chunk := stream.read(65536):
            digest.update(chunk)
    return {'sha256': digest.hexdigest(), 'files': files}


def compare(old_path, new_path, **limits):
    old, new = inventory(old_path, **limits), inventory(new_path, **limits)
    before, after = old['files'], new['files']
    return {'schema': 'org.alchemy.dbus.upstream-comparison/0.2',
            'basis': 'ARCHIVE_CONTENT_DIFF_ONLY',
            'historical_sha256': old['sha256'], 'candidate_sha256': new['sha256'],
            'added': sorted(after.keys() - before.keys()),
            'removed': sorted(before.keys() - after.keys()),
            'changed': sorted(k for k in before.keys() & after.keys() if before[k] != after[k]),
            'unchanged': sorted(k for k in before.keys() & after.keys() if before[k] == after[k]),
            'native_qualification': 'NOT_ASSESSED'}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('historical_zip', type=pathlib.Path)
    parser.add_argument('candidate_zip', type=pathlib.Path)
    parser.add_argument('--out', type=pathlib.Path)
    args = parser.parse_args()
    try:
        report = compare(args.historical_zip, args.candidate_zip)
    except (OSError, ValueError, zipfile.BadZipFile) as exc:
        print(json.dumps({'status': 'FAIL', 'reason': str(exc)}), file=sys.stderr)
        return 1
    result = json.dumps(report, indent=2, sort_keys=True) + '\n'
    if args.out:
        args.out.write_text(result, encoding='utf-8')
    print(result, end='')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
