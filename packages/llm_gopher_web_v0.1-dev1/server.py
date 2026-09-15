#!/usr/bin/env python3
"""Human-facing, read-only web explorer for LLM Gopher spheres."""
from __future__ import annotations

import argparse
import hashlib
import json
import mimetypes
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import threading
import time
import urllib.parse
import webbrowser
import zipfile
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from typing import Any

VERSION = "0.1-dev1"
PROFILE_RE = re.compile(r"(^|/)profiles/([^/]+)\.json$")
READ_ONLY_COMMANDS = {"context", "open", "search", "lookup"}


def _json_bytes(value: Any) -> bytes:
    return (json.dumps(value, ensure_ascii=False, indent=2) + "\n").encode("utf-8")


def _safe_text(value: Any) -> str:
    return "" if value is None else str(value)


class ExplorerError(RuntimeError):
    def __init__(self, message: str, *, details: Any = None, status: int = 500):
        super().__init__(message)
        self.details = details
        self.status = status


class GopherBridge:
    def __init__(
        self,
        *,
        gopher: Path,
        sphere_dir: Path,
        env_root: Path,
        role: str = "llm",
        timeout: float = 20.0,
        oorexx_deb: Path | None = None,
    ) -> None:
        self.gopher = gopher.resolve()
        self.sphere_dir = sphere_dir.resolve()
        self.env_root = env_root.expanduser().resolve()
        self.role = role
        self.timeout = timeout
        self.oorexx_deb = oorexx_deb.resolve() if oorexx_deb else None
        self._scan_lock = threading.RLock()
        self._gopher_lock = threading.RLock()
        self._entries: dict[str, dict[str, Any]] = {}
        self._scan_signature: tuple[Any, ...] | None = None
        self._active_key_by_sphere: dict[str, str] = {}
        self._activation_by_key: dict[str, dict[str, Any]] = {}
        self.setup_result: dict[str, Any] | None = None

    def environment(self) -> dict[str, str]:
        env = os.environ.copy()
        env["LLM_GOPHER_ENV"] = str(self.env_root)
        env["LLM_GOPHER_SPHERE_OVERRIDE_DIR"] = str(self.sphere_dir)
        return env

    def setup(self) -> dict[str, Any]:
        self.env_root.mkdir(parents=True, exist_ok=True, mode=0o700)
        try:
            os.chmod(self.env_root, 0o700)
        except OSError:
            pass
        cmd = [str(self.gopher), "setup", "--env", str(self.env_root), "--no-launch"]
        if self.oorexx_deb:
            cmd[2:2] = ["--oorexx-deb", str(self.oorexx_deb)]
        result = self._run_raw(cmd, include_env=True, timeout=max(self.timeout, 30.0))
        if not isinstance(result, dict) or result.get("setup_status") != "READY":
            raise ExplorerError("Gopher setup did not report READY", details=result)
        self.setup_result = result
        return result

    def _run_raw(self, cmd: list[str], *, include_env: bool = True, timeout: float | None = None) -> dict[str, Any]:
        try:
            cp = subprocess.run(
                cmd,
                cwd=str(self.gopher.parent),
                env=self.environment() if include_env else None,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
                timeout=timeout or self.timeout,
                check=False,
            )
        except subprocess.TimeoutExpired as exc:
            raise ExplorerError("Gopher command timed out", details={"command": cmd, "timeout": timeout or self.timeout}) from exc
        except OSError as exc:
            raise ExplorerError("Could not execute Gopher", details={"command": cmd, "error": str(exc)}) from exc
        stdout = cp.stdout.strip()
        stderr = cp.stderr.strip()
        try:
            payload = json.loads(stdout) if stdout else {}
        except json.JSONDecodeError as exc:
            raise ExplorerError(
                "Gopher returned non-JSON output",
                details={"command": cmd, "rc": cp.returncode, "stdout": stdout[:4000], "stderr": stderr[:4000]},
            ) from exc
        # Gopher deliberately uses process RCs to mirror operation outcomes.
        # A valid JSON envelope is still useful/authoritative even when the
        # semantic operation is NOT_FOUND or otherwise non-zero.
        if isinstance(payload, dict):
            if cp.returncode != 0:
                payload.setdefault("process", {})["rc"] = cp.returncode
                if stderr:
                    payload["process"]["stderr"] = stderr[:4000]
            return payload
        raise ExplorerError(
            "Gopher command failed without a JSON envelope",
            details={"command": cmd, "rc": cp.returncode, "stderr": stderr[:4000]},
        )

    def run(self, args: list[str]) -> dict[str, Any]:
        with self._gopher_lock:
            return self._run_raw([str(self.gopher), *args])

    def _dir_signature(self) -> tuple[Any, ...]:
        if not self.sphere_dir.is_dir():
            return ("missing", str(self.sphere_dir))
        values = []
        for p in sorted(self.sphere_dir.glob("*.zip")):
            try:
                st = p.stat()
                values.append((p.name, st.st_size, st.st_mtime_ns))
            except OSError:
                values.append((p.name, None, None))
        return tuple(values)

    @staticmethod
    def _discover_zip(path: Path) -> dict[str, Any]:
        base: dict[str, Any] = {
            "filename": path.name,
            "path": str(path.resolve()),
            "status": "unread",
        }
        try:
            st = path.stat()
            base.update({"size": st.st_size, "mtime_ns": st.st_mtime_ns})
            with zipfile.ZipFile(path) as zf:
                candidates = []
                names = zf.namelist()
                for name in names:
                    match = PROFILE_RE.search(name)
                    if not match:
                        continue
                    try:
                        profile = json.loads(zf.read(name).decode("utf-8"))
                    except Exception:
                        continue
                    fallback_id = match.group(2)
                    sphere_id = _safe_text(profile.get("id") or profile.get("profile") or fallback_id).strip()
                    if not sphere_id:
                        continue
                    candidates.append({
                        "sphere": sphere_id,
                        "profile_path": name,
                        "profile": profile,
                    })
                if not candidates:
                    base.update({
                        "status": "legacy_or_invalid",
                        "reason": "No readable profiles/*.json identity was found",
                    })
                    return base
                ids = sorted({c["sphere"] for c in candidates})
                if len(ids) != 1:
                    base.update({
                        "status": "ambiguous",
                        "sphere_ids": ids,
                        "reason": "Archive contains multiple sphere identities",
                    })
                    return base
                selected = next(c for c in candidates if c["sphere"] == ids[0])
                profile = selected["profile"]
                root_prefix = selected["profile_path"][: -len("profiles/" + selected["profile_path"].split("/")[-1])]
                # Human-list metadata only. Gopher remains authoritative once selected.
                title = None
                sphere_version = None
                object_path = None
                for name in names:
                    if root_prefix and not name.startswith(root_prefix):
                        continue
                    if not name.endswith(".json") or "/packs/" not in "/" + name:
                        continue
                    try:
                        obj = json.loads(zf.read(name).decode("utf-8"))
                    except Exception:
                        continue
                    if obj.get("kind") == "sphere" and obj.get("id") == ids[0]:
                        title = obj.get("title")
                        sphere_version = obj.get("version")
                        object_path = name
                        break
                base.update({
                    "status": "available",
                    "sphere": ids[0],
                    "title": title or ids[0],
                    "version": sphere_version or profile.get("version"),
                    "profile_path": selected["profile_path"],
                    "sphere_path": object_path,
                    "root_prefix": root_prefix,
                })
        except zipfile.BadZipFile:
            base.update({"status": "invalid_zip", "reason": "Invalid ZIP archive"})
        except OSError as exc:
            base.update({"status": "unreadable", "reason": str(exc)})
        return base

    def scan(self, *, force: bool = False) -> list[dict[str, Any]]:
        with self._scan_lock:
            signature = self._dir_signature()
            if not force and signature == self._scan_signature:
                return [dict(v) for v in self._entries.values()]
            entries: dict[str, dict[str, Any]] = {}
            if self.sphere_dir.is_dir():
                for path in sorted(self.sphere_dir.glob("*.zip")):
                    item = self._discover_zip(path)
                    key = hashlib.sha256(str(path.resolve()).encode("utf-8")).hexdigest()[:20]
                    item["key"] = key
                    entries[key] = item
            self._entries = entries
            self._scan_signature = signature
            return [dict(v) for v in entries.values()]

    def entry(self, key: str) -> dict[str, Any]:
        self.scan()
        item = self._entries.get(key)
        if not item:
            raise ExplorerError("Unknown sphere source", details={"key": key}, status=404)
        return item

    def activate(self, key: str) -> tuple[dict[str, Any], dict[str, Any]]:
        entry = self.entry(key)
        if entry.get("status") != "available" or not entry.get("sphere"):
            raise ExplorerError("This archive is not loadable by the explorer", details=entry, status=409)
        sphere = str(entry["sphere"])
        with self._gopher_lock:
            if self._active_key_by_sphere.get(sphere) != key:
                activation = self._run_raw([
                    str(self.gopher), "sphere", "load", sphere, "--override", entry["path"]
                ])
                op = activation.get("operation_status", {}).get("class")
                if op != "ACTIVATED":
                    raise ExplorerError("Gopher did not activate the selected sphere", details=activation, status=409)
                self._active_key_by_sphere[sphere] = key
                self._activation_by_key[key] = activation
            else:
                activation = self._activation_by_key.get(key) or {
                    "schema": "llm-gopher-web/cache/1",
                    "tool_status": {"rc": 0, "class": "OK"},
                    "operation_status": {"rc": 0, "class": "ALREADY_ACTIVE"},
                    "result": {"sphere": sphere, "source": entry["path"]},
                }
            context = self._run_raw([
                str(self.gopher), "--profile", sphere, "--role", self.role,
                "context", sphere, "--full"
            ])
        return activation, context

    def open_article(self, key: str, article_id: str) -> dict[str, Any]:
        entry = self.entry(key)
        self.activate(key)
        sphere = str(entry["sphere"])
        return self.run(["--profile", sphere, "--role", self.role, "open", article_id])

    def search(self, key: str, query: str) -> dict[str, Any]:
        entry = self.entry(key)
        self.activate(key)
        sphere = str(entry["sphere"])
        return self.run(["--profile", sphere, "--role", self.role, "search", query, "--sphere", sphere])

    def lookup(self, key: str, pairs: list[str]) -> dict[str, Any]:
        entry = self.entry(key)
        self.activate(key)
        sphere = str(entry["sphere"])
        clean = []
        for pair in pairs:
            if "=" not in pair or pair.startswith("="):
                raise ExplorerError("Lookup terms must use field=value", details={"term": pair}, status=400)
            clean.append(pair)
        if not clean:
            raise ExplorerError("At least one field=value lookup term is required", status=400)
        return self.run(["--profile", sphere, "--role", self.role, "lookup", *clean, "--sphere", sphere])


