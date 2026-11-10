"""GitHub intentions. Git handles SSH; Computer never constructs identity overrides.

Network reads (clone/fetch/pull) are explicit, command-array operations.
Writes require a scoped, single-use confirmation with revalidation.
"""
import hashlib
import json
import os
from pathlib import Path
import re
import shlex
import shutil
import subprocess
import time
from urllib.parse import urlparse


class GithubError(Exception):
    def __init__(self, message, rc=4):
        super().__init__(message)
        self.rc = rc


def _run(argv, timeout=30, capture=True, check=True):
    try:
        p = subprocess.run(argv, text=True, stdout=subprocess.PIPE if capture else None,
                           stderr=subprocess.PIPE if capture else None, timeout=timeout, check=False)
    except (OSError, subprocess.TimeoutExpired) as e:
        raise GithubError(f'Command could not finish: {e}', 5) from e
    if check and p.returncode:
        raise GithubError(f'Command failed (rc={p.returncode}): {shlex.join(argv[:4])} — {(p.stderr or "").strip()[:360]}', 5)
    return p


def _git(repo, *args, check=True):
    return _run(['git', '-C', str(repo), *args], check=check)


def _repo(value):
    p = Path(os.path.expanduser(value)).resolve()
    if not p.is_dir():
        raise GithubError('Repository directory does not exist', 3)
    root = _git(p, 'rev-parse', '--show-toplevel').stdout.strip()
    if Path(root).resolve() != p:
        raise GithubError('Specify the exact repository root; nested path refused', 3)
    return p


def _parse_remote(url):
    """Return ('ssh', alias) or ('https', hostname), with no authentication assumptions."""
    m = re.fullmatch(r'(?:git@)([A-Za-z0-9][A-Za-z0-9_.-]*):([A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+)(?:\.git)?', url)
    if m:
        return 'ssh', m.group(1)
    m = re.fullmatch(r'ssh://(?:git@)?([A-Za-z0-9][A-Za-z0-9_.-]*)/(?:(?:[A-Za-z0-9_.-]+/)[A-Za-z0-9_.-]+)(?:\.git)?', url)
    if m:
        return 'ssh', m.group(1)
    m = re.fullmatch(r'https://([A-Za-z0-9][A-Za-z0-9_.-]*)/[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+(?:\.git)?/?', url)
    if m:
        return 'https', m.group(1)
    raise GithubError('Unsupported remote URL: use explicit GitHub HTTPS or configured SSH alias', 4)


def _ssh_profile(alias):
    p = _run(['ssh', '-G', alias], timeout=10)
    data = {}
    for line in p.stdout.splitlines():
        k, _, v = line.partition(' ')
        if k in {'hostname', 'user', 'identityfile', 'identitiesonly', 'port', 'proxyjump', 'proxycommand'}:
            data.setdefault(k, []).append(v)
    return data


def _remote(repo, write=False):
    url = _git(repo, 'remote', 'get-url', *(['--push'] if write else []), 'origin').stdout.strip()
    kind, host = _parse_remote(url)
    ssh = _ssh_profile(host) if kind == 'ssh' else {}
    resolved = ssh.get('hostname', [host])[0] if ssh else host
    approved = {'github.com'} | {v.strip().lower() for v in os.environ.get('COMPUTER_GITHUB_HOSTS', '').split(',') if v.strip()}
    if resolved.lower() not in approved:
        raise GithubError(f'Remote resolves to {resolved}, not an approved GitHub host. Set COMPUTER_GITHUB_HOSTS explicitly for GitHub Enterprise.', 4)
    return {'url': url, 'kind': kind, 'alias': host, 'resolved_host': resolved,
            'ssh': ssh, 'core_ssh_command': _git(repo, 'config', '--get', 'core.sshCommand', check=False).stdout.strip(),
            'env_ssh_override': bool(os.environ.get('GIT_SSH_COMMAND') or os.environ.get('GIT_SSH'))}


def _preview_remote(info):
    print('REMOTE_URL=' + info['url'])
    print('AUTH_TRANSPORT=' + info['kind'] + ' ALIAS=' + info['alias'] + ' RESOLVED_HOST=' + info['resolved_host'])
    if info['kind'] == 'ssh':
        print('SSH_CONFIG (ssh -G; keys NOT read; no -i overrides):')
        for k in ('user', 'hostname', 'port', 'identityfile', 'identitiesonly'):
            print('  ' + k + '=' + ', '.join(info['ssh'].get(k, [])))
    if info['core_ssh_command']:
        print('REPOSITORY_CORE_SSH_COMMAND=' + info['core_ssh_command'])
    if info['env_ssh_override']:
        print('WARNING GIT_SSH or GIT_SSH_COMMAND overrides repository/SSH settings')


