#!/usr/bin/env python3
"""Local administrative OPEN/LOCKED/SEALED state editor.

This is a root-controlled local policy switch, not signed mesh distribution.
"""
import argparse
import datetime as dt
import json
import os
from pathlib import Path
import stat
import sys
import tempfile

MODES = {'OPEN', 'LOCKED', 'SEALED'}


def read_mode(path: Path):
    try:
        fd = os.open(path, os.O_RDONLY | os.O_CLOEXEC | os.O_NOFOLLOW)
    except FileNotFoundError:
        return 'SEALED'
    try:
        st = os.fstat(fd)
        if not stat.S_ISREG(st.st_mode) or st.st_uid != 0 or st.st_mode & 0o022:
            return 'SEALED'
        value = os.read(fd, 32).decode('ascii', 'strict').strip()
        return value if value in MODES else 'SEALED'
    finally:
        os.close(fd)


def append_record(path: Path, record: dict):
    # Root-owned parent directories must be provisioned by the administrator.
    fd = os.open(path, os.O_CREAT | os.O_WRONLY | os.O_APPEND | os.O_CLOEXEC | os.O_NOFOLLOW, 0o600)
    try:
        st = os.fstat(fd)
        if not stat.S_ISREG(st.st_mode) or st.st_uid != 0 or st.st_mode & 0o077:
            raise PermissionError('audit log must be a root-owned private regular file')
        data = (json.dumps(record, sort_keys=True) + '\n').encode()
        os.write(fd, data)
        os.fsync(fd)
    finally:
        os.close(fd)


def secure_parent(path: Path):
    parent = path.parent.resolve(strict=True)
    st = parent.stat()
    if st.st_uid != 0 or not stat.S_ISDIR(st.st_mode) or st.st_mode & 0o022:
        raise PermissionError('policy directory must be root-owned and not group/world-writable')
    return parent


def set_mode(path: Path, journal: Path, requested: str, ticket: str):
    if os.geteuid() != 0:
        raise PermissionError('root privilege required to modify SSH-over-XTP policy')
    if not ticket or len(ticket) > 128 or any(ch in '\r\n' for ch in ticket):
        raise ValueError('--ticket is required (max 128 characters)')
    parent = secure_parent(path)
    secure_parent(journal)
    old = read_mode(path)
    utc = dt.datetime.now(dt.timezone.utc).isoformat()
    rec = {'timestamp': utc, 'operation': 'ssh_xtp_policy', 'old': old, 'new': requested,
           'ticket': ticket, 'uid': os.getuid(), 'pid': os.getpid()}
    append_record(journal, rec | {'phase': 'intent'})
    fd, tmp = tempfile.mkstemp(prefix='.ssh-xtp-policy-', dir=str(parent))
    try:
        os.fchmod(fd, 0o644)
        os.fchown(fd, 0, 0)
        os.write(fd, (requested + '\n').encode())
        os.fsync(fd)
        os.close(fd)
        fd = -1
        os.replace(tmp, path)
        dirfd = os.open(parent, os.O_RDONLY | os.O_DIRECTORY | os.O_CLOEXEC)
        try:
            os.fsync(dirfd)
        finally:
            os.close(dirfd)
    finally:
        if fd != -1:
            os.close(fd)
        if os.path.exists(tmp):
            os.unlink(tmp)
    append_record(journal, rec | {'phase': 'committed'})
    return {'mode': requested, 'previous': old, 'ticket': ticket, 'committed': True}


def main():
    ap = argparse.ArgumentParser(description='Root-controlled local SSH-over-XTP admission switch')
    ap.add_argument('--file', required=True, type=Path, help='local root-owned policy file')
    ap.add_argument('--audit', type=Path, help='root-owned audit JSONL; defaults alongside policy')
    sub = ap.add_subparsers(dest='operation', required=True)
    sub.add_parser('status')
    change = sub.add_parser('set')
    change.add_argument('mode', choices=sorted(MODES))
    change.add_argument('--ticket', required=True)
    args = ap.parse_args()
    journal = args.audit or args.file.with_name(args.file.name + '.audit.jsonl')
    if args.operation == 'status':
        output = {'mode': read_mode(args.file), 'path': str(args.file), 'source': 'local-policy'}
    else:
        output = set_mode(args.file, journal, args.mode, args.ticket)
    print(json.dumps(output, sort_keys=True))


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError) as e:
        print(json.dumps({'ok': False, 'error': str(e)}), file=sys.stderr)
        sys.exit(2)