class ExplorerHandler(BaseHTTPRequestHandler):
    server_version = "LLMGopherWeb/" + VERSION

    @property
    def app(self) -> "ExplorerHTTPServer":
        return self.server  # type: ignore[return-value]

    def log_message(self, fmt: str, *args: Any) -> None:
        sys.stderr.write("[%s] %s\n" % (self.log_date_time_string(), fmt % args))

    def _send(self, status: int, body: bytes, content_type: str, *, cache: str = "no-store") -> None:
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", cache)
        self.send_header("X-Content-Type-Options", "nosniff")
        self.send_header("Content-Security-Policy", "default-src 'self'; img-src 'self' data:; style-src 'self'; script-src 'self'; connect-src 'self'; base-uri 'none'; frame-ancestors 'none'")
        self.send_header("Referrer-Policy", "no-referrer")
        self.end_headers()
        self.wfile.write(body)

    def _json(self, status: int, value: Any) -> None:
        self._send(status, _json_bytes(value), "application/json; charset=utf-8")

    def _error(self, exc: Exception) -> None:
        if isinstance(exc, ExplorerError):
            self._json(exc.status, {"error": str(exc), "details": exc.details})
        else:
            self._json(500, {"error": "Internal explorer error", "details": str(exc)})

    def do_GET(self) -> None:  # noqa: N802
        try:
            parsed = urllib.parse.urlsplit(self.path)
            path = parsed.path
            qs = urllib.parse.parse_qs(parsed.query, keep_blank_values=True)
            if path.startswith("/api/"):
                return self._api(path, qs)
            return self._static(path)
        except Exception as exc:
            self._error(exc)

    def _api(self, path: str, qs: dict[str, list[str]]) -> None:
        bridge = self.app.bridge
        if path == "/api/status":
            entries = bridge.scan()
            self._json(200, {
                "version": VERSION,
                "read_only": True,
                "sphere_dir": str(bridge.sphere_dir),
                "gopher": str(bridge.gopher),
                "gopher_env": str(bridge.env_root),
                "role": bridge.role,
                "sphere_count": len(entries),
                "loadable_count": sum(1 for e in entries if e.get("status") == "available"),
                "setup": bridge.setup_result,
            })
            return
        if path == "/api/spheres":
            force = qs.get("refresh", [""])[0] in {"1", "true", "yes"}
            entries = bridge.scan(force=force)
            self._json(200, {"spheres": entries, "count": len(entries)})
            return
        if path == "/api/sphere":
            key = self._one(qs, "key")
            entry = bridge.entry(key)
            activation, context = bridge.activate(key)
            self._json(200, {"entry": entry, "activation": activation, "context": context})
            return
        if path == "/api/article":
            key = self._one(qs, "key")
            article_id = self._one(qs, "id")
            self._json(200, bridge.open_article(key, article_id))
            return
        if path == "/api/search":
            key = self._one(qs, "key")
            query = self._one(qs, "q").strip()
            if not query:
                raise ExplorerError("Search query is empty", status=400)
            self._json(200, bridge.search(key, query))
            return
        if path == "/api/lookup":
            key = self._one(qs, "key")
            raw = self._one(qs, "q").strip()
            pairs = [part.strip() for part in re.split(r"[\n,]+", raw) if part.strip()]
            self._json(200, bridge.lookup(key, pairs))
            return
        raise ExplorerError("Unknown API endpoint", details={"path": path}, status=404)

    @staticmethod
    def _one(qs: dict[str, list[str]], name: str) -> str:
        values = qs.get(name)
        if not values:
            raise ExplorerError("Missing query parameter", details={"parameter": name}, status=400)
        return values[0]

    def _static(self, path: str) -> None:
        if path == "/":
            path = "/index.html"
        relative = Path(urllib.parse.unquote(path).lstrip("/"))
        if any(part in {"..", "."} for part in relative.parts):
            raise ExplorerError("Invalid path", status=400)
        file_path = (self.app.web_root / relative).resolve()
        if self.app.web_root not in file_path.parents and file_path != self.app.web_root:
            raise ExplorerError("Invalid path", status=400)
        if not file_path.is_file():
            raise ExplorerError("Not found", status=404)
        body = file_path.read_bytes()
        mime = mimetypes.guess_type(str(file_path))[0] or "application/octet-stream"
        if mime.startswith("text/") or mime in {"application/javascript", "application/json"}:
            mime += "; charset=utf-8"
        self._send(200, body, mime, cache="no-cache")


