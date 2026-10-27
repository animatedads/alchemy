#!/usr/bin/env python3
"""Bounded, authority-rechecking execution adapter for the ooRexx Computer client.

Public entry is exclusively --intent ID --hex HEX.  This module neither
executes raw natural language nor evaluates user-supplied shell source.
"""
import argparse
import secrets
import uuid
import datetime as dt
import hashlib
import fcntl
import json
import os
from pathlib import Path
import re
import shlex
import shutil
import stat
import subprocess
import sys
import tempfile
import time
import zipfile

KNOWN = {"HELP", "DISCOVER", "CHECK_FREE_SPACE", "CHECK_FREE_MEMORY",
         "DEPLOY_ZIPFILE", "CONFIRM_ACTION", "RUN_TESTS", "ADD_FIND_LOCATION", "ADD_TEMP_DIRECTORY",
         "RECENT_FILES", "CONTENT_SEARCH", "LATEST_CLASS", "REXXPATH_SHOW",
         "REXXPATH_SETUP", "SSH_LOGIN", "FIREWALL_REPAIR", "CONFIG_SHOW", "FILE_INTEGRITY", "INSTRUCTIONS", "SEARCH_SCOPES", "ADD_SEARCH_SCOPE", "SEARCH_NAMED", "GITHUB", "LEARN", "RUN_LEARNED", "JOBS", "READ_DOCUMENT", "FIND_DIRECTORIES"}
MAX_WALK_FILES = 50000
MAX_WALK_DEPTH = 16
MAX_RESULTS = 40
MAX_READ_BYTES = 4 * 1024 * 1024
MAX_ZIP_MEMBERS = 4000
MAX_MEMBER_BYTES = 1024 * 1024
VERSION = "0.1-dev10"
CONFIRM_TTL_SECONDS = 600
MAX_DEPLOY_BYTES = 2 * 1024 * 1024 * 1024


class ComputerError(Exception):
    def __init__(self, message, status=3):
        super().__init__(message)
        self.status = status


def config_dir():
    home = Path.home()
    return (Path(os.environ["XDG_CONFIG_HOME"]).expanduser() if os.environ.get("XDG_CONFIG_HOME")
            else home / ".config") / "scotty-computer"


def config_path():
    return config_dir() / "state.json"


def canonical(value):
    if not value or "\x00" in value or "\n" in value:
        raise ComputerError("Invalid directory path")
    return Path(os.path.expandvars(os.path.expanduser(value))).resolve()


