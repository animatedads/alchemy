#!/usr/bin/env python3
"""Offline, dependency-free TZif snapshot publisher and verifier.

Does not reinterpret TZif, change time rules, modify the host clock, or dispatch events.
Provides SHA-256 package verification. The ooRexx loader uses a separate Adler32
consistency check and must not advertise that check as cryptographic authentication.
"""
from __future__ import annotations

import argparse
import hashlib
import os
from pathlib import Path
import re
import shutil
import sys
import tempfile
import zlib

MAGIC = 'SINGLE_TIME_TZIF_V1'
ZONE_RE = re.compile(r'^[A-Za-z0-9._+\-]+(?:/[A-Za-z0-9._+\-]+)*$')
SNAP_RE = re.compile(r'^[A-Za-z0-9_+\-.]{1,80}$')
EDITION_RE = re.compile(r'^[A-Za-z0-9_+\-.]{1,80}$')
MAX_TZIF = 16 * 1024 * 1024

class SnapshotError(ValueError):
    pass


def valid_zone(value: str) -> str:
    if not ZONE_RE.fullmatch(value) or any(s in ('', '.', '..') for s in value.split('/')):
        raise SnapshotError('invalid zone identifier: ' + repr(value))
    return value


def valid_snapshot(value: str) -> str:
    if not SNAP_RE.fullmatch(value) or value in ('.', '..'):
        raise SnapshotError('invalid snapshot identifier')
    return value


def valid_edition(value: str) -> str:
    if not EDITION_RE.fullmatch(value) or value in ('.', '..'):
        raise SnapshotError('invalid tzdb edition')
    return value


def digest(data: bytes):
    return len(data), hashlib.sha256(data).hexdigest(), f'{zlib.adler32(data):08X}'


def secure_bytes(path: Path, trust_root: Path, *, may_link: bool = False) -> bytes:
    resolved = path.resolve(strict=True)
    if not resolved.is_relative_to(trust_root.resolve(strict=True)):
        raise SnapshotError('source escapes declared trusted root')
    if (path.is_symlink() and not may_link) or not resolved.is_file():
        raise SnapshotError('snapshot file must be a regular file (no symbolic link)')
    size = resolved.stat().st_size
    if size < 44 or size > MAX_TZIF:
        raise SnapshotError('TZif size out of bounds')
    data = resolved.read_bytes()
    if len(data) != size or data[:4] != b'TZif':
        raise SnapshotError('invalid or changing TZif source')
    return data


def parse_manifest(raw: bytes, snapshot: str):
    try:
        content = raw.decode('ascii')
    except UnicodeDecodeError as e:
        raise SnapshotError('non-ASCII snapshot manifest') from e
    if not content.endswith('\n') or '\r' in content or '\x00' in content:
        raise SnapshotError('non-canonical manifest encoding')
    lines = content.splitlines()
    if len(lines) < 3:
        raise SnapshotError('incomplete snapshot manifest')
    top = lines[0].split('|')
    if len(top) != 3 or top[0] != MAGIC or top[1] != snapshot:
        raise SnapshotError('manifest header mismatch')
    edition = valid_edition(top[2])
    end = lines[-1].split('|')
    entries = {}
    ordered=[]
    for line in lines[1:-1]:
        parts = line.split('|')
        if len(parts) != 5 or parts[0] != 'ZONE':
            raise SnapshotError('invalid zone manifest line')
        name=valid_zone(parts[1])
        try: length=int(parts[2])
        except ValueError: raise SnapshotError('invalid size')
        if str(length) != parts[2] or not 44 <= length <= MAX_TZIF:
            raise SnapshotError('non-canonical or invalid size')
        if not re.fullmatch('[0-9a-f]{64}',parts[3]) or not re.fullmatch('[0-9A-F]{8}',parts[4]):
            raise SnapshotError('invalid digest field')
        if name in entries: raise SnapshotError('duplicate zone')
        entries[name] = (length,parts[3],parts[4]);ordered.append(name)
    if ordered != sorted(ordered) or end != ['END',str(len(entries))]:
        raise SnapshotError('manifest ordering or end marker invalid')
    if not entries: raise SnapshotError('empty snapshot')
    return edition, entries