class ExplorerHTTPServer(ThreadingHTTPServer):
    daemon_threads = True

    def __init__(self, addr: tuple[str, int], handler: type[BaseHTTPRequestHandler], *, bridge: GopherBridge, web_root: Path):
        super().__init__(addr, handler)
        self.bridge = bridge
        self.web_root = web_root.resolve()


def find_gopher(explicit: str | None, root: Path) -> Path:
    candidates: list[Path] = []
    if explicit:
        candidates.append(Path(explicit).expanduser())
    env_gopher = os.environ.get("LLM_GOPHER")
    if env_gopher:
        candidates.append(Path(env_gopher).expanduser())
    candidates.extend([
        root / "llm_gopher" / "gopher",
        root.parent / "llm_gopher_v0.19-dev1" / "gopher",
        root.parent / "llm_gopher" / "gopher",
    ])
    for base in (root.parent, Path("/Downloads/current"), Path.home() / "Downloads" / "current"):
        if base.is_dir():
            candidates.extend(sorted(base.glob("llm_gopher_v*/gopher"), reverse=True))
    which = shutil.which("gopher")
    if which:
        candidates.append(Path(which))
    for candidate in candidates:
        try:
            if candidate.is_file() and os.access(candidate, os.X_OK):
                return candidate.resolve()
        except OSError:
            continue
    raise ExplorerError(
        "Could not find the LLM Gopher launcher. Use --gopher /path/to/gopher or set LLM_GOPHER.",
        details={"checked": [str(x) for x in candidates]},
        status=2,
    )


