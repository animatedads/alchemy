#!/usr/bin/env python3
import argparse
import hashlib
import json
import os
import shutil
import subprocess
import tempfile
import time
import zipfile
from pathlib import Path

SCHEMA_V1 = "alchemy.autobuild.integration/0.1"
SCHEMA = "alchemy.autobuild.integration/0.2"
SUPPORTED_SCHEMAS = {SCHEMA_V1, SCHEMA}
RESULT_SCHEMA = "alchemy.autobuild.result/0.2"
MSG_SCHEMA = "alchemy.mesh.autobuild/0.2"
REPO_URL = "git@github-alchemy:animatedads/alchemy.git"


def iso(ns):
    return time.strftime("%Y-%m-%dT%H:%M:%S", time.gmtime(ns / 1e9)) + f".{(ns // 1_000_000) % 1000:03d}Z"


def stamp():
    return time.strftime("%Y%m%dT%H%M%SZ", time.gmtime())


def sha256(p):
    h = hashlib.sha256()
    with open(p, "rb") as f:
        for b in iter(lambda: f.read(1 << 20), b""):
            h.update(b)
    return h.hexdigest()


def write_json(p, x):
    p = Path(p)
    p.parent.mkdir(parents=True, exist_ok=True)
    q = p.with_suffix(p.suffix + ".tmp")
    q.write_text(json.dumps(x, indent=2, sort_keys=True) + "\n")
    os.replace(q, p)


def run(argv, cwd=None, env=None, timeout=None):
    a = time.time_ns()
    try:
        r = subprocess.run(
            argv,
            cwd=cwd,
            env=env,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            timeout=timeout,
        )
        b = time.time_ns()
        return dict(
            argv=argv,
            returncode=r.returncode,
            timed_out=False,
            stdout=r.stdout,
            stderr=r.stderr,
            started_at=iso(a),
            ended_at=iso(b),
            elapsed_ms=round((b - a) / 1e6, 3),
        )
    except subprocess.TimeoutExpired as e:
        b = time.time_ns()
        out = e.stdout.decode() if isinstance(e.stdout, bytes) else (e.stdout or "")
        err = e.stderr.decode() if isinstance(e.stderr, bytes) else (e.stderr or "")
        return dict(
            argv=argv,
            returncode=None,
            timed_out=True,
            stdout=out,
            stderr=err,
            started_at=iso(a),
            ended_at=iso(b),
            elapsed_ms=round((b - a) / 1e6, 3),
        )


def defaults():
    root = Path("~/alchemy-autobuild").expanduser()
    return dict(
        root=root,
        downloads=Path("~/Downloads").expanduser(),
        repo=root / "repo",
        repo_url=REPO_URL,
        branch="main",
        poll=2.0,
        git_name="Alchemy Autobuild",
        git_email="alchemy-autobuild@localhost",
        ipc_from="AUTOBUILD",
        ipc_to="CHATGPT",
    )


def config(path=None):
    c = defaults()
    if path:
        x = json.loads(Path(path).read_text())
        if "root" in x:
            c["root"] = Path(x["root"]).expanduser()
        if "downloads" in x:
            c["downloads"] = Path(x["downloads"]).expanduser()
        if "repo_dir" in x:
            c["repo"] = Path(x["repo_dir"]).expanduser()
        elif "root" in x:
            c["repo"] = c["root"] / "repo"
        for a, b in [
            ("repo_url", "repo_url"),
            ("branch", "branch"),
            ("git_name", "git_name"),
            ("git_email", "git_email"),
            ("ipc_from", "ipc_from"),
            ("ipc_to", "ipc_to"),
        ]:
            if a in x:
                c[b] = x[a]
        if "poll_seconds" in x:
            c["poll"] = float(x["poll_seconds"])
    return c


