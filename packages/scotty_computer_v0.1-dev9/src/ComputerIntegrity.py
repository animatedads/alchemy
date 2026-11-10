"""Read-only file-integrity intentions for Scotty Computer.

No implicit writes, no shell execution, no extraction, no network.
"""
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import shlex
import stat
import zipfile

SCHEMA = 'scotty.computer.integrity/1'
ALGORITHMS = {'sha256': 64, 'sha512': 128, 'sha1': 40}
MAX_MANIFEST_ENTRIES = 1000
MAX_MANIFEST_BYTES = 1024 * 1024
MAX_ZIP_TEST_UNCOMPRESSED = 256 * 1024 * 1024
MAX_HASH_SCAN_BYTES = 2 * 1024 * 1024 * 1024

class IntegrityError(Exception):
    def __init__(self, msg, rc=3):
        super().__init__(msg)
        self.rc = rc


def _file(path):
    """An explicit path must refer to a regular, non-symlink file."""
    if path.is_symlink():
        raise IntegrityError(f'Symlink source refused: {path}', 4)
    try:
        s = path.stat()
    except FileNotFoundError:
        raise IntegrityError(f'File not found: {path}', 1)
    except OSError as e:
        raise IntegrityError(f'Cannot stat {path}: {e}', 5)
    if not stat.S_ISREG(s.st_mode):
        raise IntegrityError(f'Not a regular file: {path}', 4)
    return path


def _root_paths(state):
    return [Path(p) for p in state.get('search_roots', []) if Path(p).is_dir()]


def _resolve_name(name, state, walker):
    """Absolute or ~/ paths are explicit; basename lookup is unique or refused."""
    if not name or '\x00' in name or '\n' in name or '\r' in name:
        raise IntegrityError('Invalid or missing file name', 2)
    expanded = os.path.expanduser(name)
    p = Path(expanded)
    if p.is_absolute():
        return _file(p)
    if '/' in name or '\\' in name or name in {'.', '..'}:
        raise IntegrityError('Use an absolute path, ~/path, or unambiguous basename', 3)
    roots = _root_paths(state)
    if not roots:
        raise IntegrityError('No registered find locations; give an absolute path or register a directory', 3)
    matched = []
    for f, st in walker(roots):
        if f.name == name:
            matched.append(f)
            if len(matched) > 1:
                break
    if not matched:
        raise IntegrityError(f'File not found in search locations: {name}', 1)
    if len(matched) > 1:
        raise IntegrityError(f'Ambiguous basename {name!r}; give an absolute path (at least {matched[0]}, {matched[1]})', 3)
    return _file(matched[0])


def _hash(path, algo='sha256', max_bytes=None):
    """Stable identity digest on one opened inode. Reject changes observed while reading."""
    digest = hashlib.new(algo)
    try:
        fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW | os.O_CLOEXEC | os.O_NONBLOCK)
        with os.fdopen(fd, 'rb', buffering=0) as stream:
            first = os.fstat(stream.fileno())
            if not stat.S_ISREG(first.st_mode):
                raise IntegrityError('Source changed into non-file before hash', 4)
            if max_bytes is not None and first.st_size > max_bytes:
                raise IntegrityError('Hash exceeds bounded scan byte budget', 4)
            while True:
                block = stream.read(1024 * 1024)
                if not block:
                    break
                digest.update(block)
            last = os.fstat(stream.fileno())
        try:
            now = path.lstat()
        except FileNotFoundError:
            raise IntegrityError('Source pathname disappeared while hashing', 5)
        before = (first.st_dev, first.st_ino, first.st_size, first.st_mtime_ns, first.st_ctime_ns)
        after = (last.st_dev, last.st_ino, last.st_size, last.st_mtime_ns, last.st_ctime_ns)
        pointed = (now.st_dev, now.st_ino, now.st_size, now.st_mtime_ns, now.st_ctime_ns)
        if before != after or before != pointed or not stat.S_ISREG(now.st_mode):
            raise IntegrityError('Source changed during hashing; result refused', 5)
        return digest.hexdigest(), first.st_size
    except IntegrityError:
        raise
    except OSError as e:
        raise IntegrityError(f'Cannot hash {path}: {e}', 5)


