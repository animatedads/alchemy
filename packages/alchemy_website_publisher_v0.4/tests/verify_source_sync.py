#!/usr/bin/env python3
"""Verify the Publisher's GitHub-owned source against its checked-in provenance.

No network calls, native writer, browser, or publishing side effects.
"""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REPO = ROOT.parents[1]
MANIFEST = REPO / 'publication' / 'website_publisher_source_manifest.json'


def main():
    assert MANIFEST.is_file(), f'missing provenance: {MANIFEST}'
    manifest = json.loads(MANIFEST.read_text(encoding='utf-8'))
    assert manifest['schema'] == 'alchemy.website.publisher.github_import/0.1'
    paths = manifest['owned_paths']
    assert len(paths) == len(set(paths)) and len(paths) >= 19
    assert set(paths) == set(manifest['source_sha256'])
    for name, expected in manifest['source_sha256'].items():
        assert not Path(name).is_absolute() and '..' not in Path(name).parts, name
        actual = hashlib.sha256((ROOT / name).read_bytes()).hexdigest()
        assert actual == expected, f'source mismatch: {name}'
    for excluded in ('dependencies/nosqlserver_v0.90_sqlite_wal_read_write_candidate.zip',
                     'reference/rasenfalcon_website_builder_v0.1.zip',
                     'native_store_tmp'):
        assert not (ROOT / excluded).exists(), f'dependency/runtime content incorrectly published: {excluded}'
    sphere = REPO / 'spheres' / 'website_publisher_gopher_sphere_v0.1'
    assert (sphere / 'packs' / 'website-publisher' / '00-sphere.json').is_file()
    print(f'PASS Website Publisher source provenance ({len(paths)} files) and Gopher sphere boundary')


if __name__ == '__main__':
    main()