def verify(root: Path, snapshot: str):
    valid_snapshot(snapshot)
    folder=root/snapshot
    if folder.is_symlink() or not folder.is_dir(): raise SnapshotError('snapshot directory absent or symlink')
    manifest=folder/'MANIFEST.tsv'
    if manifest.is_symlink(): raise SnapshotError('manifest must not be a symlink')
    edition,entries=parse_manifest(manifest.read_bytes(),snapshot)
    for name, expected in entries.items():
        actual=digest(secure_bytes(folder/'zones'/name,folder))
        if actual != expected: raise SnapshotError('zone bytes disagree with manifest: '+name)
    return edition,entries,hashlib.sha256(manifest.read_bytes()).hexdigest()


def publish(source: Path, root: Path, snapshot: str, edition: str, zones: list[str]):
    valid_snapshot(snapshot);valid_edition(edition)
    zones = sorted(set(map(valid_zone,zones)))
    if not zones: raise SnapshotError('one or more --zone arguments required')
    root.mkdir(parents=True,exist_ok=True)
    if (root/snapshot).exists(): raise SnapshotError('snapshot already exists; publishing is create-only')
    staging=Path(tempfile.mkdtemp(prefix='.single-time-staging-',dir=root))
    try:
        lines=[f'{MAGIC}|{snapshot}|{edition}']
        for name in zones:
            data=secure_bytes(source/name,source,may_link=True)
            dst=staging/'zones'/name
            dst.parent.mkdir(parents=True,exist_ok=True)
            with dst.open('xb') as fd:
                fd.write(data);fd.flush();os.fsync(fd.fileno())
            length,sha,adler=digest(data)
            lines.append(f'ZONE|{name}|{length}|{sha}|{adler}')
        lines.append(f'END|{len(zones)}')
        manifest='\n'.join(lines)+'\n'
        with (staging/'MANIFEST.tsv').open('xb') as fd:
            fd.write(manifest.encode('ascii'));fd.flush();os.fsync(fd.fileno())
        # Verify entire staged tree before its publication.
        stage_name=staging.name
        target=root/snapshot
        # rename only within the same filesystem; no overwrite.
        if target.exists(): raise SnapshotError('target raced with publisher')
        staging.rename(target)
        staging=Path('')
        verify(root,snapshot)
    finally:
        if staging != Path('') and staging.exists(): shutil.rmtree(staging)


def compare(root:Path, a:str,b:str):
    ea, old, _ = verify(root,a)
    eb, new, _ = verify(root,b)
    for name in sorted(set(old)|set(new)):
        if name not in old: state='ADDED'
        elif name not in new: state='REMOVED'
        elif old[name][1] == new[name][1]: state='UNCHANGED'
        else: state='CHANGED'
        print(f'{state}\t{name}')
    print(f'BASE\t{a}\t{ea}\nTARGET\t{b}\t{eb}')


def main(argv=None):
    parser=argparse.ArgumentParser(description=__doc__)
    subs=parser.add_subparsers(dest='action',required=True)
    p=subs.add_parser('publish');p.add_argument('--source',type=Path,required=True);p.add_argument('--root',type=Path,required=True)
    p.add_argument('--snapshot',required=True);p.add_argument('--edition',required=True);p.add_argument('--zone',action='append',default=[])
    p=subs.add_parser('verify');p.add_argument('--root',type=Path,required=True);p.add_argument('--snapshot',required=True)
    p=subs.add_parser('compare');p.add_argument('--root',type=Path,required=True);p.add_argument('--from-snapshot',required=True);p.add_argument('--to-snapshot',required=True)
    a=parser.parse_args(argv)
    try:
        if a.action=='publish':
            publish(a.source,a.root,a.snapshot,a.edition,a.zone)
            print('PUBLISHED',a.snapshot)
        elif a.action=='verify':
            edition, entries, sha = verify(a.root,a.snapshot)
            print(f'VERIFIED\t{a.snapshot}\t{edition}\t{len(entries)} zones\tmanifest sha256 {sha}')
        else:compare(a.root,a.from_snapshot,a.to_snapshot)
    except (SnapshotError, OSError) as exc:
        print('REJECTED:',exc,file=sys.stderr)
        return 2
    return 0

if __name__=='__main__':sys.exit(main())
