"""Machine-local named search scopes, bounded metadata discovery, no extraction.

The name is portable; the path set is per user's machine in private local state.
No network/mount discovery or implicit broad scans are performed.
"""
import datetime as dt
import hashlib
import json
import os
from pathlib import Path
import re
import shlex
import stat
import zipfile

SCHEMA = 'scotty.computer.search/1'
MAX_PREVIEW_HASH_BYTES = 128 * 1024 * 1024
MAX_LIST = 40
NAME = r'[a-z][a-z0-9_-]{0,31}'


def _scope_name(name):
    n = name.strip().lower()
    if not re.fullmatch(NAME, n) or n in {'all', 'any', 'none', 'default'}:
        raise ValueError('Scope name must be 1..32 letters/digits/hyphen/underscore, starting with a letter (not reserved)')
    return n


def scoped_roots(state, scope, error):
    if scope is None:
        configured = state.get('search_roots', [])
        scope_name = 'legacy-default'
    else:
        try:
            scope_name = _scope_name(scope)
        except ValueError as exc:
            raise error(str(exc), 3) from exc
        mapping = state.get('search_scopes', {})
        if scope_name not in mapping:
            raise error(f'Unknown search scope {scope_name!r}. Register its directories explicitly; no fallback to unrelated locations', 3)
        configured = mapping[scope_name]
    if not configured:
        raise error(f'Search scope {scope_name!r} has no registered directories', 3)
    paths = []
    for raw in configured:
        p = Path(raw)
        if not p.is_dir():
            raise error(f'Search scope {scope_name!r} unavailable directory: {p}', 4)
        if p not in paths:
            paths.append(p)
    return paths


def register(text, load, save, canonical, error):
    """Explicit directory registration only, never creates a directory."""
    forms = (
        r'add\s+(.+?)\s+to\s+my\s+find\s+file\s+locations?\s+(?:as|named)\s+(' + NAME + r')',
        r'(?:register|add)\s+search\s+(?:location|directory)\s+(' + NAME + r')\s+(.+)',
        r'add\s+(.+?)\s+to\s+search\s+scope\s+(' + NAME + r')',
    )
    m = re.fullmatch(forms[0], text, re.I)
    if m:
        raw, name = m.groups()
    else:
        m = re.fullmatch(forms[1], text, re.I)
        if m:
            name, raw = m.groups()
        else:
            m = re.fullmatch(forms[2], text, re.I)
            if not m:
                raise error('Syntax: Computer add ~/Downloads to my find file locations as inboundfiles', 3)
            raw, name = m.groups()
    try:
        name = _scope_name(name)
    except ValueError as e:
        raise error(str(e), 3) from e
    raw = raw.strip().strip('"\'')
    if not raw.startswith(('/', '~/')):
        raise error('Search directory must be absolute or start with ~/', 3)
    target = canonical(raw)
    if not target.is_dir() or not os.access(target, os.R_OK | os.X_OK):
        raise error(f'Not an accessible directory: {target}', 4)
    state = load()
    state.setdefault('search_scopes', {})
    paths = state['search_scopes'].setdefault(name, [])
    if str(target) in paths:
        print(f'ALREADY_PRESENT scope={name} path={target}')
        return 0
    paths.append(str(target))
    save(state)
    print(f'ADDED search_scope={name} path={target}')
    print('Only explicit members of this named scope will be searched by scoped commands.')
    return 0


def list_scopes(state, json_mode=False):
    scopes = state.get('search_scopes', {})
    result = {'schema': SCHEMA, 'operation': 'SCOPES', 'status': 'OK', 'rc': 0,
              'scopes': [{'name': k, 'directories': v} for k, v in sorted(scopes.items())],
              'legacy_default': state.get('search_roots', [])}
    if json_mode:
        print(json.dumps(result, sort_keys=True))
    else:
        print('SEARCH_SCOPES (host-local; no implicit all-files search)')
        for item in result['scopes']:
            print(f"SCOPE {item['name']}")
            for root in item['directories']:
                print(f'  DIRECTORY {root}')
        print('LEGACY_DEFAULT=' + json.dumps(result['legacy_default']))
    return 0


def _candidate(path, st, reason, scope, archive_member=None):
    data = {'path': str(path), 'scope': scope, 'reason': reason,
            'modified_utc': dt.datetime.fromtimestamp(st.st_mtime, dt.timezone.utc).isoformat(),
            'modified_epoch_ns': st.st_mtime_ns, 'size_bytes': st.st_size,
            'sha256': None, 'hash_status': 'not_calculated'}
    if archive_member is not None:
        data['archive_member'] = archive_member
        data['hash_status'] = 'archive_hash_not_calculated'
    return data


