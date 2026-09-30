#!/usr/bin/env python3
"""Alchemy Cog tiny prototype with deterministic mode/language/application context.

Intent -> context-filtered recipe -> frozen plan -> evidence-bearing execution.
The LLM selector/teacher lives in cogllm.py.

This remains a deliberately small local prototype, not a production security boundary.
"""
from __future__ import annotations

import argparse
import datetime as _dt
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
from typing import Any, Dict, List, Tuple

ROOT = Path(os.environ.get("COG_HOME", Path(__file__).resolve().parent)).resolve()
WORKSPACE = Path(os.environ.get("COG_WORKSPACE", os.getcwd())).resolve()
LIBRARY_PATH = ROOT / "cog_library.json"
PLANS_PATH = ROOT / "cog_plans.json"
STATE_PATH = ROOT / "cog_state.json"
LOG_PATH = ROOT / "cog.log.jsonl"
VALID_MODES = {"os", "coding", "customer_service"}


class CogError(RuntimeError):
    pass


def now_iso() -> str:
    return _dt.datetime.now(_dt.timezone.utc).isoformat()


def log_event(event: str, **fields: Any) -> None:
    rec = {"ts": now_iso(), "component": "cog", "event": event, **fields}
    LOG_PATH.parent.mkdir(parents=True, exist_ok=True)
    with LOG_PATH.open("a", encoding="utf-8") as fh:
        fh.write(json.dumps(rec, sort_keys=True, ensure_ascii=False) + "\n")


def load_json(path: Path, default: Any) -> Any:
    if not path.exists():
        return default
    with path.open("r", encoding="utf-8") as fh:
        return json.load(fh)


def save_json(path: Path, value: Any) -> None:
    tmp = path.with_suffix(path.suffix + ".tmp")
    with tmp.open("w", encoding="utf-8") as fh:
        json.dump(value, fh, indent=2, sort_keys=True, ensure_ascii=False)
        fh.write("\n")
    tmp.replace(path)


def load_library() -> Dict[str, Any]:
    return load_json(LIBRARY_PATH, {"catalog_version": "0.1", "recipes": []})


def save_library(lib: Dict[str, Any]) -> None:
    save_json(LIBRARY_PATH, lib)


def load_plans() -> Dict[str, Any]:
    return load_json(PLANS_PATH, {"next_plan": 1, "plans": {}})


def save_plans(plans: Dict[str, Any]) -> None:
    save_json(PLANS_PATH, plans)


def default_state() -> Dict[str, Any]:
    return {
        "schema": "alchemy.cog.state/0.1",
        "mode": "os",
        "language": None,
        "application": None,
        "updated_at": None,
    }


def load_state() -> Dict[str, Any]:
    state = default_state()
    state.update(load_json(STATE_PATH, {}))
    if state.get("mode") not in VALID_MODES:
        raise CogError(f"Invalid persisted Cog mode: {state.get('mode')!r}")
    return state


def save_state(state: Dict[str, Any]) -> None:
    state = dict(state)
    state["schema"] = "alchemy.cog.state/0.1"
    state["updated_at"] = now_iso()
    save_json(STATE_PATH, state)


def context_view(state: Dict[str, Any] | None = None) -> Dict[str, Any]:
    state = state or load_state()
    mode = state.get("mode", "os")
    return {
        "mode": mode,
        "language": state.get("language") if mode == "coding" else None,
        "application": state.get("application") if mode == "customer_service" else None,
    }


def set_context(mode: str | None = None, language: str | None = None, application: str | None = None) -> Dict[str, Any]:
    old = load_state()
    new = dict(old)
    if mode is not None:
        mode = mode.strip().lower()
        if mode not in VALID_MODES:
            raise CogError("--mode must be os, coding, or customer_service")
        new["mode"] = mode
    if language is not None:
        language = language.strip().lower()
        if not language:
            raise CogError("--language cannot be empty")
        if new.get("mode") != "coding":
            raise CogError("--language may only be changed while Cog is in coding mode")
        new["language"] = language
    if application is not None:
        application = application.strip()
        if not application:
            raise CogError("--application cannot be empty")
        if new.get("mode") != "customer_service":
            raise CogError("--application may only be changed while Cog is in customer_service mode")
        new["application"] = application
    if new.get("mode") == "coding" and not new.get("language"):
        raise CogError("coding mode requires a locked language; use --mode coding --language LANGUAGE")
    if new.get("mode") == "customer_service" and not new.get("application"):
        raise CogError("customer_service mode requires an application; use --mode customer_service --application NAME")
    save_state(new)
    persisted = load_state()
    log_event("CONTEXT_CHANGE", before=context_view(old), after=context_view(persisted))
    return persisted


