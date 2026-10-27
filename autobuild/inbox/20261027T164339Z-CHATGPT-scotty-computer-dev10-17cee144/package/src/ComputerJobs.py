"""Governed user-authored executable jobs for Computer.

No new privilege is conferred. Registration: draft -> exact argv attestation ->
confirmation. Invocation: preview -> separate one-use confirmation -> execution.
Remote jobs MUST use authoritative sshnode.sh, not independently configured ssh.
"""
import datetime as dt
import hashlib
import json
import os
from pathlib import Path
import re
import secrets
import signal
import shlex
import shutil
import subprocess
import time
import stat
from ComputerExceptions import parse_registration, validate_directory, RunObserver, SAMPLE_SECONDS

NAME = re.compile(r'[a-z][a-z0-9_-]{0,39}\Z')
MAX_TEXT = 8192
MAX_ARGV = 96
MAX_ARG_BYTES = 4096
MAX_SECONDS = 1800
MAX_PIN_FILES = 16


def _fingerprint(blob):
    return hashlib.sha256(json.dumps(blob, sort_keys=True, separators=(',', ':')).encode('utf-8')).hexdigest()


def _validate_tokens(argv, error):
    if not argv or len(argv) > MAX_ARGV:
        raise error('Job needs 1..96 argv elements after --', 2)
    if any(not a or len(a.encode('utf-8')) > MAX_ARG_BYTES or any(ch in a for ch in '\x00\r\n') for a in argv):
        raise error('Job argv includes an empty, control-containing or oversized element', 2)
    return argv


def parse_draft(text, error):
    if len(text) > MAX_TEXT:
        raise error('Job draft is too long', 2)
    try:
        p = shlex.split(text)
    except ValueError as exc:
        raise error('Job command quoting is malformed: ' + str(exc), 2) from exc
    if len(p) < 6 or [t.casefold() for t in p[:2]] != ['job', 'draft']:
        raise error('Use: job draft NAME local|on ed209NODE [--cwd PATH] [--timeout N] -- EXEC ARG...', 2)
    name = p[2].casefold()
    if not NAME.fullmatch(name):
        raise error('Job name must be 1..40 lower-case letters, digits, _ or -', 2)
    if p[3].casefold() == 'local':
        target, node, ix = 'local', None, 4
    elif p[3].casefold() == 'on' and len(p) > 4 and re.fullmatch(r'ed209[a-z0-9]+', p[4], re.I):
        target, node, ix = 'remote', p[4].casefold(), 5
    else:
        raise error('Specify local or on a named ED209 node', 2)
    cwd, seconds, pins = None, 120, []
    seen = set()
    while ix < len(p) and p[ix] != '--':
        opt = p[ix]
        if opt not in {'--timeout', '--cwd', '--pin-file'} or (opt != '--pin-file' and opt in seen) or ix + 1 >= len(p):
            raise error('Only --timeout SECONDS, local --cwd PATH, and repeatable local --pin-file FILE belong before --', 2)
        seen.add(opt)
        value = p[ix + 1]
        if opt == '--pin-file':
            if target != 'local' or not Path(value).is_absolute() or value in pins or len(pins) >= MAX_PIN_FILES:
                raise error('--pin-file needs a distinct absolute local file (maximum 16)', 2)
            pins.append(value)
        elif opt == '--timeout':
            if not value.isascii() or not value.isdecimal() or not 1 <= int(value) <= MAX_SECONDS:
                raise error('Timeout must be 1..1800 seconds', 2)
            seconds = int(value)
        else:
            if target != 'local' or not Path(value).is_absolute():
                raise error('--cwd requires an absolute path and is local-only', 2)
            folder = Path(value)
            if folder.is_symlink() or not folder.is_dir():
                raise error('Local working directory must exist and not be a symlink', 4)
            cwd = str(folder.resolve())
        ix += 2
    if ix >= len(p) or p[ix] != '--':
        raise error('Place job executable/argv after a literal -- separator', 2)
    argv = _validate_tokens(p[ix + 1:], error)
    return {'name': name, 'target': target, 'node': node, 'cwd': cwd,
            'timeout': seconds, 'argv': argv, 'pin_files': pins}


def _validate_definition(definition, error):
    if not isinstance(definition, dict) or not NAME.fullmatch(str(definition.get('name', ''))):
        raise error('Invalid registered job name', 4)
    if definition.get('target') not in {'remote', 'local'}:
        raise error('Invalid registered job target', 4)
    if type(definition.get('timeout')) is not int or not 1 <= definition['timeout'] <= MAX_SECONDS:
        raise error('Invalid registered timeout', 4)
    if definition['target'] == 'remote':
        if not re.fullmatch(r'ed209[a-z0-9]+', str(definition.get('node', ''))):
            raise error('Invalid registered node', 4)
        if definition.get('cwd') is not None:
            raise error('Remote working directory is not supported by this job format', 4)
    elif definition.get('node') is not None:
        raise error('Local job has a remote target', 4)
    elif definition.get('cwd') is not None:
        path = Path(definition['cwd'])
        if not path.is_absolute() or path.is_symlink() or not path.is_dir():
            raise error('Registered local working directory changed/unavailable', 4)
    _validate_tokens(definition.get('argv'), error)
    pins = definition.get('pin_files', [])
    if not isinstance(pins, list) or len(pins) > MAX_PIN_FILES or len(set(pins)) != len(pins) or any(not isinstance(x, str) or not Path(x).is_absolute() for x in pins):
        raise error('Invalid pinned file list', 4)
    if pins and definition['target'] != 'local':
        raise error('Remote job cannot claim controller-local file pins', 4)
    return definition