def _sha_top(candidates, maximum=10):
    """Hash top 10 small archives/files, not every candidate; report when omitted."""
    for item in candidates[:maximum]:
        path = Path(item['path'])
        try:
            st = path.lstat()
            if not stat.S_ISREG(st.st_mode) or st.st_size > MAX_PREVIEW_HASH_BYTES:
                item['hash_status'] = 'skipped_large_or_nonregular'
                continue
            h = hashlib.sha256()
            # Defend against a path becoming a symlink after the directory walk.
            with os.fdopen(os.open(path, os.O_RDONLY | os.O_NOFOLLOW), 'rb') as f:
                live = os.fstat(f.fileno())
                if not stat.S_ISREG(live.st_mode) or (st.st_dev, st.st_ino, st.st_size) != (live.st_dev, live.st_ino, live.st_size):
                    item['hash_status'] = 'changed_before_hash'
                    continue
                for chunk in iter(lambda: f.read(1024 * 1024), b''):
                    h.update(chunk)
            after = path.lstat()
            if (st.st_mtime_ns, st.st_size, st.st_ino) != (after.st_mtime_ns, after.st_size, after.st_ino):
                item['hash_status'] = 'changed_during_hash'
                continue
            item['sha256'] = h.hexdigest()
            item['hash_status'] = 'archive_sha256' if 'archive_member' in item else 'file_sha256'
        except OSError as e:
            item['hash_status'] = 'error_' + type(e).__name__


def _emit(result, json_mode):
    if json_mode:
        print(json.dumps(result, ensure_ascii=False, sort_keys=True))
    else:
        print(f"{result['status']} operation={result['operation']} scope={result.get('scope')} candidates={result.get('count', 0)} scanned={result.get('scanned', 0)}")
        print('ORDER=mtime_desc ; time evidence is filesystem metadata, NOT proven download time or trusted release version')
        for index, item in enumerate(result.get('candidates', []), 1):
            path = item['path'] + ('!' + item['archive_member'] if 'archive_member' in item else '')
            print(f"{index}. {item['modified_utc']} size={item['size_bytes']} path={path} reason={item['reason']} sha256={item['sha256'] or 'UNAVAILABLE'} hash_status={item['hash_status']}")
        if result.get('truncated'):
            print('TRUNCATED results; refine search before claiming completeness')
    return result['rc']


def search(text, state, walker, error, json_mode=False):
    """Supports 'find new files in last 30 minutes in inboundfiles' and dependency queries."""
    m = re.fullmatch(r'find\s+(?:new\s+files|files\s+received)(?:\s+in\s+my\s+find\s+files?\s+location)?\s+in\s+(?:the\s+)?(?:last|past)\s+(\d+)\s+(minutes?|hours?)\s+in\s+(' + NAME + ')', text, re.I)
    if m:
        amount, unit, scope = m.groups()
        minutes = int(amount) * (60 if unit.lower().startswith('hour') else 1)
        if not 1 <= minutes <= 10080:
            raise error('Window must be 1..10080 minutes', 3)
        cutoff = dt.datetime.now(dt.timezone.utc).timestamp() - minutes * 60
        paths = scoped_roots(state, scope, error)
        entries = []
        scanned = 0
        for p, st in walker(paths):
            scanned += 1
            if st.st_mtime >= cutoff:
                entries.append(_candidate(p, st, 'mtime_within_requested_window', scope))
        op = 'RECENT_IN_SCOPE'
    else:
        m = re.fullmatch(r'find\s+dependency\s+(?:rexx\s+)?(.+?)(?:\s+in\s+(' + NAME + '))?', text, re.I)
        if not m:
            raise error('Use: find new files in last 30 minutes in inboundfiles OR find dependency rexx crypto in dependencies', 3)
        subject, scope = m.groups()
        if not scope:
            raise error('Dependency discovery requires an explicit named scope: ... in dependencies', 3)
        terms = [w.lower() for w in re.split(r'\s+', subject.strip()) if w]
        if not terms or len(terms) > 5 or any(not re.fullmatch(r'[a-z0-9_.+-]{1,40}', x) for x in terms):
            raise error('Invalid dependency identifier', 3)
        paths = scoped_roots(state, scope, error)
        entries = []
        scanned = 0
        for p, st in walker(paths):
            scanned += 1
            if p.suffix.lower() in {'.cls', '.rex', '.zip', '.tar', '.gz', '.deb'} and all(t in p.name.lower() for t in terms):
                entries.append(_candidate(p, st, 'filename_all_terms', scope))
            if p.suffix.lower() == '.zip' and st.st_size < 1024*1024*1024:
                try:
                    with zipfile.ZipFile(p) as z:
                        names = z.namelist()
                        if len(names) > 4000:
                            continue
                        for name in names:
                            if name.lower().endswith(('.cls', '.rex')) and all(t in name.rsplit('/', 1)[-1].lower() for t in terms):
                                entries.append(_candidate(p, st, 'zip_member_filename_all_terms', scope, name))
                except (OSError, zipfile.BadZipFile, ValueError):
                    continue
        op = 'FIND_DEPENDENCY'
    entries.sort(key=lambda row: (-row['modified_epoch_ns'], row['path'], row.get('archive_member', '')))
    _sha_top(entries)
    result = {'schema': SCHEMA, 'operation': op, 'status': 'MATCH' if entries else 'NOT_FOUND',
              'rc': 0 if entries else 1, 'scope': scope, 'scanned': scanned, 'count': len(entries),
              'truncated': len(entries) > MAX_LIST, 'candidates': entries[:MAX_LIST]}
    return _emit(result, json_mode)