def validate(m):
    if not isinstance(m, dict) or m.get("schema") not in SUPPORTED_SCHEMAS:
        raise ValueError("unsupported integration schema")
    p = m.get("package")
    tests = m.get("tests")
    if not isinstance(p, dict) or not all(isinstance(p.get(k), str) and p[k] for k in ("name", "version")):
        raise ValueError("package name/version required")
    if not isinstance(tests, list) or not tests:
        raise ValueError("tests required")
    for t in tests:
        a = t.get("argv") if isinstance(t, dict) else None
        if not isinstance(a, list) or not a or not all(isinstance(v, str) and v for v in a):
            raise ValueError("test argv required")
        if "command" in t or "shell" in t:
            raise ValueError("use argv, not shell strings")
        if float(t.get("timeout_seconds", 60)) <= 0:
            raise ValueError("positive timeout required")
    e = m.get("environment", {})
    if not isinstance(e.get("set", {}), dict):
        raise ValueError("environment.set must be object")
    for k in ("prepend_path", "append_path"):
        if not isinstance(e.get(k, []), list):
            raise ValueError(f"environment.{k} must be array")

    pub = m.get("publish", {})
    if not isinstance(pub, dict):
        raise ValueError("publish must be object")
    tree = pub.get("tree")
    artifact_only = pub.get("artifact_only", False)
    if tree is not None:
        if not isinstance(tree, dict):
            raise ValueError("publish.tree must be object")
        for k in ("source", "path"):
            if not isinstance(tree.get(k), str) or not tree[k]:
                raise ValueError(f"publish.tree.{k} required")
    if artifact_only not in (True, False):
        raise ValueError("publish.artifact_only must be boolean")
    if tree is not None and artifact_only:
        raise ValueError("publish.tree and artifact_only are mutually exclusive")
    if m["schema"] == SCHEMA and tree is None and not artifact_only:
        raise ValueError("schema 0.2 requires publish.tree or publish.artifact_only=true")

    for f in pub.get("files", []):
        if not isinstance(f, dict) or not isinstance(f.get("source"), str) or not isinstance(f.get("path"), str):
            raise ValueError("publish source/path required")
        if f.get("when", "pass") not in ("pass", "always"):
            raise ValueError("publish.files.when must be pass or always")
        if "legacy_bootstrap" in f and not isinstance(f["legacy_bootstrap"], bool):
            raise ValueError("legacy_bootstrap must be boolean")


def manifest(z):
    with zipfile.ZipFile(z) as f:
        if "integration.json" not in f.namelist():
            return None
        m = json.loads(f.read("integration.json").decode())
    validate(m)
    return m


def safe_path(root, s):
    root = Path(root).resolve()
    p = (root / s).resolve()
    if p != root and root not in p.parents:
        raise ValueError(f"path escapes root: {s}")
    return p


def safe_repo_rel(s):
    rel = Path(s)
    if rel.is_absolute() or not rel.parts or str(rel) in ("", ".") or ".." in rel.parts:
        raise ValueError("unsafe publish destination")
    return rel


def extract(z, d):
    with zipfile.ZipFile(z) as f:
        for n in f.namelist():
            safe_path(d, n)
        f.extractall(d)


def sname(x):
    y = "".join(c if c.isalnum() or c in "._-" else "_" for c in x)
    if y in ("", ".", ".."):
        raise ValueError("unsafe name")
    return y


def environment(spec, pkg, c):
    e = os.environ.copy()
    repl = {
        "${PACKAGE_ROOT}": str(pkg),
        "${AUTOBUILD_ROOT}": str(c["root"]),
        "${REPO_ROOT}": str(c["repo"]),
    }
    for k, v in spec.get("set", {}).items():
        for a, b in repl.items():
            v = v.replace(a, b)
        e[k] = v
    pre = [str(safe_path(pkg, x)) for x in spec.get("prepend_path", [])]
    app = [str(safe_path(pkg, x)) for x in spec.get("append_path", [])]
    e["PATH"] = os.pathsep.join(pre + ([e.get("PATH", "")] if e.get("PATH") else []) + app)
    e.update(
        ALCHEMY_PACKAGE_ROOT=str(pkg),
        ALCHEMY_AUTOBUILD_ROOT=str(c["root"]),
        ALCHEMY_REPO_ROOT=str(c["repo"]),
    )
    return e