def _pin_regular_file(path, sha_file, error):
    """Pin local file bytes; do not confuse this with immutable transitive imports."""
    candidate = Path(path)
    try:
        st = candidate.lstat()
    except OSError as exc:
        raise error('Pinned script/input unavailable: ' + str(candidate), 4) from exc
    if not stat.S_ISREG(st.st_mode) or candidate.is_symlink():
        raise error('Pinned script/input must be an ordinary nonsymlink file: ' + str(candidate), 4)
    return {'path': str(candidate.resolve()), 'sha256': sha_file(candidate)}


def _auto_script(definition, resolved_exec):
    """Recognise an explicit script argument, not a guessed shell command."""
    name = Path(resolved_exec).name.casefold()
    words = definition['argv'][1:]
    if name.startswith('python'):
        # Python flags without a parameter. -m/-c have no script-file argument.
        while words and words[0] in {'-B', '-E', '-I', '-S', '-s', '-u', '-O', '-OO'}:
            words = words[1:]
        if not words or words[0].startswith('-'):
            return None
    elif name in {'bash', 'sh', 'dash', 'zsh', 'ksh'}:
        # -c (including -lc) executes an inline command; this must not be
        # mistaken for a script pathname. Other option forms are not guessed.
        while words and words[0].startswith('-'):
            if 'c' in words[0][1:]:
                return None
            if words[0] not in {'-e', '-u', '-x', '-eu', '-eux', '-xe'}:
                return None
            words = words[1:]
    elif name in {'rexx', 'regina'}:
        if not words or words[0].startswith('-'):
            return None
    else:
        return None
    if not words or words[0] == '-' or words[0].startswith('-'):
        return None
    path = Path(words[0])
    if not path.is_absolute():
        path = Path(definition.get('cwd') or os.getcwd()) / path
    return path


def _authority(definition, helper, configured_nodes, sha_file, error):
    _validate_definition(definition, error)
    if definition['target'] == 'remote':
        tool = helper('sshnode.sh', 'COMPUTER_SSHNODE')
        if definition['node'] not in configured_nodes(tool):
            raise error('Remote node not present in authoritative sshnode.sh: ' + definition['node'], 4)
        ssh_config = Path.home() / '.ssh' / 'config'
        ssh_profile = {'path': str(ssh_config),
                       'sha256': sha_file(ssh_config) if ssh_config.is_file() else None}
        return {'kind': 'sshnode', 'path': str(tool), 'sha256': sha_file(tool),
                'ssh_config': ssh_profile}
    executable = definition['argv'][0]
    chosen = executable if '/' in executable else shutil.which(executable)
    if not chosen:
        raise error('Local executable not found in PATH: ' + executable, 4)
    original = Path(chosen)
    if not original.is_file():
        raise error('Local executable is not a file: ' + str(original), 4)
    path = original.resolve()
    if not path.is_file() or not os.access(path, os.X_OK):
        raise error('Local executable is not executable: ' + str(path), 4)
    pins = []
    script = _auto_script(definition, path)
    if script is not None:
        pins.append(_pin_regular_file(script, sha_file, error))
    for pin in definition.get('pin_files', []):
        item = _pin_regular_file(pin, sha_file, error)
        if item['path'] not in {p['path'] for p in pins}:
            pins.append(item)
    pins.sort(key=lambda p: p['path'])
    return {'kind': 'local_exec', 'path': str(path), 'sha256': sha_file(path),
            'file_pins': pins}


def _actual_argv(definition, authority, run_id):
    if definition['target'] == 'local':
        return [authority['path'], *definition['argv'][1:]]
    # sshnode.sh passes command words to OpenSSH. An SSH remote shell interprets
    # the command; serialize *each* user argv element with POSIX shell quoting.
    # Pass one shell-quoted string to prevent OpenSSH space-joining raw elements.
    remote_line = shlex.join(definition['argv'])
    return [authority['path'], '--job-id', run_id, definition['node'], remote_line]


def _show(definition, authority, run_id):
    actual = _actual_argv(definition, authority, run_id)
    print('TARGET=' + (definition['node'] if definition['target'] == 'remote' else 'local'))
    print('JOB_ARGV_JSON=' + json.dumps(definition['argv'], ensure_ascii=False))
    print('EXEC_ARGV_JSON=' + json.dumps(actual, ensure_ascii=False))
    print('COMMAND=' + shlex.join(actual))
    print('AUTHORITY=' + json.dumps(authority, sort_keys=True))
    print('PINNED_FILES=' + json.dumps(authority.get('file_pins', []), sort_keys=True))
    print('WORKDIR=' + (definition['cwd'] or '(inherited)'))
    print('TIMEOUT_SECONDS=' + str(definition['timeout']))
    if definition['target'] == 'remote':
        print('REMOTE_EXECUTION=sshnode.sh via OpenSSH/POSIX remote shell; local SSH config hashed when present; remote executable bytes not independently pinned')
    else:
        print('LOCAL_EXECUTION=subprocess argv; shell=False (unless operator explicitly chose a shell executable)')
        print('PIN_SCOPE=interpreter/executable and enumerated local file pins only; imported modules, nested scripts and shell-generated file references are NOT pinned')
    return actual



# Run evidence is private and indexed by an opaque, validated ID. No arbitrary
# path argument and no new executable job is required to inspect a receipt.
RUN_ID = re.compile(r'computer-job-([a-z][a-z0-9_-]{0,39})-(?:[a-f0-9]{16}|[0-9]{8}T[0-9]{6}Z-[a-f0-9]{8})\Z')
RUN_SCHEMA = 'scotty.computer.job-run/1'
RECEIPT_READ_LIMIT = 64 * 1024
HISTORY_SCAN_LIMIT = 4096


def _receipt_root(config_dir, error, create=False):
    base = config_dir()
    root = base / 'jobs'
    if base.is_symlink() or root.is_symlink():
        raise error('Unsafe receipts directory', 4)
    if create:
        root.mkdir(mode=0o700, parents=True, exist_ok=True)
        os.chmod(root, 0o700)
    if not root.is_dir():
        raise error('No local job receipts yet', 1)
    return root