def parse_kv(values: List[str] | None) -> Dict[str, str]:
    result: Dict[str, str] = {}
    for item in values or []:
        if "=" not in item:
            raise CogError(f"--arg must be key=value, got: {item!r}")
        key, value = item.split("=", 1)
        key = key.strip()
        if not key:
            raise CogError("--arg key cannot be empty")
        result[key] = value
    return result


def recipe_context_match(recipe: Dict[str, Any], context: Dict[str, Any]) -> Tuple[bool, int, Dict[str, Any]]:
    mode = str(recipe.get("mode", "any")).lower()
    language = str(recipe.get("language", "any")).lower()
    application = str(recipe.get("application", "any"))
    current_mode = str(context.get("mode") or "os").lower()
    current_language = str(context.get("language") or "").lower()
    current_application = str(context.get("application") or "")
    score = 0
    if mode not in {"any", current_mode}:
        return False, 0, {"mode": mode, "language": language, "application": application}
    if mode == current_mode:
        score += 300
    if current_mode == "coding":
        if language not in {"any", current_language}:
            return False, 0, {"mode": mode, "language": language, "application": application}
        if language == current_language:
            score += 100
    if current_mode == "customer_service":
        if application not in {"any", current_application}:
            return False, 0, {"mode": mode, "language": language, "application": application}
        if application == current_application:
            score += 100
    return True, score, {"mode": mode, "language": language, "application": application}


def recipe_matches(recipe: Dict[str, Any], request: str, supplied: Dict[str, str], context: Dict[str, Any]) -> List[Dict[str, Any]]:
    eligible, context_score, recipe_context = recipe_context_match(recipe, context)
    if not eligible:
        return []
    out = []
    for index, pattern in enumerate(recipe.get("patterns", [])):
        try:
            m = re.fullmatch(pattern, request.strip(), flags=re.IGNORECASE)
        except re.error as exc:
            log_event("INVALID_RECIPE_PATTERN", recipe_id=recipe.get("id"), pattern=pattern, error=str(exc))
            continue
        if not m:
            continue
        params = dict(supplied)
        params.update({k: v for k, v in m.groupdict().items() if v is not None})
        required = list(recipe.get("required_params", []))
        missing = [k for k in required if k not in params or params[k] == ""]
        out.append({
            "recipe_id": recipe["id"],
            "pattern_index": index,
            "params": params,
            "missing_params": missing,
            "priority": int(recipe.get("priority", 0)),
            "context_score": context_score,
            "recipe_context": recipe_context,
        })
    return out


def resolve_request(request: str, supplied: Dict[str, str] | None = None, library: Dict[str, Any] | None = None, context: Dict[str, Any] | None = None) -> Dict[str, Any]:
    supplied = supplied or {}
    library = library or load_library()
    context = context or context_view()
    matches: List[Dict[str, Any]] = []
    for recipe in library.get("recipes", []):
        matches.extend(recipe_matches(recipe, request, supplied, context))
    matches.sort(key=lambda x: (-x["context_score"], -x["priority"], x["recipe_id"], x["pattern_index"]))
    proposed = matches[0] if matches else None
    return {
        "request": request,
        "supplied_params": supplied,
        "context": context,
        "candidate_matches": matches,
        "proposed": proposed,
        "resolution": "recipe" if proposed else "X",
    }


def get_recipe(recipe_id: str, library: Dict[str, Any] | None = None) -> Dict[str, Any]:
    library = library or load_library()
    for recipe in library.get("recipes", []):
        if recipe.get("id") == recipe_id:
            return recipe
    raise CogError(f"Unknown recipe: {recipe_id}")