def _manifest(path):
    """GNUs plain sha256sum entries; fail closed on escaping, traversal, duplication."""
    if path.stat().st_size > MAX_MANIFEST_BYTES:
        raise IntegrityError('Manifest exceeds 1 MiB', 4)
    try:
        data = path.read_text(encoding='utf-8')
    except (OSError, UnicodeError) as e:
        raise IntegrityError(f'Cannot decode manifest: {e}', 5)
    entries = []
    seen = set()
    for n, line in enumerate(data.splitlines(), 1):
        if not line.strip() or line.startswith('#'):
            continue
        if line.startswith('\\'):
            raise IntegrityError(f'GNU escaped checksum line not supported at {n}', 2)
        m = re.fullmatch(r'([a-fA-F0-9]{64}) ([ *])(.+)', line)
        if not m:
            raise IntegrityError(f'Invalid SHA256SUMS line {n}', 2)
        name = m.group(3)
        components = PurePosixPath(name)
        if (components.is_absolute() or '\\' in name or name.startswith('./') and name[2:].startswith('./')
                or any(c in {'.', '..'} for c in name.split('/')) or '//' in name or name in seen):
            raise IntegrityError(f'Unsafe or duplicate manifest entry on line {n}', 4)
        seen.add(name)
        entries.append((m.group(1).lower(), name))
        if len(entries) > MAX_MANIFEST_ENTRIES:
            raise IntegrityError('Manifest exceeds 1000 entries', 4)
    if not entries:
        raise IntegrityError('No checksums in manifest', 2)
    return entries


def _result(kind, status='OK', rc=0, **data):
    return {'schema': SCHEMA, 'operation': kind, 'status': status, 'rc': rc, **data}


def _zip_info(path, test):
    try:
        with zipfile.ZipFile(path) as archive:
            files = archive.infolist()
            if len(files) > 4000:
                raise IntegrityError('ZIP member count exceeds 4000', 4)
            total = sum(m.file_size for m in files if not m.is_dir())
            unsafe = [m.filename for m in files if (m.filename.startswith('/') or '\\' in m.filename or
                      any(p == '..' for p in m.filename.split('/')) or '\x00' in m.filename)]
            encrypted = [m.filename for m in files if m.flag_bits & 1]
            if unsafe or encrypted:
                raise IntegrityError(f'ZIP has {len(unsafe)} unsafe names and {len(encrypted)} encrypted members; refusing to trust or test', 4)
            if test:
                if total > MAX_ZIP_TEST_UNCOMPRESSED:
                    raise IntegrityError('ZIP uncompressed size exceeds 256 MiB test budget', 4)
                for member in files:
                    if member.is_dir():
                        continue
                    with archive.open(member) as source:
                        while source.read(1024 * 1024):
                            pass  # zipfile checks member CRC at EOF
            return _result('ZIP_TEST' if test else 'ZIP_LIST', count=len(files), uncompressed_bytes=total,
                           members=[{'name': m.filename, 'size': m.file_size, 'compressed': m.compress_size}
                                    for m in files[:40]], truncated=len(files) > 40,
                           crc_verified=test)
    except IntegrityError:
        raise
    except (zipfile.BadZipFile, OSError, RuntimeError, EOFError, ValueError) as e:
        raise IntegrityError(f'ZIP validation failed: {e}', 1)