def _read_private_file(path, error, maximum=16384):
    try:
        fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW | getattr(os, 'O_NONBLOCK', 0))
        with os.fdopen(fd, 'rb') as f:
            st = os.fstat(f.fileno())
            if not stat.S_ISREG(st.st_mode) or (st.st_mode & 0o077):
                raise error('Receipt is not a private regular file', 4)
            if st.st_size > maximum:
                raise error('Receipt metadata oversized', 4)
            return f.read(maximum + 1)
    except FileNotFoundError as exc:
        raise error('No such job receipt: ' + path.name, 1) from exc
    except OSError as exc:
        raise error('Cannot read receipt: ' + str(exc), 5) from exc


def _run_record(root, run_id, error):
    if not RUN_ID.fullmatch(run_id):
        raise error('Invalid job run identifier', 2)
    path = root / (run_id + '.json')
    try:
        doc = json.loads(_read_private_file(path, error).decode('utf-8'))
    except (ValueError, UnicodeDecodeError) as exc:
        raise error('Invalid job metadata', 4) from exc
    if not isinstance(doc, dict) or doc.get('schema') != RUN_SCHEMA or doc.get('run_id') != run_id:
        raise error('Run metadata schema or identity mismatch', 4)
    if doc.get('status') not in {'EXITED', 'TIMEOUT', 'LAUNCH_FAILED'} or type(doc.get('child_rc')) is not int:
        raise error('Run metadata has invalid status or child exit value', 4)
    for key in ('job', 'target', 'definition_sha256', 'finished_at', 'stdout_path', 'stderr_path'):
        if not isinstance(doc.get(key), str):
            raise error('Run metadata missing required field: ' + key, 4)
    return doc



def _legacy_record(root, run_id, error):
    # Pre-dev6 executions have only stdout/stderr. Never infer completion from
    # file existence, filenames, or apparent command output.
    streams = {}
    for ext in ('stdout', 'stderr'):
        for folder in (root, root / 'receipts'):
            if folder.is_symlink():
                raise error('Legacy receipt folder is a symlink', 4)
            path = folder / (run_id + '.' + ext)
            try:
                st = path.lstat()
                if not stat.S_ISREG(st.st_mode) or (st.st_mode & 0o077):
                    raise error('Legacy receipt is not a private regular file', 4)
                streams[ext] = str(path)
                break
            except FileNotFoundError:
                pass
    if not streams:
        raise error('No indexed or legacy receipt for run ' + run_id, 1)
    return {'schema': RUN_SCHEMA, 'run_id': run_id, 'job': RUN_ID.fullmatch(run_id).group(1),
            'target': 'UNVERIFIED', 'status': 'UNKNOWN_LEGACY', 'child_rc': None,
            'definition_sha256': None, 'stdout_path': streams.get('stdout'),
            'stderr_path': streams.get('stderr'), 'evidence': 'unindexed pre-dev6 receipt; outcome unverified'}

def _write_run_record(root, record, error):
    path = root / (record['run_id'] + '.json')
    blob = json.dumps(record, sort_keys=True).encode('utf-8') + b'\n'
    try:
        fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
        with os.fdopen(fd, 'wb') as f:
            f.write(blob)
            f.flush()
            os.fsync(f.fileno())
    except OSError as exc:
        raise error('Cannot create run metadata: ' + str(exc), 5) from exc