def new_plan(request: str, server: str | None, supplied: Dict[str, str]) -> Dict[str, Any]:
    library = load_library()
    context = context_view()
    resolution = resolve_request(request, supplied, library, context)
    db = load_plans()
    n = int(db.get("next_plan", 1))
    plan_id = f"PLAN{n:04d}"
    db["next_plan"] = n + 1
    plan = {
        "plan_id": plan_id,
        "created_at": now_iso(),
        "server": server,
        "request": request,
        "supplied_params": supplied,
        "context": context,
        "resolution": resolution["resolution"],
        "candidate_matches": resolution["candidate_matches"],
        "proposed": resolution["proposed"],
        "status": "awaiting_llm_review",
        "validated": False,
        "selected_recipe": None,
        "recipe_snapshot": None,
        "params": resolution["proposed"]["params"] if resolution["proposed"] else supplied,
        "plan_hash": None,
        "execution": None,
    }
    db.setdefault("plans", {})[plan_id] = plan
    save_plans(db)
    log_event(
        "REQUEST",
        plan_id=plan_id,
        server=server,
        request=request,
        supplied_params=supplied,
        context=context,
        resolution=plan["resolution"],
        proposed_recipe=(plan["proposed"] or {}).get("recipe_id"),
        candidate_recipes=[m["recipe_id"] for m in plan["candidate_matches"]],
    )
    return plan


def get_plan(plan_id: str) -> Tuple[Dict[str, Any], Dict[str, Any]]:
    db = load_plans()
    try:
        return db, db["plans"][plan_id]
    except KeyError:
        raise CogError(f"Unknown plan: {plan_id}")