def _command(argv, label, timeout=180):
    print('ARGV=' + json.dumps(argv))
    print('COMMAND=' + shlex.join(argv), flush=True)
    if os.environ.get('COMPUTER_DRY_RUN') == '1':
        print('DRY_RUN ' + label)
        return 0
    res = _run(argv, capture=False, timeout=timeout)
    print('OK ' + label)
    return res.returncode


def _branch(repo):
    branch = _git(repo, 'symbolic-ref', '--quiet', '--short', 'HEAD', check=False)
    b = branch.stdout.strip()
    if branch.returncode or not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9._/-]*', b) or '..' in b or b.endswith('.lock'):
        raise GithubError('Current branch is detached or unsafe; explicit branch required', 4)
    return b


def _file_sha256(path):
    h = hashlib.sha256()
    with path.open('rb') as src:
        for chunk in iter(lambda: src.read(1024 * 1024), b''):
            h.update(chunk)
    return h.hexdigest()


def _fingerprint(repo):
    """Fingerprint index, HEAD and tree; disallow unsafe implicit staging."""
    head = _git(repo, 'rev-parse', 'HEAD').stdout.strip()
    stage = _git(repo, 'ls-files', '--stage', '-z').stdout
    diff = _git(repo, 'diff', '--cached', '--raw', '-z').stdout
    digest = hashlib.sha256((head + '\x00' + stage + '\x00' + diff).encode()).hexdigest()
    return {'head': head, 'index_sha256': digest}


def _begin(kind, repo, argv, create, extra=None):
    info = _remote(repo, write=(kind == 'GITHUB_PUSH')) if kind != 'GITHUB_STAGE' else None
    if info and info['env_ssh_override']:
        raise GithubError('GIT_SSH(_COMMAND) override present; clear it or use explicit reviewed workflow before write', 4)
    evidence = _fingerprint(repo)
    doc = {'schema': 'scotty.computer.pending/1', 'intent': kind,
           'created_at': time.time(), 'repo': str(repo), 'argv': argv, 'fingerprint': evidence,
           'remote': info, 'extra': extra or {}}
    token = create(doc)
    print('NOT EXECUTED: ' + kind)
    if info: _preview_remote(info)
    print('HEAD=' + evidence['head'] + ' INDEX_SHA256=' + evidence['index_sha256'])
    print('ARGV=' + json.dumps(argv))
    print('COMMAND=' + shlex.join(argv))
    print('VERIFY exact argument and option order, branch, repository and SSH identity before confirming.')
    if kind == 'GITHUB_COMMIT':
        print('NOTE: Git commit hooks and filters are repository-controlled and can execute programs. Review repository policy first.')
    print('Computer confirm ' + token)
    return 3


def _destination(value):
    path = Path(os.path.expanduser(value))
    if not path.is_absolute():
        raise GithubError('Clone destination must be an absolute path', 3)
    if path.exists() or path.is_symlink():
        raise GithubError('Clone destination already exists; refusing overwrite', 4)
    parent = path.parent
    if not parent.is_dir() or parent.is_symlink():
        raise GithubError('Clone destination parent must exist and must not be a symlink', 4)
    p = path.resolve()
    home = Path.home().resolve()
    if home not in p.parents:
        raise GithubError('Clone destination must be under HOME (no unexpected system writes)', 4)
    if not os.access(parent, os.W_OK):
        raise GithubError('Clone destination parent is not writable', 4)
    return p