def receipt_command(text, config_dir, error):
    json_mode = text.casefold().startswith('--json ')
    if json_mode:
        text = text[7:].strip()
    m = re.fullmatch(r'job\s+(result|stdout|stderr|explain|history)\s+([a-zA-Z0-9_-]+)', text, re.I)
    if not m:
        raise error('Use job result|stdout|stderr|explain RUN_ID OR job history NAME', 2)
    op, ident = m.group(1).lower(), m.group(2)
    if op == 'history':
        name = ident.casefold()
        if not NAME.fullmatch(name):
            raise error('Invalid job name', 2)
        root = _receipt_root(config_dir, error)
        docs, scanned = [], 0
        with os.scandir(root) as entries:
            for entry in entries:
                scanned += 1
                if scanned > HISTORY_SCAN_LIMIT:
                    raise error('Receipt history scan limit reached; cannot claim completeness', 3)
                if not entry.name.endswith('.json') or not entry.name.startswith('computer-job-' + name + '-'):
                    continue
                run_id = entry.name[:-5]
                if not RUN_ID.fullmatch(run_id) or RUN_ID.fullmatch(run_id).group(1) != name:
                    continue
                docs.append(_run_record(root, run_id, error))
        docs.sort(key=lambda doc: doc.get('finished_at', ''), reverse=True)
        data = {'schema': RUN_SCHEMA, 'operation': 'history', 'job': name, 'count': len(docs),
                'runs': docs[:40], 'truncated': len(docs) > 40, 'complete': True}
        if json_mode:
            print(json.dumps(data, sort_keys=True))
        else:
            print(f'JOB_HISTORY name={name} count={len(docs)} truncated={data["truncated"]}')
            for row in data['runs']:
                print(f'RUN_ID={row["run_id"]} status={row["status"]} child_rc={row["child_rc"]} exception_count={row.get("exceptions", {}).get("count", 0)} finished_at={row["finished_at"]}')
        return 0 if docs else 1
    if not RUN_ID.fullmatch(ident):
        raise error('Invalid job run identifier', 2)
    root = _receipt_root(config_dir, error)
    if op in {'result', 'explain'}:
        if (root / (ident + '.json')).exists() or (root / (ident + '.json')).is_symlink():
            doc = _run_record(root, ident, error)
        else:
            doc = _legacy_record(root, ident, error)
        if json_mode:
            print(json.dumps(doc, sort_keys=True))
        elif op == 'result':
            print('JOB_RESULT=' + json.dumps(doc, sort_keys=True))
        else:
            print('RUN_ID=' + ident)
            print('RESULT status=' + str(doc['status']) + ' child_rc=' + str(doc['child_rc']))
            print('AUTHORITY=' + str(doc['target']) + ' definition_sha256=' + str(doc['definition_sha256']))
            print('STDOUT=' + str(doc['stdout_path']) + ' STDERR=' + str(doc['stderr_path']))
            if doc.get('exceptions'):
                print('EXCEPTIONS=' + json.dumps(doc['exceptions'], sort_keys=True))
            if doc['status'] == 'UNKNOWN_LEGACY':
                print('EXPLANATION=legacy receipts only; execution status is UNKNOWN and must not be claimed as success')
            elif doc['status'] == 'TIMEOUT':
                print('EXPLANATION=process exceeded the registered timeout; no success claimed')
            elif doc['status'] == 'EXITED' and doc['child_rc'] == 0:
                print('EXPLANATION=child exited zero; this does not prove the intended remote result')
            else:
                print('EXPLANATION=child failed or could not be launched; inspect stderr')
        return 0
    path = root / (ident + '.' + op)
    if not path.exists() and not path.is_symlink():
        legacy_folder = root / 'receipts'
        if legacy_folder.is_symlink():
            raise error('Legacy receipt folder is a symlink', 4)
        path = legacy_folder / (ident + '.' + op)
    try:
        fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW | getattr(os, 'O_NONBLOCK', 0))
        with os.fdopen(fd, 'rb') as f:
            st = os.fstat(f.fileno())
            if not stat.S_ISREG(st.st_mode) or (st.st_mode & 0o077):
                raise error('Receipt is not a private regular file', 4)
            data = f.read(RECEIPT_READ_LIMIT + 1)
            size = st.st_size
    except FileNotFoundError as exc:
        raise error('Receipt stream does not exist: ' + ident, 1) from exc
    except OSError as exc:
        raise error('Receipt stream cannot be read: ' + str(exc), 5) from exc
    text_data = data[:RECEIPT_READ_LIMIT].decode('utf-8', errors='replace')
    # Escape control characters that could change the terminal's display.
    text_data = ''.join(ch if ch in '\n\t' or ord(ch) >= 32 and ord(ch) != 127 else '\uFFFD' for ch in text_data)
    metadata_exists = (root / (ident + '.json')).exists()
    if json_mode:
        print(json.dumps({'schema': RUN_SCHEMA, 'operation': op, 'run_id': ident,
                          'metadata_status': 'INDEXED' if metadata_exists else 'UNVERIFIED_LEGACY',
                          'size_bytes': size, 'truncated': size > RECEIPT_READ_LIMIT, 'text': text_data}))
    else:
        print(f'JOB_{op.upper()} run_id={ident} size_bytes={size} truncated={size > RECEIPT_READ_LIMIT} metadata={"INDEXED" if metadata_exists else "UNVERIFIED_LEGACY"}')
        print(text_data, end='' if text_data.endswith('\n') else '\n')
        if size > RECEIPT_READ_LIMIT:
            print('TRUNCATED: use the existing receipt file for controlled deeper inspection')
    return 0


def _repeat_readonly(definition):
    """Finite diagnostic language. No freeform shell, paths, sudo or options."""
    argv = definition['argv']
    allowed = {
        'df': {('df', '-h'), ('df', '-h', '-T')},
        'free': {('free', '-h')},
        'uptime': {('uptime',)},
        'uname': {('uname', '-a')},
        'date': {('date', '-u')},
    }
    # Explicit local /usr/bin or /bin paths accepted; no arbitrary executable path.
    cmd = argv[0]
    if '/' in cmd:
        if cmd not in {'/usr/bin/df', '/bin/df', '/usr/bin/free', '/usr/bin/uptime',
                       '/bin/uname', '/usr/bin/uname', '/usr/bin/date', '/bin/date'}:
            return False
        cmd = Path(cmd).name
    normalized = (cmd, *argv[1:])
    return normalized in allowed.get(cmd, ()) and definition.get('cwd') is None


def _validate_registered_job(name, load, error):
    doc = load().get('jobs', {}).get(name)
    if not doc:
        raise error('Unknown registered job: ' + name, 1)
    definition = {k: v for k, v in doc.items() if k not in {'definition_sha256', 'registered_at'}}
    _validate_definition(definition, error)
    if _fingerprint(definition) != doc.get('definition_sha256'):
        raise error('Registered job definition hash mismatch', 4)
    return definition, doc