def run(text, state, walker, json_mode=False):
    """Return (exit_status, output object) without side effects."""
    op = 'UNKNOWN'
    try:
        try:
            args = shlex.split(text, posix=True)
        except ValueError as e:
            raise IntegrityError(f'Unbalanced file name quotes: {e}', 2)
        if not args:
            raise IntegrityError('Missing operation', 2)
        lower = [x.lower() for x in args]
        # Narrow, documented everyday synonyms; no arbitrary-language-to-shell mapping.
        if lower[:3] == ['get', 'the', 'sha256'] and len(args) == 5 and lower[3] == 'of':
            args = ['sha256', args[4]]
        elif lower[:2] == ['get', 'sha256'] and len(args) == 4 and lower[2] == 'of':
            args = ['sha256', args[3]]
        elif lower[:3] == ['get', 'sha', 'of'] and len(args) == 4:
            args = ['sha256', args[3]]
        elif lower[:2] == ['calculate', 'sha256'] and len(args) == 3:
            args = ['sha256', args[2]]
        elif lower[0] == 'hash' and len(args) == 2:
            args = ['sha256', args[1]]
        elif lower[:2] == ['compare', 'hashes']:
            args = ['compare', 'sha256', *args[2:]]
        lower = [x.lower() for x in args]
        if lower[0] in ALGORITHMS:
            op = 'HASH'
            if len(args) != 2:
                raise IntegrityError('Syntax: Computer sha256|sha512|sha1 FILE', 2)
            algo = lower[0]
            p = _resolve_name(args[1], state, walker)
            digest, n = _hash(p, algo)
            result = _result(op, algorithm=algo, path=str(p), bytes=n, digest=digest,
                             warning='SHA1 is for legacy compatibility, not authentication' if algo == 'sha1' else None)
        elif lower[:2] == ['compare', 'sha256'] or lower[:2] == ['compare', 'files']:
            op = 'COMPARE_SHA256' if lower[1] == 'sha256' else 'COMPARE_FILES'
            if len(args) != 5 or lower[3] != 'with':
                raise IntegrityError('Syntax: Computer compare sha256|files FILE with FILE', 2)
            left = _resolve_name(args[2], state, walker)
            right = _resolve_name(args[4], state, walker)
            a, ab = _hash(left)
            b, bb = _hash(right)
            # Cryptographic digest is an excellent integrity check, but comparing
            # whole files is stronger when byte identity is the actual request.
            identical = a == b and ab == bb
            if lower[1] == 'files' and identical:
                with left.open('rb') as f1, right.open('rb') as f2:
                    while True:
                        b1, b2 = f1.read(1024 * 1024), f2.read(1024 * 1024)
                        if b1 != b2:
                            identical = False
                            break
                        if not b1:
                            break
                # Any concurrent changes are detected with fresh hashes.
                if _hash(left) != (a, ab) or _hash(right) != (b, bb):
                    raise IntegrityError('Files changed during byte comparison', 5)
            result = _result(op, status='MATCH' if identical else 'MISMATCH', rc=0 if identical else 1,
                             left=str(left), right=str(right), left_sha256=a, right_sha256=b,
                             left_bytes=ab, right_bytes=bb, identical=identical)
        elif lower[:2] == ['verify', 'sha256']:
            op = 'VERIFY_SHA256'
            if len(args) != 4 or not re.fullmatch(r'[0-9A-Fa-f]{64}', args[2]):
                raise IntegrityError('Syntax: Computer verify sha256 64_HEX_DIGITS FILE', 2)
            p = _resolve_name(args[3], state, walker)
            actual, n = _hash(p)
            expected = args[2].lower()
            matched = actual == expected
            result = _result(op, status='MATCH' if matched else 'MISMATCH', rc=0 if matched else 1,
                             path=str(p), bytes=n, algorithm='sha256', expected=expected,
                             actual=actual, verified=matched)
        elif lower[:2] == ['verify', 'manifest']:
            op = 'VERIFY_MANIFEST'
            if len(args) != 3:
                raise IntegrityError('Syntax: Computer verify manifest FILE', 2)
            manifest = _resolve_name(args[2], state, walker)
            entries = _manifest(manifest)
            detail = []
            failures = 0
            for expected, name in entries:
                candidate = manifest.parent / name
                # Reject symlinks anywhere in the relative path, not only at the end.
                cursor = manifest.parent
                for component in name.split('/'):
                    cursor = cursor / component
                    if cursor.is_symlink():
                        raise IntegrityError(f'Manifest symlink traversal refused: {name}', 4)
                if candidate.exists():
                    p = _file(candidate)
                    actual, n = _hash(p)
                    ok = actual == expected
                else:
                    actual, n, ok = None, None, False
                failures += not ok
                if len(detail) < 40 or not ok:
                    detail.append({'path': name, 'status': 'MATCH' if ok else 'MISMATCH',
                                   'expected': expected, 'actual': actual, 'bytes': n})
            result = _result(op, status='MATCH' if failures == 0 else 'MISMATCH', rc=0 if failures == 0 else 1,
                             manifest=str(manifest), count=len(entries), failed=failures,
                             entries=detail[:40], truncated=len(detail) > 40)
        elif lower[:2] == ['list', 'zip'] or lower[:2] == ['test', 'zip']:
            op = 'ZIP_TEST' if lower[0] == 'test' else 'ZIP_LIST'
            if len(args) != 3:
                raise IntegrityError('Syntax: Computer list|test zip FILE', 2)
            p = _resolve_name(args[2], state, walker)
            result = _zip_info(p, lower[0] == 'test')
            result['path'] = str(p)
        elif lower[:2] == ['find', 'sha256']:
            op = 'FIND_SHA256'
            if len(args) != 3 or not re.fullmatch(r'[0-9A-Fa-f]{64}', args[2]):
                raise IntegrityError('Syntax: Computer find sha256 64_HEX_DIGITS', 2)
            expected = args[2].lower()
            search_roots = _root_paths(state)
            if not search_roots:
                raise IntegrityError('Register find file locations first', 3)
            matches, scanned, consumed = [], 0, 0
            for p, st in walker(search_roots):
                if consumed + st.st_size > MAX_HASH_SCAN_BYTES:
                    raise IntegrityError('Hash-search scan reached 2 GiB budget; narrow search roots (no NOT_FOUND claim)', 3)
                consumed += st.st_size
                if p.is_symlink():
                    continue
                digest, size = _hash(p)
                scanned += 1
                if digest == expected:
                    matches.append(str(p))
                    if len(matches) >= 40:
                        break
            result = _result(op, status='MATCH' if matches else 'NOT_FOUND', rc=0 if matches else 1,
                             algorithm='sha256', expected=expected, matches=matches, files_scanned=scanned,
                             bytes_scanned=consumed, complete=len(matches) < 40)
        elif lower[:1] == ['inspect']:
            op = 'INSPECT_FILE'
            if len(args) != 2:
                raise IntegrityError('Syntax: Computer inspect FILE', 2)
            p = _resolve_name(args[1], state, walker)
            digest, n = _hash(p)
            st = p.stat()
            result = _result(op, path=str(p), bytes=n, sha256=digest,
                             modified_ns=st.st_mtime_ns, mode=oct(stat.S_IMODE(st.st_mode)))
        else:
            raise IntegrityError('Unknown file integrity instruction', 2)
    except IntegrityError as e:
        result = _result(op, status='ERROR', rc=e.rc, error=str(e))
    if json_mode:
        print(json.dumps(result, sort_keys=True, ensure_ascii=False))
    else:
        print(f"{result['status']} operation={result['operation']} rc={result['rc']}")
        for k, value in result.items():
            if k in {'schema', 'operation', 'status', 'rc'} or value is None:
                continue
            if k in {'entries', 'members', 'matches'} and isinstance(value, list):
                for item in value:
                    print(f'  {k[:-1].upper() if k.endswith("s") else k.upper()} {json.dumps(item, ensure_ascii=False, sort_keys=True)}')
            else:
                print(f'{k.upper()}={json.dumps(value, ensure_ascii=False)}')
    return result['rc']