def git(c, *args, capture=False):
    r = subprocess.run(
        ["git", "-C", str(c["repo"]), *args],
        check=True,
        text=True,
        stdout=subprocess.PIPE if capture else None,
        stderr=subprocess.PIPE if capture else None,
    )
    return r.stdout if capture else ""


def sync_repo(c):
    r = c["repo"]
    if (r / ".git").is_dir():
        git(c, "fetch", "origin")
        git(c, "checkout", c["branch"])
        git(c, "pull", "--ff-only", "origin", c["branch"])
    else:
        r.parent.mkdir(parents=True, exist_ok=True)
        subprocess.run(["git", "clone", "--branch", c["branch"], c["repo_url"], str(r)], check=True)
    git(c, "config", "user.name", c["git_name"])
    git(c, "config", "user.email", c["git_email"])


def same_file(a, b):
    return Path(a).stat().st_size == Path(b).stat().st_size and sha256(a) == sha256(b)


def tree_fingerprint(root):
    root = Path(root)
    out = []
    for p in sorted(root.rglob("*"), key=lambda x: x.relative_to(root).as_posix()):
        rel = p.relative_to(root).as_posix()
        if p.is_symlink():
            raise ValueError(f"symlink not allowed in published tree: {rel}")
        if p.is_dir():
            out.append(("d", rel, None))
        elif p.is_file():
            out.append(("f", rel, sha256(p)))
        else:
            raise ValueError(f"unsupported file type in published tree: {rel}")
    return out


def publish_tree(m, pkg, c):
    spec = m.get("publish", {}).get("tree")
    if spec is None:
        return None
    src = safe_path(pkg, spec["source"])
    if not src.is_dir():
        raise ValueError("publish.tree.source must be a directory")
    rel = safe_repo_rel(spec["path"])
    rr = c["repo"].resolve()
    dst = (rr / rel).resolve()
    if dst != rr and rr not in dst.parents:
        raise ValueError("publish tree escapes repo")
    if dst.exists():
        if not dst.is_dir() or tree_fingerprint(src) != tree_fingerprint(dst):
            raise ValueError(f"publish tree destination exists with different content: {rel}")
        return str(rel)
    dst.parent.mkdir(parents=True, exist_ok=True)
    tmp = dst.parent / f".{dst.name}.autobuild-{os.getpid()}-{time.time_ns()}"
    try:
        shutil.copytree(src, tmp)
        os.replace(tmp, dst)
    finally:
        if tmp.exists():
            shutil.rmtree(tmp, ignore_errors=True)
    return str(rel)


def publish_files(m, pkg, c, passed):
    out = []
    rr = c["repo"].resolve()
    for f in m.get("publish", {}).get("files", []):
        # Used only to get v0.2 installed by a v0.1 runner. A v0.2 runner
        # publishes the tree instead and must not duplicate these writes.
        if f.get("legacy_bootstrap"):
            continue
        if f.get("when", "pass") == "pass" and not passed:
            continue
        src = safe_path(pkg, f["source"])
        if not src.is_file():
            raise ValueError(f"publish source is not a file: {f['source']}")
        rel = safe_repo_rel(f["path"])
        dst = (rr / rel).resolve()
        if dst != rr and rr not in dst.parents:
            raise ValueError("publish escapes repo")
        if dst.exists():
            if str(rel).startswith("mesh/ctl/"):
                raise ValueError("append-only message exists")
            if not dst.is_file() or not same_file(src, dst):
                raise ValueError(f"publish destination exists with different content: {rel}")
            out.append(str(rel))
            continue
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src, dst)
        out.append(str(rel))
    return out