def handle(text, load, save, create, consume, error, helper, configured_nodes, sha_file, config_dir):
    low = text.casefold()
    if re.match(r'(?:--json\s+)?job\s+(?:result|stdout|stderr|history|explain)\s+', text, re.I):
        return receipt_command(text, config_dir, error)
    # Exception policy is independent of the immutable command definition.
    # It is versioned and bound to a particular run at preview/confirmation.
    m_ex = re.fullmatch(r'job\s+exceptions\s+([a-z][a-z0-9_-]{0,39})', text, re.I)
    if m_ex:
        name = m_ex.group(1).casefold()
        definition, registered = _validate_registered_job(name, load, error)
        rules = load().get('job_exceptions', {}).get(name, [])
        print('JOB_EXCEPTIONS name=' + name + ' definition_sha256=' + registered['definition_sha256'])
        print('EXCEPTIONS_JSON=' + json.dumps(rules, sort_keys=True))
        print('EXCEPTIONS_SHA256=' + _fingerprint(rules))
        return 0
    if low.startswith('job exception register ') or low.startswith('job exception add '):
        from ComputerExceptions import MAX_RULES
        name, rule = parse_registration(text, error)
        definition, registered = _validate_registered_job(name, load, error)
        if definition['target'] == 'remote' and rule['type'] == 'runaway_space':
            raise error('runaway_space path is controller-local; remote workspace size requires a distinct remote observer', 4)
        current = load().get('job_exceptions', {}).get(name, [])
        if rule in current:
            print('JOB_EXCEPTION_ALREADY_REGISTERED name=' + name + ' rule=' + json.dumps(rule, sort_keys=True))
            return 0
        if len(current) >= MAX_RULES:
            raise error('Maximum registered exceptions per job reached', 4)
        proposed = current + [rule]
        authority = _authority(definition, helper, configured_nodes, sha_file, error)
        pending = {'schema': 'scotty.computer.pending/1', 'intent': 'JOB_EXCEPTION_REGISTER',
                   'created_at': time.time(), 'definition': definition,
                   'definition_sha256': registered['definition_sha256'], 'authority': authority,
                   'before_sha256': _fingerprint(current), 'after_sha256': _fingerprint(proposed),
                   'exceptions': proposed}
        token = create(pending)
        print('JOB_EXCEPTION_PREVIEW name=' + name + ' NOT REGISTERED')
        print('RULE=' + json.dumps(rule, sort_keys=True))
        print('EXCEPTIONS_SHA256=' + _fingerprint(proposed))
        print('OBSERVER=only during this Computer job run; report-only; no background daemon or termination')
        _show(definition, authority, '<RUN_JOB_ID>')
        print('Operator must approve the exact watch path, unit, threshold and target.')
        print('Computer confirm ' + token)
        return 3
    m = re.fullmatch(r'job\s+policy\s+([a-z][a-z0-9_-]{0,39})\s+(repeat-readonly|manual)', text, re.I)
    if m:
        name, mode = m.group(1).casefold(), m.group(2).casefold()
        definition, registered = _validate_registered_job(name, load, error)
        if mode == 'repeat-readonly' and not _repeat_readonly(definition):
            raise error('Repeat authority is only supported for exact allowlisted diagnostic argv', 4)
        authority = _authority(definition, helper, configured_nodes, sha_file, error)
        pending = {'schema': 'scotty.computer.pending/1', 'intent': 'JOB_POLICY',
                   'created_at': time.time(), 'definition': definition,
                   'definition_sha256': registered['definition_sha256'], 'authority': authority, 'policy': mode}
        token = create(pending)
        print('JOB_POLICY_PREVIEW name=' + name + ' mode=' + mode + ' NOT CHANGED')
        _show(definition, authority, '<RUN_JOB_ID>')
        print('POLICY_SCOPE=exact pinned argv, target, executable/sshnode hash; only finite diagnostics permitted for repeat-readonly')
        print('POLICY_WARNING=remote executable/agent identities not pinned; SSH config file hash is rechecked but no new OS authority is granted')
        print('Computer confirm ' + token)
        return 3
    if low in {'job help', 'jobs help'}:
        print('REGISTER: Computer \'job draft NAME local [--cwd PATH] [--timeout 120] [--pin-file ABSOLUTE_FILE ...] -- EXEC ARG...\'')
        print('REMOTE: Computer \'job draft NAME on ed209b [--timeout 120] -- EXEC ARG...\'')
        print('REVIEW: Read exact job argv, target, executable, options and execution command.')
        print('ATTEST: Computer \'job approve TOKEN -- EXEC ARG...\' (identical argv/order)')
        print('ACTIVATE: Computer confirm TOKEN2 (separate, one-use approval)')
        print('EXECUTE: Computer \'job run NAME\' or \'job start NAME\' (preview only), then Computer confirm TOKEN3')
        print('INSPECT: Computer job list | Computer job show NAME')
        print('REVOKE: Computer job revoke NAME (preview), then Computer confirm TOKEN')
        print('RECEIPTS: Computer job result|stdout|stderr|explain RUN_ID; job history NAME')
        print('REUSE: Computer job policy NAME repeat-readonly|manual (confirmation required)')
        print('EXCEPTIONS: Computer job exception register NAME runaway_space ABSOLUTE_DIRECTORY 10 meg')
        print('EXCEPTIONS: Computer job exception register NAME runtime_overrun 5 seconds')
        print('EXCEPTIONS: Computer job exception register NAME output_contains "ERROR:" [stdout|stderr|both]')
        print('LIST: Computer job exceptions NAME; exceptions are report-only, run-scoped and sampled')
        print('Only explicitly allowlisted fixed diagnostic argv can use repeat-readonly.')
        return 0
    if low == 'job list':
        for name, doc in sorted(load().get('jobs', {}).items()):
            print('JOB name=' + name + ' target=' + (doc['node'] or 'local') + ' argv=' + json.dumps(doc['argv']))
        return 0
    m = re.fullmatch(r'job\s+show\s+([a-z][a-z0-9_-]{0,39})', text, re.I)
    if m:
        name = m.group(1).casefold()
        doc = load().get('jobs', {}).get(name)
        if not doc:
            raise error('Unknown registered job: ' + name, 1)
        definition = {k: v for k, v in doc.items() if k not in {'definition_sha256', 'registered_at'}}
        print('JOB_DEFINITION=' + json.dumps(definition, sort_keys=True))
        print('PINNED_DEFINITION_SHA256=' + doc.get('definition_sha256', 'MISSING'))
        print('EXECUTION_POLICY=' + json.dumps(load().get('job_policies', {}).get(name, {'mode': 'manual'}), sort_keys=True))
        print('EXCEPTIONS=' + json.dumps(load().get('job_exceptions', {}).get(name, []), sort_keys=True))
        return 0
    m = re.fullmatch(r'job\s+revoke\s+([a-z][a-z0-9_-]{0,39})', text, re.I)
    if m:
        name = m.group(1).casefold()
        doc = load().get('jobs', {}).get(name)
        if not doc:
            raise error('Unknown registered job: ' + name, 1)
        definition = {k: v for k, v in doc.items() if k not in {'definition_sha256', 'registered_at'}}
        if _fingerprint(_validate_definition(definition, error)) != doc.get('definition_sha256'):
            raise error('Registered job definition is corrupt; cannot revoke through this interface', 4)
        pending = {'schema': 'scotty.computer.pending/1', 'intent': 'JOB_REVOKE',
                   'created_at': time.time(), 'definition': definition,
                   'definition_sha256': doc['definition_sha256']}
        token = create(pending)
        print('JOB_REVOKE_PREVIEW name=' + name + ' definition_sha256=' + str(doc['definition_sha256']))
        print('NOT REVOKED. Pending run confirmations will fail once revoked.')
        print('Computer confirm ' + token)
        return 3
    if low.startswith('job draft '):
        definition = parse_draft(text, error)
        if definition['name'] in load().get('jobs', {}):
            raise error('Job name already registered; immutable definition (choose a new name)', 4)
        authority = _authority(definition, helper, configured_nodes, sha_file, error)
        rendered = 'job draft ' + definition['name'] + (' local' if definition['target'] == 'local' else ' on ' + definition['node'])
        if definition['cwd']:
            rendered += ' --cwd ' + shlex.quote(definition['cwd'])
        for pin in definition.get('pin_files', []):
            rendered += ' --pin-file ' + shlex.quote(pin)
        rendered += ' --timeout ' + str(definition['timeout']) + ' -- ' + shlex.join(definition['argv'])
        pending = {'schema': 'scotty.computer.pending/1', 'intent': 'JOB_REVIEW',
                   'created_at': time.time(), 'definition': definition,
                   'definition_sha256': _fingerprint(definition), 'authority': authority}
        token = create(pending)
        print('JOB_DRAFT name=' + definition['name'] + ' NOT REGISTERED; NOT EXECUTED')
        print('REGISTER_REQUEST=' + shlex.join(['Computer', rendered]))
        _show(definition, authority, '<RUN_JOB_ID>')
        print('Codex MUST present target, argv elements, all option positions, and the exact execution COMMAND for approval.')
        print('APPROVE_STRUCTURE=' + shlex.join(['Computer', 'job approve ' + token + ' -- ' + shlex.join(definition['argv'])]))
        print('This consumes review token; different argument order/quoting/value fails and must be redrafted.')
        return 3
    m = re.fullmatch(r'job\s+approve\s+([A-Za-z0-9_-]{32})\s+--\s+(.+)', text, re.I | re.S)
    if m:
        pending = consume(m.group(1))
        if pending.get('intent') != 'JOB_REVIEW':
            raise error('Token is not a job-review record', 4)
        definition = _validate_definition(pending['definition'], error)
        try:
            proposed_argv = _validate_tokens(shlex.split(m.group(2)), error)
        except ValueError as exc:
            raise error('Invalid job approval argv quoting: ' + str(exc), 2) from exc
        if proposed_argv != definition['argv'] or _fingerprint(definition) != pending['definition_sha256']:
            raise error('Job structure/options/positional arguments changed; draft again', 4)
        if _authority(definition, helper, configured_nodes, sha_file, error) != pending['authority']:
            raise error('Executable or SSH adapter changed during review; draft again', 4)
        if definition['name'] in load().get('jobs', {}):
            raise error('Job name already registered', 4)
        pending['intent'] = 'JOB_ACTIVATE'
        pending['created_at'] = time.time()
        token2 = create(pending)
        print('JOB_STRUCTURE_ATTESTED name=' + definition['name'] + ' exact_argv_and_order=true')
        print('COMMAND=' + shlex.join(_actual_argv(definition, pending['authority'], '<RUN_JOB_ID>')))
        print('NOT REGISTERED until: Computer confirm ' + token2)
        return 3
    m = re.fullmatch(r'job\s+(?:run|start)\s+([a-z][a-z0-9_-]{0,39})', text, re.I)
    if m:
        name = m.group(1).casefold()
        doc = load().get('jobs', {}).get(name)
        if not doc:
            raise error('Unknown registered job: ' + name, 1)
        definition, doc = _validate_registered_job(name, load, error)
        authority = _authority(definition, helper, configured_nodes, sha_file, error)
        jid = 'computer-job-' + name + '-' + secrets.token_hex(8)
        pending = {'schema': 'scotty.computer.pending/1', 'intent': 'JOB_EXECUTE',
                   'created_at': time.time(), 'definition': definition, 'definition_sha256': doc['definition_sha256'],
                   'authority': authority, 'run_id': jid}
        rules = load().get('job_exceptions', {}).get(name, [])
        pending['exceptions'] = rules
        pending['exceptions_sha256'] = _fingerprint(rules)
        policy = load().get('job_policies', {}).get(name)
        if policy is not None:
            if policy.get('mode') != 'repeat-readonly' or not _repeat_readonly(definition) or policy.get('definition_sha256') != doc['definition_sha256'] or policy.get('authority') != authority:
                raise error('Reusable policy authority or definition changed; execution blocked (review policy)', 4)
            print('JOB_POLICY_RUN name=' + name + ' policy=repeat-readonly definition_sha256=' + doc['definition_sha256'], flush=True)
            return confirm(pending, load, save, error,
                           helper, configured_nodes, sha_file, config_dir, reused_policy=True)
        token = create(pending)
        print('JOB_EXECUTION_PREVIEW name=' + name + ' NOT EXECUTED')
        _show(definition, authority, jid)
        print('Operator MUST inspect actual argv and authorize this individual execution.')
        print('CONFIRM_RUN=Computer confirm ' + token)
        return 3
    raise error('Use Computer job help for supported job intention grammar', 2)