def load_state():
    f = config_path()
    if not f.exists():
        return {"schema": "scotty.computer.state/1", "search_roots": [], "temp_roots": [], "search_scopes": {}, "learned": {}, "jobs": {}}
    if f.is_symlink():
        raise ComputerError("State path is a symlink; refusing to follow it")
    if f.stat().st_size > 256 * 1024:
        raise ComputerError("State file is unexpectedly large")
    try:
        obj = json.loads(f.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        raise ComputerError(f"Cannot read state: {exc}") from exc
    if not isinstance(obj, dict) or obj.get("schema") != "scotty.computer.state/1":
        raise ComputerError("Unrecognised state schema")
    for k in ("search_roots", "temp_roots"):
        if not isinstance(obj.get(k), list) or not all(isinstance(v, str) for v in obj[k]):
            raise ComputerError(f"Invalid {k} state")
    policies = obj.setdefault('job_policies', {})
    if not isinstance(policies, dict):
        raise ComputerError('Invalid job policy registry')
    scopes = obj.setdefault('search_scopes', {})
    if not isinstance(scopes, dict) or any(not isinstance(k, str) or not isinstance(v, list) or not all(isinstance(x, str) for x in v) for k,v in scopes.items()):
        raise ComputerError('Invalid search scopes state')
    learned = obj.setdefault('learned', {})
    if not isinstance(learned, dict):
        raise ComputerError('Invalid learned registry')
    jobs = obj.setdefault('jobs', {})
    if not isinstance(jobs, dict):
        raise ComputerError('Invalid job registry')
    return obj


def save_state(obj):
    base = config_dir()
    base.mkdir(parents=True, exist_ok=True, mode=0o700)
    if base.is_symlink():
        raise ComputerError("Configuration directory is a symlink")
    os.chmod(base, 0o700)
    if config_path().is_symlink():
        raise ComputerError("State file is a symlink")
    fd, path = tempfile.mkstemp(prefix=".state-", suffix=".json", dir=base)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as out:
            json.dump(obj, out, indent=2, sort_keys=True)
            out.write("\n")
            out.flush()
            os.fsync(out.fileno())
        os.chmod(path, 0o600)
        os.replace(path, config_path())
    finally:
        if os.path.exists(path):
            os.unlink(path)


def extract_path(text, tail):
    m = re.fullmatch(r"add\s+(.+?)\s+to\s+my\s+" + tail + r"\s*", text, re.I)
    if not m:
        raise ComputerError("Please specify an existing directory and its intended role")
    raw = m.group(1).strip().strip('"\'')
    directory = canonical(raw)
    if not directory.is_dir():
        raise ComputerError(f"Directory does not exist: {directory}")
    if not os.access(directory, os.R_OK | os.X_OK):
        raise ComputerError(f"Directory is not searchable: {directory}")
    return directory


def add_root(text, temporary):
    tail = r"permitted\s+temporary\s+file\s+director(?:y|ies)" if temporary else r"find\s+file\s+locations?"
    root = extract_path(text, tail)
    if temporary and not os.access(root, os.W_OK):
        raise ComputerError(f"Temporary directory is not writable: {root}")
    obj = load_state()
    key = "temp_roots" if temporary else "search_roots"
    if str(root) in obj[key]:
        print(f"ALREADY_PRESENT {key}: {root}")
        return 0
    obj[key].append(str(root))
    save_state(obj)
    print(f"ADDED {key}: {root}")
    return 0


def show_config():
    print(json.dumps(load_state(), indent=2, sort_keys=True))
    return 0


def roots():
    obj = load_state()
    paths = [canonical(p) for p in obj["search_roots"]]
    valid = [p for p in paths if p.is_dir()]
    if not valid:
        raise ComputerError("No accessible search roots. Use: Computer add ~/Downloads to my find file locations")
    return valid


def walk_files(start_paths):
    """Bounded, non-symlink-recursing local scan; OS errors remain visible as warnings."""
    visited_dirs = set()
    total = 0
    for root in start_paths:
        todo = [(root, 0)]
        while todo:
            directory, depth = todo.pop()
            if depth > MAX_WALK_DEPTH:
                continue
            try:
                ds = directory.stat()
                key = (ds.st_dev, ds.st_ino)
                if key in visited_dirs:
                    continue
                visited_dirs.add(key)
                with os.scandir(directory) as scan:
                    entries = list(scan)
                entries.sort(key=lambda e: e.name)
            except OSError as exc:
                print(f"WARNING scan_skipped={directory}: {exc}", file=sys.stderr)
                continue
            for e in entries:
                try:
                    if e.is_symlink():
                        continue
                    if e.is_dir(follow_symlinks=False):
                        if depth < MAX_WALK_DEPTH:
                            todo.append((Path(e.path), depth + 1))
                    elif e.is_file(follow_symlinks=False):
                        total += 1
                        if total > MAX_WALK_FILES:
                            raise ComputerError(f"Scan bounded at {MAX_WALK_FILES} files; narrow search roots")
                        yield Path(e.path), e.stat(follow_symlinks=False)
                except OSError:
                    continue


def latest_timestamp(st):
    if hasattr(st, "st_birthtime") and st.st_birthtime > 0:
        return st.st_birthtime, "BIRTH_TIME"
    return st.st_ctime, "INODE_CTIME_PROXY"


def recent(text):
    m = re.search(r"\bpast\s+(\d+)\s+minutes?\b", text, re.I)
    if not m:
        raise ComputerError("Specify a bounded window: 'past 30 minutes'")
    mins = int(m.group(1))
    if not 1 <= mins <= 10080:
        raise ComputerError("Time window must be 1..10080 minutes")
    cutoff = time.time() - 60 * mins
    candidates = []
    for path, st in walk_files(roots()):
        seen, source = latest_timestamp(st)
        if seen >= cutoff:
            candidates.append((seen, source, path))
    candidates.sort(reverse=True, key=lambda x: (x[0], str(x[2])))
    print(f"FOUND {len(candidates)} files within past {mins} minutes (receipt time is not verified)")
    for when, source, path in candidates[:MAX_RESULTS]:
        print(f"{dt.datetime.fromtimestamp(when, dt.timezone.utc).isoformat()} {source} {path}")
    if len(candidates) > MAX_RESULTS:
        print(f"TRUNCATED showing {MAX_RESULTS} of {len(candidates)}")
    return 0


def contents(text):
    m = re.fullmatch(r"which\s+file\s+has\s+(.+)", text, re.I | re.S)
    if not m:
        raise ComputerError("Use: Computer which file has TEXT")
    needle = m.group(1).strip().strip('"\'')
    if not needle or len(needle) > 1024:
        raise ComputerError("Content search phrase must be 1..1024 characters")
    hits = []
    scan_count = 0
    for path, st in walk_files(roots()):
        if len(hits) >= MAX_RESULTS:
            break
        if st.st_size > MAX_READ_BYTES or st.st_size == 0:
            continue
        if path.suffix.lower() in {".zip", ".jar"}:
            try:
                with zipfile.ZipFile(path) as z:
                    if len(z.infolist()) > MAX_ZIP_MEMBERS:
                        continue
                    for member in z.infolist():
                        if member.is_dir() or member.file_size > MAX_MEMBER_BYTES or member.flag_bits & 1:
                            continue
                        if member.filename.startswith("/") or ".." in Path(member.filename).parts:
                            continue
                        try:
                            with z.open(member) as f:
                                data = f.read(MAX_MEMBER_BYTES + 1)
                            snippet = first_match(data, needle)
                            if snippet:
                                hits.append((str(path) + "!" + member.filename, snippet))
                        except (OSError, RuntimeError, ValueError):
                            continue
                        if len(hits) >= MAX_RESULTS:
                            break
            except (OSError, zipfile.BadZipFile, ValueError):
                continue
        else:
            scan_count += 1
            if path.suffix.lower() in {".mp4", ".webm", ".pdf", ".png", ".jpg", ".so", ".deb", ".gz"}:
                continue
            try:
                with path.open("rb") as f:
                    data = f.read(MAX_READ_BYTES + 1)
                snippet = first_match(data, needle)
                if snippet:
                    hits.append((str(path), snippet))
            except (OSError, UnicodeError):
                continue
    print(f"CONTENT_MATCHES {len(hits)} (limit {MAX_RESULTS}; binary/large files omitted)")
    for path, line in hits:
        print(f"{path}\t{line}")
    if len(hits) == MAX_RESULTS:
        print("TRUNCATED at result limit")
    return 0


def first_match(data, needle):
    if len(data) > MAX_READ_BYTES or b"\x00" in data[:4096]:
        return None
    text = data.decode("utf-8", errors="replace")
    for n, line in enumerate(text.splitlines(), 1):
        if needle.casefold() in line.casefold():
            excerpt = line.strip().replace("\t", " ")[:180]
            return f"line={n} {excerpt}"
    return None


def version_of(text):
    versions = re.findall(r"(?:^|[^A-Za-z0-9])v?(\d+)\.(\d+)(?:\.(\d+))?", text, re.I)
    return max(((int(a), int(b), int(c or 0)) for a, b, c in versions), default=(-1, -1, -1))


def latest_class(text):
    m = re.fullmatch(r"find\s+(?:the\s+)?latest\s+copy\s+of\s+(.+)", text, re.I)
    if not m:
        raise ComputerError("Use: Computer find the latest copy of Crypto rexx class")
    subject = re.sub(r"\b(?:rexx|ooRexx|class|file|\.cls)\b", "", m.group(1), flags=re.I).strip(" .")
    if not subject or len(subject) > 100:
        raise ComputerError("Class name is missing")
    tokens = [p.casefold() for p in subject.split()]
    found = []
    for path, st in walk_files(roots()):
        if path.suffix.lower() == ".cls" and all(t in path.name.casefold() for t in tokens):
            found.append((version_of(str(path)), st.st_mtime, str(path)))
        elif path.suffix.lower() == ".zip" and st.st_size <= 1024 * 1024 * 1024:
            try:
                with zipfile.ZipFile(path) as z:
                    if len(z.infolist()) > MAX_ZIP_MEMBERS:
                        continue
                    for member in z.infolist():
                        if not member.is_dir() and member.filename.lower().endswith(".cls") and all(t in member.filename.rsplit("/", 1)[-1].casefold() for t in tokens):
                            found.append((version_of(str(path)), st.st_mtime, f"{path}!{member.filename}"))
            except (OSError, zipfile.BadZipFile):
                continue
    found.sort(key=lambda row: (row[0], row[1], row[2]), reverse=True)
    if not found:
        print(f"NOT_FOUND class={subject!r}; searched configured roots, direct .cls files and .zip members")
        return 1
    print(f"LATEST_CANDIDATE {found[0][2]}")
    print(f"ORDER=filename_semver_then_mtime; version={found[0][0]}; candidate_not_verified_release")
    for version, stamp, path in found[:MAX_RESULTS]:
        print(f"CANDIDATE version={'.'.join(map(str,version))} mtime={dt.datetime.fromtimestamp(stamp,dt.timezone.utc).isoformat()} path={path}")
    if len(found) > MAX_RESULTS:
        print(f"TRUNCATED showing {MAX_RESULTS} of {len(found)}")
    return 0


def find_class_directories():
    paths = []
    for folder, st in walk_files(roots()):
        if folder.suffix.lower() == ".cls":
            parent = str(folder.parent)
            if parent not in paths:
                paths.append(parent)
        if len(paths) >= 100:
            break
    return paths


def rexxpath(text, setup):
    current = [x for x in os.environ.get("REXX_PATH", "").split(os.pathsep) if x]
    if not setup:
        print("REXX_PATH=" + os.environ.get("REXX_PATH", ""))
        return 0
    class_dirs = find_class_directories()
    merged = list(dict.fromkeys(class_dirs + current))
    if not merged:
        print("NO_CHANGE: no .cls directories discovered in configured search roots")
        return 3
    base = config_dir()
    base.mkdir(mode=0o700, parents=True, exist_ok=True)
    os.chmod(base, 0o700)
    target = base / "rexxpath.sh"
    if target.is_symlink():
        raise ComputerError("REXX_PATH output is a symlink")
    fd, tmp = tempfile.mkstemp(prefix=".rexxpath-", dir=base)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            f.write("# Generated by Scotty Computer. Source explicitly in your shell.\n")
            f.write("export REXX_PATH=" + shlex.quote(os.pathsep.join(merged)) + "\n")
        os.chmod(tmp, 0o600)
        os.replace(tmp, target)
    finally:
        if os.path.exists(tmp):
            os.unlink(tmp)
    print(f"WROTE {target}\nApply to current shell with: source {shlex.quote(str(target))}")
    print("An external process cannot modify its parent's environment")
    return 0


def helper(name, env):
    value = os.environ.get(env)
    if value:
        path = Path(value).expanduser().resolve()
    else:
        sibling = Path(__file__).resolve().parent.parent / "adapters" / name
        path = (Path(shutil.which(name) or sibling)).resolve()
    if not path.is_file() or not os.access(path, os.X_OK):
        raise ComputerError(f"Missing executable authority adapter: {path}", 4)
    return path


def configured_nodes(script):
    code = script.read_text(encoding="utf-8", errors="replace")
    return {x.casefold() for x in re.findall(r"^\s*(ed209[a-z0-9]+)\)\s+user=", code, re.I | re.M)}


def node_in_text(text):
    result = re.findall(r"\bed209[a-z0-9]+\b", text, re.I)
    if len(result) != 1:
        raise ComputerError("Please name exactly one ED209 node")
    return result[0].lower()


def login(text):
    if not re.fullmatch(r"(?:log\s+me\s+into|login)\s+ed209[a-z0-9]+\s*", text, re.I):
        raise ComputerError("Use: Computer log me into ED209B")
    node = node_in_text(text)
    tool = helper("sshnode.sh", "COMPUTER_SSHNODE")
    if node not in configured_nodes(tool):
        raise ComputerError(f"Unknown node {node} in authoritative {tool}; no SSH attempted", 4)
    if os.environ.get("COMPUTER_DRY_RUN") == "1":
        print(f"DRY_RUN sshnode.sh {node} (tool={tool})")
        return 0
    print(f"CONNECTING via {tool} {node}", flush=True)
    log_dir = config_dir()
    log_dir.mkdir(mode=0o700, parents=True, exist_ok=True)
    os.chmod(log_dir, 0o700)
    env = os.environ.copy()
    env.setdefault("SSHNODE_LOG", str(log_dir / "sshnode.log"))
    return subprocess.call([str(tool), node], env=env)


def firewall(text):
    node = node_in_text(text)
    try:
        tool = helper("sshnode.sh", "COMPUTER_SSHNODE")
    except ComputerError as err:
        print(f"BLOCKED FIREWALL {node}: {err}")
        return 4
    nodes = configured_nodes(tool)
    if node not in nodes:
        print(f"BLOCKED FIREWALL {node}: node absent from authoritative sshnode.sh mapping")
        print("No provider, security group, VCN/NSG, ingress rule or credentials invented")
        return 4
    try:
        cloud = helper("cloudctl.sh", "COMPUTER_CLOUDCTL")
    except ComputerError as err:
        print(f"BLOCKED FIREWALL {node}: {err}")
        return 4
    print(f"PLAN_ONLY FIREWALL {node}: node is SSH-known; cloud authority is {cloud}")
    print("Need verified provider, scoped firewall resource, desired ports/protocol, approved peer sources and an authorised change")
    print("cloudctl supports provider-specific firewall list/update. No generic 'fix' action is authorised.")
    return 4



def host_check(text, memory=False):
    """Execute only the fixed local tools or the authoritative SSH node wrapper.

    Never interpret the user's request as a remote shell command.
    """
    kind = "memory" if memory else "space"
    match = re.fullmatch(r"check\s+free\s+" + kind + r"(?:\s+on\s+(ed209[a-z0-9]+))?\s*", text, re.I)
    if not match:
        raise ComputerError(f"Specify check free {kind} [on ed209NODE]", 3)
    node = match.group(1)
    binary = "free" if memory else "df"
    argv = [binary, "-h"]
    if node is not None:
        node = node.lower()
        tool = helper("sshnode.sh", "COMPUTER_SSHNODE")
        if node not in configured_nodes(tool):
            raise ComputerError(f"Unknown node {node} in authoritative {tool}; no SSH attempted", 4)
        jid = f"computer-check-free-{kind}-{node}-{dt.datetime.now(dt.timezone.utc):%Y%m%dT%H%M%SZ}-{uuid.uuid4().hex[:8]}"
        argv = [str(tool), "--job-id", jid, node, binary, "-h"]
    if os.environ.get("COMPUTER_DRY_RUN") == "1":
        print(f"DRY_RUN check free {kind} on {node or 'local'}: argv=" + json.dumps(argv))
        return 0
    try:
        result = subprocess.run(argv, timeout=120, check=False)
    except (OSError, subprocess.TimeoutExpired) as exc:
        raise ComputerError(f"Diagnostic failed: {exc}", 5) from exc
    if result.returncode:
        raise ComputerError(f"Diagnostic on {node or 'local'} failed: rc={result.returncode}", 5)
    print(f"OK check-free-{kind} on {node or 'local'}")
    return 0


def file_sha256(path):
    digest = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def deploy_source(name):
    if not name or any(c in name for c in "\x00\n\r"):
        raise ComputerError("Specify a ZIP file", 3)
    if Path(name).suffix.lower() != ".zip":
        raise ComputerError("Deployment source must be a .zip file", 3)
    search = roots()
    matches = []
    supplied = Path(os.path.expanduser(name))
    if supplied.is_absolute():
        matches = [supplied]
    elif supplied.name == name:
        matches = [p for p, st in walk_files(search) if p.name == name]
    else:
        raise ComputerError("Use a ZIP basename or an absolute path", 3)
    unique = list(dict.fromkeys(p.resolve() for p in matches))
    if not unique:
        raise ComputerError(f"ZIP file {name!r} not found in registered locations", 1)
    if len(unique) > 1:
        raise ComputerError("Ambiguous ZIP file; give its absolute path: " + ", ".join(map(str, unique[:8])), 3)
    p = unique[0]
    if supplied.is_symlink():
        raise ComputerError("Source ZIP symlink refused", 4)
    if not any(p == base or base in p.parents for base in search):
        raise ComputerError("ZIP file is outside registered search locations", 4)
    if not p.is_file() or p.is_symlink():
        raise ComputerError("Source is not a regular non-symlink ZIP file", 4)
    if not 0 < p.stat().st_size <= MAX_DEPLOY_BYTES:
        raise ComputerError("ZIP file size is zero or above configured deployment limit", 4)
    if not zipfile.is_zipfile(p):
        raise ComputerError("ZIP header is invalid", 1)
    return p


def pending_dir():
    folder = config_dir() / "pending"
    if config_dir().is_symlink() or folder.is_symlink():
        raise ComputerError("Unsafe pending directory symlink", 4)
    folder.mkdir(parents=True, mode=0o700, exist_ok=True)
    os.chmod(folder, 0o700)
    return folder


def confirm_create(document):
    directory = pending_dir()
    for _ in range(3):
        token = secrets.token_urlsafe(24)
        path = directory / token
        try:
            fd = os.open(path, os.O_CREAT | os.O_EXCL | os.O_WRONLY | os.O_NOFOLLOW, 0o600)
        except FileExistsError:
            continue
        try:
            os.write(fd, (json.dumps(document, sort_keys=True) + "\n").encode("utf-8"))
            os.fsync(fd)
        finally:
            os.close(fd)
        return token
    raise ComputerError("Cannot allocate a unique confirmation token", 5)


def confirm_consume(token):
    if not re.fullmatch(r"[A-Za-z0-9_-]{32}", token):
        raise ComputerError("Malformed confirmation token", 2)
    folder = pending_dir()
    lock_path = folder / ".lock"
    with os.fdopen(os.open(lock_path, os.O_RDWR | os.O_CREAT | os.O_NOFOLLOW, 0o600), "r+") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        path = folder / token
        try:
            with os.fdopen(os.open(path, os.O_RDONLY | os.O_NOFOLLOW), "rb") as f:
                raw = f.read(16385)
        except FileNotFoundError as exc:
            raise ComputerError("Unknown, used or expired confirmation token", 4) from exc
        finally:
            # Burn a token on any validation attempt, including malformed contents.
            path.unlink(missing_ok=True)
        if len(raw) > 16384:
            raise ComputerError("Oversized pending record", 4)
        try:
            doc = json.loads(raw)
            if doc["schema"] != "scotty.computer.pending/1":
                raise ValueError("schema")
            created = float(doc["created_at"])
        except (ValueError, TypeError, KeyError, json.JSONDecodeError) as exc:
            raise ComputerError("Malformed pending confirmation record", 4) from exc
        now = time.time()
        if now < created - 30 or now > created + CONFIRM_TTL_SECONDS:
            raise ComputerError("Expired confirmation; repeat the original command", 4)
        return doc


def deploy_prepare(text):
    """Park a fully scoped, content-hashed transfer for explicit reauthorisation."""
    match = re.fullmatch(r"deploy\s+zipfile\s+(.+?)\s+to\s+(ed209[a-z0-9]+)\s*", text, re.I)
    if not match:
        raise ComputerError("Specify: deploy zipfile <file.zip> to <ed209node>", 3)
    name, node = match.group(1).strip().strip('"\''), match.group(2).lower()
    tool = helper("sshnode.sh", "COMPUTER_SSHNODE")
    if node not in configured_nodes(tool):
        raise ComputerError(f"Unknown node {node} in authoritative {tool}; no transfer attempted", 4)
    path = deploy_source(name)
    st = path.stat()
    digest = file_sha256(path)
    authority = file_sha256(tool)
    doc = {"schema": "scotty.computer.pending/1", "intent": "DEPLOY_ZIPFILE", "created_at": time.time(),
           "node": node, "source_path": str(path), "source_size": st.st_size,
           "source_sha256": digest, "sshnode_path": str(tool), "sshnode_sha256": authority}
    token = confirm_create(doc)
    print(f"CONFIRM intent=DEPLOY_ZIPFILE NODE={node} SOURCE={path} SIZE={st.st_size} SHA256={digest}")
    print("NOT EXECUTED. ZIP transfer is only via the authoritative sshnode.sh adapter.")
    print(f"Computer confirm {token}")
    return 3


def confirm_action(text):
    match = re.fullmatch(r"confirm\s+([A-Za-z0-9_-]+)\s*", text, re.I)
    if not match:
        raise ComputerError("Malformed confirmation token", 2)
    doc = confirm_consume(match.group(1))
    if doc.get('intent', '').startswith('GITHUB_'):
        from ComputerGithub import confirm as github_confirm, GithubError
        try:
            return github_confirm(doc)
        except GithubError as e:
            raise ComputerError(str(e), e.rc) from e
    if doc.get('intent') in {'JOB_ACTIVATE', 'JOB_EXECUTE', 'JOB_REVOKE', 'JOB_POLICY', 'JOB_EXCEPTION_REGISTER'}:
        from ComputerJobs import confirm as job_confirm
        return job_confirm(doc, load_state, save_state, ComputerError, helper, configured_nodes, file_sha256, config_dir)
    if doc.get('intent') == 'LEARN_ACTIVATE':
        from ComputerLearn import activate as learn_activate
        return learn_activate(doc, load_state, save_state, ComputerError)
    if doc.get("intent") != "DEPLOY_ZIPFILE":
        raise ComputerError("Unsupported pending operation", 4)
    node = doc["node"]
    expected_path = Path(doc["sshnode_path"])
    tool = helper("sshnode.sh", "COMPUTER_SSHNODE")
    if tool != expected_path or file_sha256(tool) != doc["sshnode_sha256"]:
        raise ComputerError("SSH adapter changed since preview; request a new confirmation", 4)
    if node not in configured_nodes(tool):
        raise ComputerError("SSH node mapping changed; no transfer attempted", 4)
    path = deploy_source(doc["source_path"])
    st = path.stat()
    if st.st_size != doc["source_size"] or file_sha256(path) != doc["source_sha256"]:
        raise ComputerError("ZIP bytes changed since preview; no transfer attempted", 4)
    jid = f"computer-deploy-zipfile-{node}-{dt.datetime.now(dt.timezone.utc):%Y%m%dT%H%M%SZ}-{uuid.uuid4().hex[:8]}"
    argv = [str(tool), "--job-id", jid, "--transfer", node, str(path)]
    if os.environ.get("COMPUTER_DRY_RUN") == "1":
        print("DRY_RUN confirmed transfer, token consumed: " + json.dumps(argv))
        return 0
    print(f"TRANSFERRING {path} to {node} via sshnode.sh (job={jid})", flush=True)
    try:
        result = subprocess.run(argv, timeout=600, check=False)
    except (OSError, subprocess.TimeoutExpired) as exc:
        raise ComputerError(f"Transfer execution failed: {exc}", 5) from exc
    if result.returncode:
        raise ComputerError(f"SSH transfer failed: rc={result.returncode}", 5)
    print(f"OK transferred {path} to {node}:{path.name} (remote home directory)")
    return 0


def run_tests(text):
    if text.casefold() not in {"run tests", "run the tests"}:
        raise ComputerError("RUN_TESTS request mismatch", 2)
    root = Path(__file__).resolve().parent.parent
    target = root / "tools" / "qualify.sh"
    if not target.is_file():
        raise ComputerError("Test runner unavailable in this installation", 4)
    try:
        outcome = subprocess.run(["bash", str(target)], cwd=root, timeout=180, check=False)
    except (OSError, subprocess.TimeoutExpired) as exc:
        raise ComputerError(f"Test runner unavailable: {exc}", 5) from exc
    if outcome.returncode:
        raise ComputerError(f"Qualification failed rc={outcome.returncode}", 5)
    print("OK run-tests qualification passed")
    return 0

def discover():
    state = load_state()
    ssh = None
    cloud = None
    try:
        ssh = helper("sshnode.sh", "COMPUTER_SSHNODE")
    except ComputerError:
        pass
    try:
        cloud = helper("cloudctl.sh", "COMPUTER_CLOUDCTL")
    except ComputerError:
        pass
    print(f"Scotty Computer {VERSION}: capabilities discovered on this invocation")
    print("Local: configure search roots, recently received (metadata-proxy) files, content search, latest .cls inside ZIP, REXX_PATH setup")
    print("search_roots:", json.dumps(state["search_roots"]))
    print("search_scopes:", json.dumps(state.get("search_scopes", {}), sort_keys=True))
    print("temp_roots:", json.dumps(state["temp_roots"]))
    print("sshnode:", str(ssh) if ssh else "UNAVAILABLE")
    print("cloudctl:", str(cloud) if cloud else "UNAVAILABLE")
    print("Diagnostics: check free space/memory locally or via authoritative sshnode.sh")
    print("Integrity: SHA256/SHA512, legacy SHA1, byte comparison, expected checksum, manifest, ZIP audit, find by checksum")
    print("Machine output: Computer --json sha256 FILE; Computer instructions lists Codex operating rules")
    print('Search scopes: machine-local named directory sets, explicitly selected, no implicit global scans')
    print('GitHub: project SSH aliases preserved; write actions preview/confirm; Computer github help')
    print('Learning: reviewed read-only aliases; governed executable local/remote jobs via Computer job help')
    print("Deployment: ZIP transfer requires single-use expiring confirmation")
    print("Firewall changes: BLOCKED until evidence, scope and authority are supplied")
    return 0


def help_message():
    print("Scotty Computer — ooRexx IntentionService client")
    for line in ("Computer add ~/Downloads to my find file locations",
                 "Computer add ~/Downloads/current to my find file locations",
                 "Computer add ~/Downloads to my find file locations as inboundfiles",
                 "Computer add ~/deps to my find file locations as dependencies",
                 "Computer search scopes",
                 "Computer find new files in last 30 minutes in inboundfiles",
                 "Computer find dependency rexx crypto in dependencies",
                 "Computer find directories matching xtp in xtpwork",
                 "Computer add /tmp to my permitted temporary file directory",
                 "Computer find files received in my find files location in the past 30 minutes",
                 'Computer which file has "IntentionService"',
                 "Computer find the latest copy of Crypto rexx class",
                 "Computer set up the rexxpath",
                 "Computer check free space [on ED209B]",
                 "Computer check free memory [on ED209B]",
                 "Computer deploy zipfile mypackage.zip to ED209B [confirm required]",
                 "Computer confirm <token>",
                 "Computer sha256 FILE | sha512 FILE | sha1 FILE",
                 "Computer compare sha256 FILE with FILE",
                 "Computer compare files FILE with FILE",
                 "Computer verify sha256 HEX FILE",
                 "Computer verify manifest SHA256SUMS",
                 "Computer find sha256 HEX",
                 "Computer inspect FILE",
                 "Computer list zip FILE | Computer test zip FILE",
                 "Computer --json sha256 FILE (and other integrity instructions)",
                 "Computer instructions",
                 "Computer read document FILE | list documents in ZIP | read document MEMBER in ZIP",
                 "Computer job help | job list | job draft NAME on ED209B -- EXEC ARGS",
                 "Computer job run NAME | job revoke NAME | Computer confirm TOKEN",
                 "Computer job stdout|stderr|result|explain RUN_ID | job history NAME",
                 "Computer job policy NAME repeat-readonly|manual [confirmed]",
                 "Computer github help",
                 "Computer learn help",
                 "Computer run tests",
                 "Computer log me into ED209B",
                 "Computer fix the firewall on ed209f [plan/block only]",
                 "Computer discover | Computer config | Computer rexxpath"):
        print("  " + line)
    return 0


def show_instructions():
    """Operational command guidance is part of the Computer command surface."""
    path = Path(__file__).resolve().parent.parent / 'AGENTS.md'
    if not path.is_file():
        raise ComputerError('Computer operator instructions are missing', 4)
    print(path.read_text(encoding='utf-8'))
    return 0


def audit(intent, text, result):
    """Append a content-blind, mode-0600 result record; never store search text."""
    base = config_dir()
    base.mkdir(mode=0o700, parents=True, exist_ok=True)
    if base.is_symlink() or (base / "audit.jsonl").is_symlink():
        raise ComputerError("Unsafe audit path")
    os.chmod(base, 0o700)
    record = {
        "schema": "scotty.computer.audit/1",
        "at_utc": dt.datetime.now(dt.timezone.utc).isoformat(),
        "intent": intent,
        "request_sha256": hashlib.sha256(text.encode("utf-8")).hexdigest(),
        "exit_code": int(result),
    }
    f = os.open(base / "audit.jsonl", os.O_WRONLY | os.O_APPEND | os.O_CREAT | os.O_NOFOLLOW, 0o600)
    try:
        os.fchmod(f, 0o600)
        fcntl.flock(f, fcntl.LOCK_EX)
        os.write(f, (json.dumps(record, sort_keys=True) + "\n").encode("utf-8"))
        os.fsync(f)
    finally:
        os.close(f)


def execute(intent, text):
    if intent == 'JOBS':
        from ComputerJobs import handle
        return handle(text, load_state, save_state, confirm_create, confirm_consume, ComputerError, helper, configured_nodes, file_sha256, config_dir)
    if intent == 'FIND_DIRECTORIES':
        from ComputerSearch import find_directories
        j = text.casefold().startswith('--json ')
        return find_directories(text[7:].strip() if j else text, load_state(), ComputerError, json_mode=j)
    if intent == 'READ_DOCUMENT':
        from ComputerDocuments import execute as read_document
        return read_document(text, ComputerError)
    if intent == 'SEARCH_NAMED':
        from ComputerSearch import search
        j = text.casefold().startswith('--json ')
        return search(text[7:].strip() if j else text, load_state(), walk_files, ComputerError, json_mode=j)
    if intent == 'SEARCH_SCOPES':
        from ComputerSearch import list_scopes
        j = text.casefold().startswith('--json ')
        request = text[7:].strip() if j else text
        if request.casefold() not in {'search scopes', 'list search locations', 'list search scopes'}:
            raise ComputerError('SEARCH_SCOPES grammar mismatch', 2)
        return list_scopes(load_state(), j)
    if intent == 'ADD_SEARCH_SCOPE':
        from ComputerSearch import register
        return register(text, load_state, save_state, canonical, ComputerError)
    if intent == 'GITHUB':
        from ComputerGithub import github, GithubError
        try:
            return github(text, confirm_create)
        except GithubError as e:
            raise ComputerError(str(e), e.rc) from e
    if intent == 'LEARN':
        from ComputerLearn import learn
        return learn(text, load_state, confirm_create, ComputerError, confirm_consume)
    if intent == 'RUN_LEARNED':
        from ComputerLearn import run_learned
        return run_learned(text, load_state, execute, ComputerError)
    if intent not in KNOWN:
        raise ComputerError(f"Unsupported intention {intent}", 2)
    if intent == "FILE_INTEGRITY":
        from ComputerIntegrity import run as run_integrity
        is_json = text.casefold().startswith('--json ')
        request = text[7:].strip() if is_json else text
        return run_integrity(request, load_state(), walk_files, json_mode=is_json)
    if intent == "INSTRUCTIONS":
        if text.casefold() not in {"instructions", "computer instructions"}:
            raise ComputerError("INSTRUCTIONS text mismatch", 2)
        return show_instructions()
    if intent == "HELP":
        if text.casefold() not in {"help", "--help", "-h"}:
            raise ComputerError("HELP text does not match recognised utterance", 2)
        return help_message()
    if intent == "DISCOVER":
        if text.casefold() not in {"discover", "intentions", "what can you do"}:
            raise ComputerError("DISCOVER request mismatch", 2)
        return discover()
    if intent == "CONFIG_SHOW":
        if text.casefold() not in {"config", "show config", "show my find file locations"}:
            raise ComputerError("CONFIG request mismatch", 2)
        return show_config()
    if intent == "ADD_FIND_LOCATION":
        return add_root(text, False)
    if intent == "ADD_TEMP_DIRECTORY":
        return add_root(text, True)
    if intent == "RECENT_FILES":
        if not re.match(r"find files received\b", text, re.I):
            raise ComputerError("RECENT_FILES request mismatch", 2)
        return recent(text)
    if intent == "CONTENT_SEARCH":
        return contents(text)
    if intent == "LATEST_CLASS":
        if not re.match(r"find\s+.*latest.*class", text, re.I):
            raise ComputerError("LATEST_CLASS request mismatch", 2)
        return latest_class(text)
    if intent == "REXXPATH_SHOW":
        if text.casefold() not in {"rexxpath", "show rexxpath"}:
            raise ComputerError("REXXPATH_SHOW request mismatch", 2)
        return rexxpath(text, False)
    if intent == "REXXPATH_SETUP":
        if text.casefold() not in {"set up the rexxpath", "set up rexxpath", "rexxpath setup"}:
            raise ComputerError("REXXPATH_SETUP request mismatch", 2)
        return rexxpath(text, True)
    if intent == "CHECK_FREE_SPACE":
        return host_check(text, False)
    if intent == "CHECK_FREE_MEMORY":
        return host_check(text, True)
    if intent == "DEPLOY_ZIPFILE":
        return deploy_prepare(text)
    if intent == "CONFIRM_ACTION":
        return confirm_action(text)
    if intent == "RUN_TESTS":
        return run_tests(text)
    if intent == "SSH_LOGIN":
        return login(text)
    if intent == "FIREWALL_REPAIR":
        if not re.match(r"(?:fix|repair|diagnose).*firewall", text, re.I):
            raise ComputerError("FIREWALL_REPAIR request mismatch", 2)
        return firewall(text)
    raise ComputerError("Unreachable intention", 2)


def main():
    cli = argparse.ArgumentParser()
    cli.add_argument("--intent", required=True, choices=sorted(KNOWN))
    cli.add_argument("--hex", required=True)
    args = cli.parse_args()
    if not re.fullmatch(r"[0-9A-Fa-f]{0,16384}", args.hex) or len(args.hex) % 2:
        raise ComputerError("Invalid hex request", 2)
    try:
        utterance = bytes.fromhex(args.hex).decode("utf-8")
    except UnicodeDecodeError as e:
        raise ComputerError("Request must be UTF-8", 2) from e
    if any(c in utterance for c in "\x00\r\n"):
        raise ComputerError("Single-line requests only", 2)
    utterance = utterance.strip()
    try:
        outcome = execute(args.intent, utterance)
    except ComputerError as failure:
        audit(args.intent, utterance, failure.status)
        raise
    audit(args.intent, utterance, outcome)
    return outcome


if __name__ == "__main__":
    try:
        status = main()
        sys.stdout.flush()
        sys.exit(status)
    except BrokenPipeError:
        # A consumer such as `head` or `grep -q` has enough output.  Do not
        # turn a closed stdout pipe into a misleading Computer I/O failure.
        # A closed pipe is NOT evidence that an effectful action succeeded;
        # inspect the independent job receipt for those actions.
        try:
            sys.stdout.close()
            sys.stdout = open(os.devnull, 'w')
        except OSError:
            pass
        sys.exit(0)
    except ComputerError as e:
        print(f"COMPUTER_ERROR rc={e.status}: {e}", file=sys.stderr)
        sys.exit(e.status)
    except (OSError, PermissionError) as e:
        print(f"COMPUTER_ERROR rc=5: {e}", file=sys.stderr)
        sys.exit(5)