def integrate(z, st, m, c, start_ns):
    c["root"].mkdir(parents=True, exist_ok=True)
    (c["root"] / "staging").mkdir(exist_ok=True)
    sync_repo(c)
    h = sha256(z)
    p = m["package"]
    rid = f"{stamp()}-{h[:12]}"
    began = time.time_ns()

    with tempfile.TemporaryDirectory(prefix="run-", dir=c["root"] / "staging") as td:
        pkg = Path(td)
        extract(z, pkg)
        cwd = safe_path(pkg, m.get("working_directory", "."))
        env = environment(m.get("environment", {}), pkg, c)
        tr = []
        tests_ok = True
        for i, t in enumerate(m["tests"], 1):
            test_cwd = safe_path(pkg, t.get("cwd", str(cwd.relative_to(pkg))))
            r = run(t["argv"], str(test_cwd), env, float(t.get("timeout_seconds", 60)))
            r["name"] = t.get("name", f"test-{i}")
            r["status"] = "PASS" if r["returncode"] == 0 and not r["timed_out"] else "FAIL"
            tests_ok &= r["status"] == "PASS"
            tr.append(r)

        ar = Path("autobuild/artifacts") / sname(p["name"]) / sname(p["version"]) / (h + ".zip")
        ad = c["repo"] / ar
        ad.parent.mkdir(parents=True, exist_ok=True)
        if not ad.exists():
            shutil.copy2(z, ad)

        rd = Path("autobuild/results") / rid
        logs = c["repo"] / rd / "logs"
        logs.mkdir(parents=True, exist_ok=True)
        for i, r in enumerate(tr, 1):
            stem = f"{i:02d}-{sname(r['name'])}"
            op = rd / "logs" / (stem + ".stdout.txt")
            ep = rd / "logs" / (stem + ".stderr.txt")
            (c["repo"] / op).write_text(r.pop("stdout"))
            (c["repo"] / ep).write_text(r.pop("stderr"))
            r["stdout_path"] = str(op)
            r["stderr_path"] = str(ep)

        publication_error = None
        published_tree = None
        published_files = []
        try:
            # Promote source from a pristine re-extraction of the downloaded ZIP,
            # not from the test working tree. Tests are allowed to create caches,
            # logs and build debris; those are not source unless explicitly
            # published through publish.files.
            if tests_ok and m.get("publish", {}).get("tree") is not None:
                with tempfile.TemporaryDirectory(prefix="publish-", dir=c["root"] / "staging") as pd:
                    pristine = Path(pd)
                    extract(z, pristine)
                    published_tree = publish_tree(m, pristine, c)
            published_files = publish_files(m, pkg, c, tests_ok)
        except Exception as e:
            publication_error = str(e)

        if publication_error:
            status = "ERROR"
        elif tests_ok:
            status = "PASS"
        else:
            status = "FAIL"

        ended = time.time_ns()
        res = dict(
            schema=RESULT_SCHEMA,
            run_id=rid,
            status=status,
            runner=dict(started_ns=start_ns, started_at=iso(start_ns)),
            run=dict(started_at=iso(began), ended_at=iso(ended), elapsed_ms=round((ended - began) / 1e6, 3)),
            source=dict(
                filename=Path(z).name,
                mtime_ns=st.st_mtime_ns,
                ctime_ns=st.st_ctime_ns,
                arrival_ns=st.st_ctime_ns,
                size=st.st_size,
                sha256=h,
            ),
            package=p,
            artifact_path=str(ar),
            tests=tr,
        )
        if published_tree:
            res["published_tree"] = published_tree
        if published_files:
            res["published_files"] = published_files
        if publication_error:
            res["publication_error"] = publication_error
        write_json(c["repo"] / rd / "result.json", res)

    route = Path("mesh/ctl") / (c["ipc_from"] + "-" + c["ipc_to"])
    mr = route / (stamp() + "-" + h[:12] + ".msg")
    md = c["repo"] / mr
    md.parent.mkdir(parents=True, exist_ok=True)
    msg = dict(
        schema=MSG_SCHEMA,
        knd="AUTOBUILD_RESULT",
        src=c["ipc_from"],
        dst=c["ipc_to"],
        run_id=rid,
        status=res["status"],
        elapsed_ms=res["run"]["elapsed_ms"],
        package=p,
        result_path=str(rd / "result.json"),
        artifact_path=str(ar),
        sha256=h,
    )
    if res.get("published_tree"):
        msg["published_tree"] = res["published_tree"]
    md.write_text("EVENT|" + json.dumps(msg, sort_keys=True) + "\n")

    paths = [str(ar), str(rd), str(mr)]
    if res.get("published_tree"):
        paths.append(res["published_tree"])
    paths += res.get("published_files", [])
    git(c, "add", "--", *paths)
    if git(c, "status", "--porcelain", capture=True).strip():
        git(c, "commit", "-m", "autobuild: " + rid)
        try:
            git(c, "push", "origin", c["branch"])
        except subprocess.CalledProcessError:
            git(c, "pull", "--rebase", "origin", c["branch"])
            git(c, "push", "origin", c["branch"])
    return res