def _stop_timed_out_process(proc):
    """End a timed-out local process *group*, not just its leader.

    Each Computer job is started in a fresh POSIX session. Children that stay in
    this process group are included in SIGKILL. A child which explicitly detaches
    into another session, and a process on the far side of SSH, are NOT covered.
    Return a factual termination-attempt record, not a success guarantee.
    """
    if os.name == 'posix':
        try:
            os.killpg(proc.pid, signal.SIGKILL)
            attempted = 'posix_process_group_sigkill'
        except ProcessLookupError:
            attempted = 'posix_group_already_exited'
        except OSError:
            # A group operation can be refused. Try to kill the leader so the
            # caller can at least reap it; preserve the narrower claim.
            proc.kill()
            attempted = 'leader_sigkill_group_failed'
    else:
        proc.kill()
        attempted = 'leader_only_platform_fallback'
    proc.wait()
    return attempted


def confirm(doc, load, save, error, helper, configured_nodes, sha_file, config_dir, reused_policy=False):
    intent = doc.get('intent')
    definition = _validate_definition(doc['definition'], error)
    if _fingerprint(definition) != doc.get('definition_sha256'):
        raise error('Definition changed since approval', 4)
    if intent == 'JOB_EXCEPTION_REGISTER':
        state = load()
        name = definition['name']
        if state.get('jobs', {}).get(name, {}).get('definition_sha256') != doc['definition_sha256']:
            raise error('Job definition changed during exception registration', 4)
        if _authority(definition, helper, configured_nodes, sha_file, error) != doc['authority']:
            raise error('Job authority changed during exception registration', 4)
        previous = state.get('job_exceptions', {}).get(name, [])
        proposed = doc.get('exceptions', [])
        if _fingerprint(previous) != doc.get('before_sha256') or _fingerprint(proposed) != doc.get('after_sha256') or len(proposed) != len(previous)+1:
            raise error('Exception rules changed during review', 4)
        from ComputerExceptions import MAX_RULES
        if len(proposed) > MAX_RULES:
            raise error('Too many registered exceptions', 4)
        if proposed[-1]['type'] == 'runaway_space':
            validate_directory(Path(proposed[-1]['path']), error)
        state.setdefault('job_exceptions', {})[name] = proposed
        save(state)
        print('JOB_EXCEPTION_REGISTERED name=' + name + ' type=' + proposed[-1]['type'])
        print('EXCEPTIONS_SHA256=' + _fingerprint(proposed))
        return 0
    if intent == 'JOB_POLICY':
        state = load()
        installed = state.get('jobs', {}).get(definition['name'])
        if not installed or installed.get('definition_sha256') != doc['definition_sha256']:
            raise error('Job registration changed since policy preview', 4)
        if _authority(definition, helper, configured_nodes, sha_file, error) != doc['authority']:
            raise error('Job authority changed since policy preview', 4)
        policy = doc.get('policy')
        if policy == 'repeat-readonly' and _repeat_readonly(definition):
            state.setdefault('job_policies', {})[definition['name']] = {
                'mode': policy, 'definition_sha256': doc['definition_sha256'],
                'authority': doc['authority'], 'approved_at': time.time()}
        elif policy == 'manual':
            state.setdefault('job_policies', {}).pop(definition['name'], None)
        else:
            raise error('Not a permitted reusable authority policy', 4)
        save(state)
        print('JOB_POLICY_APPLIED name=' + definition['name'] + ' mode=' + policy)
        return 0
    if intent == 'JOB_REVOKE':
        state = load()
        installed = state.get('jobs', {}).get(definition['name'])
        if not installed or installed.get('definition_sha256') != doc['definition_sha256']:
            raise error('Job registry changed since revocation preview', 4)
        del state['jobs'][definition['name']]
        state.setdefault('job_policies', {}).pop(definition['name'], None)
        state.setdefault('job_exceptions', {}).pop(definition['name'], None)
        save(state)
        print('JOB_REVOKED name=' + definition['name'] + ' sha256=' + str(doc['definition_sha256']))
        return 0
    authority = _authority(definition, helper, configured_nodes, sha_file, error)
    if authority != doc['authority']:
        raise error('Executable/sshnode authority changed; no execution', 4)
    if intent == 'JOB_ACTIVATE':
        state = load()
        registry = state.setdefault('jobs', {})
        if definition['name'] in registry:
            raise error('Job name already registered', 4)
        registry[definition['name']] = {**definition, 'definition_sha256': doc['definition_sha256'], 'registered_at': time.time()}
        save(state)
        print('JOB_REGISTERED name=' + definition['name'] + ' sha256=' + str(doc['definition_sha256']))
        print('To preview first run: Computer job run ' + definition['name'])
        return 0
    if intent != 'JOB_EXECUTE':
        raise error('Unsupported job pending intent', 4)
    installed = load().get('jobs', {}).get(definition['name'])
    if not installed or installed.get('definition_sha256') != doc['definition_sha256']:
        raise error('Job registration changed or disappeared; no execution', 4)
    if reused_policy:
        current = load().get('job_policies', {}).get(definition['name'])
        if not current or current.get('mode') != 'repeat-readonly' or not _repeat_readonly(definition) or current.get('definition_sha256') != doc['definition_sha256'] or current.get('authority') != authority:
            raise error('Reusable job policy was withdrawn or changed', 4)
    rules = doc.get('exceptions', [])
    if _fingerprint(rules) != doc.get('exceptions_sha256') or _fingerprint(load().get('job_exceptions', {}).get(definition['name'], [])) != doc['exceptions_sha256']:
        raise error('Registered job exception rules changed since run preview; re-preview required', 4)
    for rule in rules:
        if rule['type'] == 'runaway_space':
            validate_directory(Path(rule['path']), error)
    run_id = doc['run_id']
    if not re.fullmatch(r'computer-job-[a-z][a-z0-9_-]{0,39}-[a-f0-9]{16}', run_id):
        raise error('Invalid recorded job id', 4)
    argv = _actual_argv(definition, authority, run_id)
    print('JOB_EXECUTE name=' + definition['name'] + ' run_id=' + run_id, flush=True)
    _show(definition, authority, run_id)
    if os.environ.get('COMPUTER_DRY_RUN') == '1':
        print('DRY_RUN: confirmation consumed, process NOT executed')
        return 0
    root = config_dir() / 'jobs'
    if root.is_symlink():
        raise error('Unsafe job receipts directory', 4)
    root.mkdir(mode=0o700, parents=True, exist_ok=True)
    os.chmod(root, 0o700)
    out_path, err_path = root / (run_id + '.stdout'), root / (run_id + '.stderr')
    for target in (out_path, err_path):
        if target.exists() or target.is_symlink():
            raise error('Job receipt path already exists', 4)
    flags = os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW
    try:
        ofd = os.open(out_path, flags, 0o600)
        efd = os.open(err_path, flags, 0o600)
    except OSError as exc:
        if 'ofd' in locals():
            os.close(ofd)
        raise error('Cannot create job receipts: ' + str(exc), 5) from exc
    started_at = dt.datetime.now(dt.timezone.utc).isoformat()
    start = time.monotonic()
    observer = RunObserver(rules, out_path, err_path) if rules else None
    termination_attempt = None
    try:
        with os.fdopen(ofd, 'wb') as outf, os.fdopen(efd, 'wb') as errf:
            proc = None
            try:
                # Both observed and ordinary jobs get an isolated POSIX process
                # group. subprocess.run(timeout=...) kills only the group leader.
                proc = subprocess.Popen(argv, cwd=definition['cwd'], stdout=outf, stderr=errf,
                                        start_new_session=(os.name == 'posix'))
                status, code = 'EXITED', None
                if observer is None:
                    try:
                        code = proc.wait(timeout=definition['timeout'])
                    except subprocess.TimeoutExpired:
                        termination_attempt = _stop_timed_out_process(proc)
                        status, code = 'TIMEOUT', 124
                else:
                    # Observe only during this invocation. A registered
                    # exception records evidence but NEVER ends a job.
                    observer.tick()
                    while code is None:
                        code = proc.poll()
                        if code is not None:
                            break
                        if time.monotonic() - start >= definition['timeout']:
                            termination_attempt = _stop_timed_out_process(proc)
                            status, code = 'TIMEOUT', 124
                            break
                        time.sleep(min(SAMPLE_SECONDS, max(0.001, definition['timeout'] - (time.monotonic() - start))))
                        outf.flush(); errf.flush()
                        observer.tick()
            except OSError as exc:
                code, status = 127, 'LAUNCH_FAILED'
                errf.write(('Launch failed: ' + str(exc) + '\n').encode('utf-8', errors='replace'))
            except BaseException:
                # Do not leave the job running if Computer itself is interrupted
                # after launch but before a receipt can be committed.
                if proc is not None and proc.poll() is None:
                    _stop_timed_out_process(proc)
                raise
            finally:
                if observer is not None:
                    outf.flush(); errf.flush()
    finally:
        print('RECEIPT stdout=' + str(out_path) + ' stderr=' + str(err_path), flush=True)
    exception_report = observer.finish() if observer else {
        'schema': 'scotty.computer.job-exceptions/1', 'registered': [],
        'raised': [], 'count': 0, 'observation_complete': True,
        'samples': 0, 'policy': 'no registered exception rules'}
    duration = round(time.monotonic() - start, 3)
    metadata = {'schema': RUN_SCHEMA, 'run_id': run_id, 'job': definition['name'],
                'target': definition['node'] or 'local', 'definition_sha256': doc['definition_sha256'],
                'authority': authority, 'status': status, 'child_rc': code,
                'started_at': started_at, 'finished_at': dt.datetime.now(dt.timezone.utc).isoformat(),
                'elapsed_seconds': duration, 'stdout_path': str(out_path), 'stderr_path': str(err_path),
                'stdout_bytes': out_path.stat().st_size, 'stderr_bytes': err_path.stat().st_size,
                'exceptions_sha256': doc['exceptions_sha256'], 'exceptions': exception_report,
                'policy': 'repeat-readonly' if reused_policy else 'confirmed-per-run',
                'termination_attempt': termination_attempt,
                'termination_scope': ('local_process_group_only' if os.name == 'posix' else 'direct_child_only')}
    _write_run_record(root, metadata, error)
    print('RESULT status=' + status + ' rc=' + str(code) + ' elapsed_seconds=' + str(duration))
    if termination_attempt:
        print('TERMINATION_ATTEMPT=' + termination_attempt + ' SCOPE=' + ('local_process_group_only' if os.name == 'posix' else 'direct_child_only'))
    print('JOB_RESULT_COMMAND=Computer job result ' + run_id)
    print('JOB_STDERR_COMMAND=Computer job stderr ' + run_id)
    print('OUTPUT_BYTES stdout=' + str(out_path.stat().st_size) + ' stderr=' + str(err_path.stat().st_size))
    print('EXCEPTION_REPORT count=' + str(exception_report['count']) + ' complete=' + str(exception_report['observation_complete']).lower() + ' samples=' + str(exception_report['samples']))
    for event in exception_report['raised']:
        print('EXCEPTION type=' + event['type'] + ' observed=' + json.dumps(event['observed'], sort_keys=True))
    if exception_report['count'] or not exception_report['observation_complete']:
        print('JOB_OUTCOME=EXCEPTION_REPORTED (child_rc is separate; job was not killed by rule)')
        return 6
    return 0 if code == 0 else (4 if code == 124 else 5)