def default_sphere_dir() -> Path:
    explicit = os.environ.get("LLM_GOPHER_SPHERE_DIR")
    if explicit:
        return Path(explicit).expanduser()
    absolute = Path("/Downloads/current/sphere")
    if absolute.is_dir():
        return absolute
    home = Path.home() / "Downloads" / "current" / "sphere"
    if home.is_dir():
        return home
    return absolute


def self_test(bridge: GopherBridge) -> int:
    entries = bridge.scan(force=True)
    loadable = [e for e in entries if e.get("status") == "available"]
    result: dict[str, Any] = {
        "schema": "llm-gopher-web/self-test/1",
        "version": VERSION,
        "sphere_dir": str(bridge.sphere_dir),
        "discovered": len(entries),
        "loadable": len(loadable),
        "checks": [],
    }
    if not loadable:
        result["checks"].append({"name": "discover", "status": "FAIL", "reason": "No loadable spheres"})
        print(json.dumps(result, indent=2))
        return 1
    chosen = next((e for e in loadable if e.get("sphere") == "maths"), loadable[0])
    try:
        activation, context = bridge.activate(chosen["key"])
        result["checks"].append({
            "name": "activate-context",
            "status": "PASS",
            "sphere": chosen.get("sphere"),
            "activation": activation.get("operation_status", {}).get("class"),
            "context": context.get("operation_status", {}).get("class"),
        })
        articles = context.get("result", {}).get("articles") or []
        if articles:
            opened = bridge.open_article(chosen["key"], str(articles[0]["id"]))
            result["checks"].append({
                "name": "article-open",
                "status": "PASS" if opened.get("operation_status", {}).get("class") == "OPENED" else "FAIL",
                "article": articles[0]["id"],
            })
        searched = bridge.search(chosen["key"], "current")
        result["checks"].append({
            "name": "corpus-search",
            "status": "PASS" if searched.get("tool_status", {}).get("class") == "OK" else "FAIL",
            "operation": searched.get("operation_status", {}).get("class"),
        })
    except Exception as exc:
        result["checks"].append({"name": "gopher-roundtrip", "status": "FAIL", "reason": str(exc), "details": getattr(exc, "details", None)})
    failed = any(c.get("status") != "PASS" for c in result["checks"])
    result["status"] = "FAIL" if failed else "PASS"
    print(json.dumps(result, indent=2))
    return 1 if failed else 0