def find_directories(text, state, error, json_mode=False):
    """Search explicitly registered scope directory NAMES, never descend into file contents.

    Counts every encountered directory entry (including files) towards the work
    budget, so a very wide tree cannot silently turn into an unbounded scan.
    """
    m = re.fullmatch(r'find\s+directories\s+matching\s+([a-z0-9_.+-]{1,40})\s+in\s+(' + NAME + r')', text, re.I)
    if not m:
        raise error('Use: find directories matching xtp in xtpwork', 2)
    term, scope = m.group(1).casefold(), m.group(2).lower()
    roots = scoped_roots(state, scope, error)
    max_entries, max_depth, max_matches = 50000, 16, 2000
    scanned, directories, matches, complete = 0, 0, [], True
    seen = set()
    for root in roots:
        if not complete:
            break
        stack = [(root, 0)]
        while stack:
            path, depth = stack.pop()
            try:
                st = path.lstat()
                if not stat.S_ISDIR(st.st_mode) or stat.S_ISLNK(st.st_mode):
                    continue
                devino = (st.st_dev, st.st_ino)
                if devino in seen:
                    continue
                seen.add(devino)
                directories += 1
                if term in path.name.casefold():
                    if len(matches) < max_matches:
                        matches.append({'path': str(path), 'scope': scope, 'reason': 'directory_name_contains_term',
                                        'modified_utc': dt.datetime.fromtimestamp(st.st_mtime, dt.timezone.utc).isoformat(),
                                        'modified_epoch_ns': st.st_mtime_ns})
                    else:
                        complete = False
                        break
                if depth >= max_depth:
                    # Depth bound may hide further subdirectories; do not claim complete.
                    with os.scandir(path) as entries:
                        for entry in entries:
                            scanned += 1
                            if scanned > max_entries:
                                complete = False
                                break
                            if entry.is_dir(follow_symlinks=False):
                                complete = False
                    continue
                with os.scandir(path) as entries:
                    for entry in entries:
                        scanned += 1
                        if scanned > max_entries:
                            complete = False
                            break
                        if entry.is_dir(follow_symlinks=False):
                            stack.append((Path(entry.path), depth + 1))
                if not complete:
                    break
            except (OSError, PermissionError) as exc:
                raise error('Directory discovery incomplete due to access error: ' + str(exc), 3) from exc
    matches.sort(key=lambda entry: (-entry['modified_epoch_ns'], entry['path']))
    result = {'schema': SCHEMA, 'operation': 'FIND_DIRECTORIES', 'scope': scope,
              'term': term, 'scanned_entries': scanned, 'directories_visited': directories,
              'count': len(matches), 'candidates': matches[:MAX_LIST],
              'truncated': len(matches) > MAX_LIST, 'complete': complete,
              'status': 'MATCH' if matches else ('NOT_FOUND' if complete else 'INCOMPLETE'),
              'rc': 0 if complete and matches else (1 if complete else 3)}
    if json_mode:
        print(json.dumps(result, sort_keys=True))
    else:
        print(f'DIRECTORY_MATCHES scope={scope} term={term} count={len(matches)} scanned_entries={scanned} complete={complete}')
        for c in result['candidates']:
            print(f"{c['modified_utc']} {c['path']} reason={c['reason']}")
        if not complete:
            print('INCOMPLETE: entry/depth/match budget reached; narrow the named scope before claiming absence')
    return result['rc']