def github(text, create):
    if text == 'github help':
        print('github inspect|status|remotes|ssh|fetch|pull REPO')
        print('github clone GITHUB_URL to ABSOLUTE_DESTINATION')
        print('github stage REPO file RELATIVE_FILE (preview/confirm)')
        print('github commit REPO message "MESSAGE" (only staged content; preview/confirm)')
        print('github push REPO (current branch to origin; preview/confirm, never force)')
        return 0
    m = re.fullmatch(r'github\s+clone\s+(.+?)\s+to\s+(.+)', text, re.I)
    if m:
        url, dst = [v.strip().strip('"\'') for v in m.groups()]
        kind, host = _parse_remote(url)
        info = _ssh_profile(host) if kind == 'ssh' else {}
        resolved = info.get('hostname', [host])[0] if info else host
        approved = {'github.com'} | {v.strip().lower() for v in os.environ.get('COMPUTER_GITHUB_HOSTS', '').split(',') if v.strip()}
        if resolved.lower() not in approved:
            raise GithubError('Clone alias does not resolve to an approved GitHub host', 4)
        target = _destination(dst)
        print(f'CLONE_AUTH={kind} alias={host} resolved_host={resolved} (git/SSH use existing per-project keys)')
        if os.environ.get('GIT_SSH_COMMAND') or os.environ.get('GIT_SSH'):
            print('WARNING GIT_SSH or GIT_SSH_COMMAND override present; Git may not use ~/.ssh/config')
        return _command(['git', 'clone', '--', url, str(target)], 'github clone', 300)
    m = re.fullmatch(r'github\s+(inspect|status|remotes|ssh|fetch|pull|push)\s+(.+)', text, re.I)
    if m:
        op, value = m.group(1).lower(), m.group(2).strip().strip('"\'')
        repo = _repo(value)
        if op == 'status':
            return _command(['git','-C',str(repo),'status','--short','--branch'], 'github status')
        if op in {'inspect', 'remotes', 'ssh'}:
            info = _remote(repo, write=(op == 'ssh'))
            print('REPO=' + str(repo))
            print('BRANCH=' + _branch(repo))
            _preview_remote(info)
            print('LOCAL_SSH_CONFIG_UNCHANGED')
            return 0
        if op == 'fetch':
            _preview_remote(_remote(repo))
            return _command(['git','-C',str(repo),'fetch','--no-tags','origin'], 'github fetch', 300)
        if op == 'pull':
            _preview_remote(_remote(repo))
            if _git(repo, 'status', '--porcelain').stdout.strip():
                raise GithubError('Working tree has changes; pull refused rather than overwrite', 4)
            return _command(['git','-C',str(repo),'pull','--ff-only','origin',_branch(repo)], 'github pull', 300)
        if op == 'push':
            branch = _branch(repo)
            return _begin('GITHUB_PUSH', repo, ['git','-C',str(repo),'push','origin',f'refs/heads/{branch}:refs/heads/{branch}'], create)
    m = re.fullmatch(r'github\s+stage\s+(.+?)\s+file\s+(.+)', text, re.I)
    if m:
        repo = _repo(m.group(1).strip('"\''))
        name = m.group(2).strip().strip('"\'')
        candidate = Path(name)
        if candidate.is_absolute() or not name or any(x in {'..', '.git'} for x in candidate.parts) or any(c in name for c in '*?[]'):
            raise GithubError('Stage requires explicit repository-relative non-glob path', 3)
        file = (repo / candidate).resolve()
        if repo not in file.parents or not file.is_file() or file.is_symlink():
            raise GithubError('Stage source must be a regular file within the repository', 4)
        digest = _file_sha256(file)
        return _begin('GITHUB_STAGE', repo, ['git','-C',str(repo),'add','--',name], create,
                      {'stage_path': name, 'sha256': digest})
    m = re.fullmatch(r'github\s+commit\s+(.+?)\s+message\s+(.+)', text, re.I)
    if m:
        repo = _repo(m.group(1).strip('"\''))
        message = m.group(2).strip().strip('"\'')
        if not message or len(message) > 512 or any(c in message for c in '\n\r\x00'):
            raise GithubError('Commit message must be one line of 1..512 characters', 3)
        staged = _git(repo, 'diff', '--cached', '--name-only').stdout.strip()
        if not staged:
            raise GithubError('No staged changes. Stage explicit files first; Computer will not git add -A.', 3)
        print('STAGED_FILES:\n' + staged)
        return _begin('GITHUB_COMMIT', repo, ['git','-C',str(repo),'commit','-m',message], create)
    raise GithubError('Unknown GitHub intention. Use: Computer github help', 2)


def confirm(doc):
    kind = doc.get('intent')
    if kind not in {'GITHUB_STAGE', 'GITHUB_COMMIT', 'GITHUB_PUSH'}:
        raise GithubError('Invalid GitHub confirmation intent', 4)
    repo = _repo(doc['repo'])
    if _fingerprint(repo) != doc['fingerprint']:
        raise GithubError('Git HEAD/index changed since preview; repeat command', 4)
    if doc['remote'] is not None and _remote(repo, write=(kind == 'GITHUB_PUSH')) != doc['remote']:
        raise GithubError('Git remote/SSH identity resolution changed; repeat command', 4)
    expected = doc['argv']
    if not isinstance(expected,list) or len(expected) < 5 or expected[:3] != ['git','-C',str(repo)]:
        raise GithubError('Confirmation command structure corrupted', 4)
    if kind == 'GITHUB_STAGE':
        name = doc['extra']['stage_path']
        src = (repo / name).resolve()
        if expected != ['git','-C',str(repo),'add','--',name] or not src.is_file() or src.is_symlink() or repo not in src.parents or _file_sha256(src) != doc['extra']['sha256']:
            raise GithubError('Stage file or command changed since preview', 4)
    elif kind == 'GITHUB_COMMIT':
        if expected[:4] != ['git','-C',str(repo),'commit'] or expected[4] != '-m' or len(expected) != 6:
            raise GithubError('Commit command changed',4)
        if not _git(repo,'diff','--cached','--name-only').stdout.strip():
            raise GithubError('Staged changes disappeared',4)
    elif kind == 'GITHUB_PUSH':
        branch = _branch(repo)
        if expected != ['git','-C',str(repo),'push','origin',f'refs/heads/{branch}:refs/heads/{branch}']:
            raise GithubError('Branch changed since preview',4)
    return _command(expected, kind.lower(), 300)