def candidate(downloads, start_ns):
    best = None
    try:
        entries = Path(downloads).iterdir()
    except FileNotFoundError:
        return None
    for p in entries:
        if not p.is_file() or p.suffix.lower() != ".zip":
            continue
        st = p.stat()
        arrived = st.st_ctime_ns
        if arrived < start_ns:
            continue
        if best is None or (arrived, p.name) > (best[0], best[1].name):
            best = (arrived, p, st)
    return None if best is None else (best[1], best[2])


def state(c, start_ns, status, **kw):
    write_json(
        c["root"] / "runner-state.json",
        dict(
            schema="alchemy.autobuild.state/0.2",
            status=status,
            started_ns=start_ns,
            started_at=iso(start_ns),
            downloads=str(c["downloads"]),
            repo_dir=str(c["repo"]),
            repo_url=c["repo_url"],
            **kw,
        ),
    )


def loop(c, once=False, start_ns=None):
    start_ns = time.time_ns() if start_ns is None else start_ns
    c["root"].mkdir(parents=True, exist_ok=True)
    (c["root"] / "staging").mkdir(exist_ok=True)
    state(c, start_ns, "started")
    seen = None
    handled = set()
    while True:
        x = candidate(c["downloads"], start_ns)
        if x:
            z, st = x
            fp = (str(z), st.st_mtime_ns, st.st_ctime_ns, st.st_size)
            if fp not in handled:
                if fp != seen:
                    seen = fp
                    state(c, start_ns, "observed", candidate=z.name, arrival_ns=st.st_ctime_ns)
                else:
                    try:
                        m = manifest(z)
                    except (zipfile.BadZipFile, EOFError):
                        seen = None
                        state(c, start_ns, "waiting-for-stable-zip", candidate=z.name)
                    except Exception as e:
                        handled.add(fp)
                        state(c, start_ns, "rejected", candidate=z.name, error=str(e))
                    else:
                        handled.add(fp)
                        if m is None:
                            state(c, start_ns, "ignored-no-manifest", candidate=z.name)
                        else:
                            state(c, start_ns, "running", candidate=z.name, package=m["package"])
                            try:
                                r = integrate(z, st, m, c, start_ns)
                            except Exception as e:
                                state(c, start_ns, "integration-error", candidate=z.name, error=str(e))
                            else:
                                state(
                                    c,
                                    start_ns,
                                    r["status"].lower(),
                                    candidate=z.name,
                                    run_id=r["run_id"],
                                    outcome=r["status"],
                                )
        if once:
            return
        time.sleep(c["poll"])


def main():
    a = argparse.ArgumentParser()
    a.add_argument("--config")
    a.add_argument("--once", action="store_true")
    a.add_argument("--print-config", action="store_true")
    n = a.parse_args()
    c = config(n.config)
    if n.print_config:
        print(json.dumps({k: str(v) if isinstance(v, Path) else v for k, v in c.items()}, indent=2))
        return
    loop(c, n.once)


if __name__ == "__main__":
    main()