def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(description="Read-only web explorer for LLM Gopher sphere collections")
    p.add_argument("--sphere-dir", default=str(default_sphere_dir()), help="Directory containing sphere ZIPs")
    p.add_argument("--gopher", help="Path to the LLM Gopher launcher")
    p.add_argument("--gopher-env", default=str(Path.home() / ".local" / "state" / "llm-gopher-web" / "gopher-env"), help="Private Gopher environment")
    p.add_argument("--oorexx-deb", help="Optional exact ooRexx .deb for Gopher setup")
    p.add_argument("--role", default="llm", help="Gopher access-control role (default: llm)")
    p.add_argument("--host", default="127.0.0.1", help="Listen host (default: loopback only)")
    p.add_argument("--port", type=int, default=8765, help="Listen port (default: 8765; 0 selects a free port)")
    p.add_argument("--timeout", type=float, default=20.0, help="Per-Gopher-command timeout in seconds")
    p.add_argument("--no-browser", action="store_true", help="Do not open the browser automatically")
    p.add_argument("--self-test", action="store_true", help="Run discovery/Gopher round-trip checks and exit")
    p.add_argument("--version", action="version", version="llm-gopher-web " + VERSION)
    return p


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    root = Path(__file__).resolve().parent
    try:
        gopher = find_gopher(args.gopher, root)
        sphere_dir = Path(args.sphere_dir).expanduser()
        if not sphere_dir.is_dir():
            raise ExplorerError("Sphere directory does not exist", details={"sphere_dir": str(sphere_dir)}, status=2)
        bridge = GopherBridge(
            gopher=gopher,
            sphere_dir=sphere_dir,
            env_root=Path(args.gopher_env),
            role=args.role,
            timeout=args.timeout,
            oorexx_deb=Path(args.oorexx_deb).expanduser() if args.oorexx_deb else None,
        )
        bridge.setup()
        if args.self_test:
            return self_test(bridge)
        server = ExplorerHTTPServer((args.host, args.port), ExplorerHandler, bridge=bridge, web_root=root / "web")
        host, port = server.server_address[:2]
        url_host = "127.0.0.1" if host in {"0.0.0.0", "::"} else host
        url = f"http://{url_host}:{port}/"
        print(json.dumps({
            "schema": "llm-gopher-web/start/1",
            "status": "READY",
            "url": url,
            "sphere_dir": str(bridge.sphere_dir),
            "gopher": str(bridge.gopher),
            "read_only": True,
        }, indent=2), flush=True)
        if not args.no_browser:
            threading.Timer(0.35, lambda: webbrowser.open(url)).start()
        try:
            server.serve_forever(poll_interval=0.35)
        except KeyboardInterrupt:
            pass
        finally:
            server.server_close()
        return 0
    except ExplorerError as exc:
        print(json.dumps({"error": str(exc), "details": exc.details}, indent=2), file=sys.stderr)
        return exc.status if 1 <= exc.status <= 125 else 1


if __name__ == "__main__":
    raise SystemExit(main())