def canonical_hash(plan: Dict[str, Any]) -> str:
    payload = {
        "plan_id": plan["plan_id"],
        "request": plan["request"],
        "server": plan.get("server"),
        "context": plan.get("context"),
        "selected_recipe": plan.get("selected_recipe"),
        "recipe_snapshot": plan.get("recipe_snapshot"),
        "params": plan.get("params", {}),
    }
    raw = json.dumps(payload, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode("utf-8")
    return "sha256:" + hashlib.sha256(raw).hexdigest()


def safe_workspace_path(value: str) -> Path:
    p = Path(value)
    if not p.is_absolute():
        p = WORKSPACE / p
    p = p.resolve()
    try:
        p.relative_to(WORKSPACE)
    except ValueError:
        raise CogError(f"Path escapes COG_WORKSPACE: {value}")
    return p


class _FormatDict(dict):
    def __missing__(self, key: str) -> str:
        raise CogError(f"Missing recipe parameter: {key}")


def render(value: Any, params: Dict[str, Any]) -> Any:
    if isinstance(value, str):
        return value.format_map(_FormatDict(params))
    if isinstance(value, list):
        return [render(v, params) for v in value]
    if isinstance(value, dict):
        return {k: render(v, params) for k, v in value.items()}
    return value


def execute_action(action: Dict[str, Any], params: Dict[str, Any]) -> Dict[str, Any]:
    kind = action.get("kind")
    rendered = render(action, params)
    log_event("ACTION_START", kind=kind, action=rendered)

    if kind == "pwd":
        result = {"ok": True, "cwd": str(WORKSPACE)}
    elif kind == "respond":
        result = {"ok": True, "response": rendered.get("text", "")}
    elif kind == "list_dir":
        path = safe_workspace_path(rendered.get("path", "."))
        entries = []
        for p in sorted(path.iterdir(), key=lambda x: x.name.lower()):
            entries.append({"name": p.name, "type": "dir" if p.is_dir() else "file", "size": p.stat().st_size if p.is_file() else None})
        result = {"ok": True, "path": str(path), "entries": entries}
    elif kind == "exists":
        path = safe_workspace_path(rendered["path"])
        result = {"ok": True, "path": str(path), "exists": path.exists(), "is_file": path.is_file(), "is_dir": path.is_dir()}
    elif kind == "mkdir":
        path = safe_workspace_path(rendered["path"])
        path.mkdir(parents=bool(rendered.get("parents", True)), exist_ok=bool(rendered.get("exist_ok", True)))
        result = {"ok": True, "path": str(path), "exists": path.is_dir()}
    elif kind == "read_text":
        path = safe_workspace_path(rendered["path"])
        max_chars = int(rendered.get("max_chars", 20000))
        text = path.read_text(encoding=rendered.get("encoding", "utf-8"))
        truncated = len(text) > max_chars
        result = {"ok": True, "path": str(path), "text": text[:max_chars], "truncated": truncated, "chars": len(text)}
    elif kind == "write_text":
        path = safe_workspace_path(rendered["path"])
        path.parent.mkdir(parents=True, exist_ok=True)
        text = rendered.get("text", "")
        path.write_text(text, encoding=rendered.get("encoding", "utf-8"))
        result = {"ok": True, "path": str(path), "bytes": path.stat().st_size, "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}
    elif kind == "append_text":
        path = safe_workspace_path(rendered["path"])
        path.parent.mkdir(parents=True, exist_ok=True)
        text = rendered.get("text", "")
        encoding = rendered.get("encoding", "utf-8")
        with path.open("a", encoding=encoding) as fh:
            fh.write(text)
        result = {"ok": True, "path": str(path), "bytes": path.stat().st_size, "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}
    elif kind == "exec":
        argv = rendered.get("argv")
        if not isinstance(argv, list) or not argv or not all(isinstance(x, str) for x in argv):
            raise CogError("exec action requires non-empty string argv array")
        tail_param = rendered.get("argv_tail_param")
        if tail_param:
            raw_tail = params.get(tail_param, "[]")
            if isinstance(raw_tail, str):
                try:
                    tail = json.loads(raw_tail)
                except json.JSONDecodeError as exc:
                    raise CogError("exec argv_tail_param must be a JSON string array") from exc
            else:
                tail = raw_tail
            if not isinstance(tail, list) or not all(isinstance(x, str) for x in tail):
                raise CogError("exec argv_tail_param must resolve to a string array")
            argv = list(argv) + tail
        cwd = safe_workspace_path(rendered.get("cwd", "."))
        timeout = float(rendered.get("timeout_seconds", 30))
        try:
            cp = subprocess.run(argv, cwd=str(cwd), capture_output=True, text=True, timeout=timeout, shell=False)
            result = {"ok": cp.returncode == 0, "argv": argv, "cwd": str(cwd), "returncode": cp.returncode, "stdout": cp.stdout, "stderr": cp.stderr, "timed_out": False}
        except subprocess.TimeoutExpired as exc:
            result = {"ok": False, "argv": argv, "cwd": str(cwd), "returncode": None, "stdout": exc.stdout if isinstance(exc.stdout, str) else "", "stderr": exc.stderr if isinstance(exc.stderr, str) else "", "timed_out": True, "timeout_seconds": timeout}
    elif kind == "sequence":
        steps = []
        ok = True
        for index, step in enumerate(rendered.get("steps", []), start=1):
            step_result = execute_action(step, params)
            steps.append({"step": index, "result": step_result})
            if not step_result.get("ok", False):
                ok = False
                if not rendered.get("continue_on_error", False):
                    break
        result = {"ok": ok, "steps": steps}
    else:
        raise CogError(f"Unsupported action kind: {kind!r}")

    log_event("ACTION_RESULT", kind=kind, result=result)
    return result


def execute_plan(plan_id: str) -> Dict[str, Any]:
    db, plan = get_plan(plan_id)
    if not plan.get("validated"):
        raise CogError(f"{plan_id} has not been accepted by cogllm")
    if not plan.get("recipe_snapshot"):
        raise CogError(f"{plan_id} has no frozen recipe snapshot")
    expected = canonical_hash(plan)
    if plan.get("plan_hash") != expected:
        raise CogError(f"{plan_id} hash mismatch; refusing execution")
    missing = [k for k in plan["recipe_snapshot"].get("required_params", []) if k not in plan.get("params", {})]
    if missing:
        raise CogError(f"{plan_id} missing parameters: {', '.join(missing)}")
    current_context = context_view()
    if plan.get("context") and plan["context"] != current_context:
        raise CogError(f"{plan_id} was frozen for context {plan['context']}, current context is {current_context}")

    log_event("EXECUTION_START", plan_id=plan_id, plan_hash=plan["plan_hash"], recipe_id=plan["selected_recipe"], params=plan.get("params", {}), context=plan.get("context"))
    started = now_iso()
    try:
        result = execute_action(plan["recipe_snapshot"]["action"], plan.get("params", {}))
        status = "complete" if result.get("ok") else "failed"
    except Exception as exc:
        result = {"ok": False, "exception": type(exc).__name__, "error": str(exc)}
        status = "failed"
    plan["execution"] = {"started_at": started, "finished_at": now_iso(), "status": status, "result": result}
    plan["status"] = status
    db["plans"][plan_id] = plan
    save_plans(db)
    log_event("EXECUTION_RESULT", plan_id=plan_id, status=status, result=result)
    return plan


def format_plan(plan: Dict[str, Any]) -> str:
    return json.dumps(plan, indent=2, sort_keys=True, ensure_ascii=False)


def tail_log(n: int) -> str:
    if not LOG_PATH.exists():
        return ""
    lines = LOG_PATH.read_text(encoding="utf-8").splitlines()
    return "\n".join(lines[-n:])


def main(argv: List[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Alchemy Cog tiny deterministic planner/executor")
    parser.add_argument("inputs", nargs="*", help="REQUEST, or SERVER REQUEST")
    parser.add_argument("--arg", action="append", default=[], help="Structured parameter key=value; repeatable")
    parser.add_argument("--plan", metavar="PLAN_ID", help="Show a stored plan")
    parser.add_argument("--do_it", metavar="PLAN_ID", help="Execute a validated frozen plan")
    parser.add_argument("--library", action="store_true", help="Show the learned recipe library")
    parser.add_argument("--plans", action="store_true", help="Show plan index")
    parser.add_argument("--log", nargs="?", const="50", metavar="N", help="Show last N cog log records")
    parser.add_argument("--state", action="store_true", help="Show current Cog mode/language/application state")
    parser.add_argument("--mode", choices=sorted(VALID_MODES), help="Switch Cog operating mode")
    parser.add_argument("--language", help="Set the locked coding language; valid only in coding mode")
    parser.add_argument("--application", help="Set the customer-service application; valid only in customer_service mode")
    args = parser.parse_args(argv)

    log_event("CLI", argv=sys.argv[1:])
    try:
        if args.mode is not None or args.language is not None or args.application is not None:
            state = set_context(args.mode, args.language, args.application)
            print(json.dumps(state, indent=2, sort_keys=True, ensure_ascii=False))
            return 0
        if args.state:
            print(json.dumps(load_state(), indent=2, sort_keys=True, ensure_ascii=False))
            return 0
        if args.library:
            print(json.dumps(load_library(), indent=2, sort_keys=True, ensure_ascii=False))
            return 0
        if args.plans:
            print(json.dumps(load_plans(), indent=2, sort_keys=True, ensure_ascii=False))
            return 0
        if args.log is not None:
            print(tail_log(int(args.log)))
            return 0
        if args.plan:
            _, plan = get_plan(args.plan)
            print(format_plan(plan))
            return 0
        if args.do_it:
            print(format_plan(execute_plan(args.do_it)))
            return 0

        if len(args.inputs) == 1:
            server = None
            request = args.inputs[0]
        elif len(args.inputs) == 2:
            server, request = args.inputs
        else:
            parser.error("Supply REQUEST, or SERVER REQUEST, or use a control option")
        supplied = parse_kv(args.arg)
        plan = new_plan(request, server, supplied)
        compact = {
            "plan_id": plan["plan_id"],
            "request": plan["request"],
            "context": plan.get("context"),
            "resolution": plan["resolution"],
            "proposed_recipe": (plan.get("proposed") or {}).get("recipe_id"),
            "candidate_recipes": [m["recipe_id"] for m in plan.get("candidate_matches", [])],
            "params": plan.get("params", {}),
            "missing_params": (plan.get("proposed") or {}).get("missing_params", []),
            "status": plan["status"],
            "next": f"./cogllm.py {plan['plan_id']}",
        }
        print(json.dumps(compact, indent=2, sort_keys=True, ensure_ascii=False))
        return 0
    except CogError as exc:
        log_event("ERROR", error=str(exc))
        print(json.dumps({"ok": False, "error": str(exc)}, ensure_ascii=False), file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
