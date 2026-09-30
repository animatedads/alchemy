#!/usr/bin/env python3
"""LLM selector/teacher companion for context-aware Alchemy Cog."""
from __future__ import annotations

import argparse
import datetime as _dt
import json
import sys
from typing import Any, Dict, List

import cog

LOG_PATH = cog.ROOT / "cogllm.log.jsonl"


def now_iso() -> str:
    return _dt.datetime.now(_dt.timezone.utc).isoformat()


def log_event(event: str, **fields: Any) -> None:
    rec = {"ts": now_iso(), "component": "cogllm", "event": event, **fields}
    with LOG_PATH.open("a", encoding="utf-8") as fh:
        fh.write(json.dumps(rec, sort_keys=True, ensure_ascii=False) + "\n")


def normalize_recipe_for_plan(recipe: Dict[str, Any], plan: Dict[str, Any]) -> Dict[str, Any]:
    recipe = dict(recipe)
    context = plan.get("context") or {"mode": "os", "language": None, "application": None}
    recipe.setdefault("mode", context.get("mode") or "any")
    if recipe.get("mode") == "coding":
        recipe.setdefault("language", context.get("language") or "any")
    else:
        recipe.setdefault("language", "any")
    if recipe.get("mode") == "customer_service":
        recipe.setdefault("application", context.get("application") or "any")
    else:
        recipe.setdefault("application", "any")
    recipe.setdefault("priority", 0)
    recipe.setdefault("required_params", [])
    recipe.setdefault("side_effect", "unknown")
    recipe.setdefault("source", "learned_by_cogllm")
    return recipe


def validate_recipe(recipe: Dict[str, Any]) -> None:
    required = ["id", "description", "patterns", "action", "mode", "language", "application"]
    missing = [k for k in required if k not in recipe]
    if missing:
        raise cog.CogError("Recipe missing fields: " + ", ".join(missing))
    if not isinstance(recipe["id"], str) or not recipe["id"].strip():
        raise cog.CogError("Recipe id must be a non-empty string")
    if not isinstance(recipe["patterns"], list) or not recipe["patterns"]:
        raise cog.CogError("Recipe patterns must be a non-empty array")
    if not isinstance(recipe["action"], dict) or "kind" not in recipe["action"]:
        raise cog.CogError("Recipe action must be an object containing kind")
    allowed = {"pwd", "respond", "list_dir", "exists", "mkdir", "read_text", "write_text", "append_text", "exec", "sequence"}
    if recipe["action"].get("kind") not in allowed:
        raise cog.CogError(f"Unsupported action kind: {recipe['action'].get('kind')}")
    if recipe["mode"] not in {"any", "os", "coding", "customer_service"}:
        raise cog.CogError("Recipe mode must be any, os, coding, or customer_service")
    if not isinstance(recipe["language"], str) or not recipe["language"]:
        raise cog.CogError("Recipe language must be a non-empty string")
    if not isinstance(recipe["application"], str) or not recipe["application"]:
        raise cog.CogError("Recipe application must be a non-empty string")


def recipe_map() -> Dict[str, Dict[str, Any]]:
    return {r["id"]: r for r in cog.load_library().get("recipes", [])}


def review_packet(plan: Dict[str, Any]) -> Dict[str, Any]:
    rmap = recipe_map()
    candidates = []
    for m in plan.get("candidate_matches", []):
        recipe = rmap.get(m["recipe_id"])
        if recipe:
            candidates.append({"match": m, "recipe": recipe})
    return {
        "selector_contract": {
            "goal": "Accept the deterministic recipe only if it adequately performs the request in the locked Cog context. Otherwise teach a better reusable recipe.",
            "reward": {"adequate_existing_recipe": 1.0, "new_custom_recipe": 0.1, "inadequate_recipe": -10.0},
            "rules": [
                "Do not execute tools directly; all tooling must stay behind cog.py/cogllm.py.",
                "Prefer an adequate existing deterministic recipe over creating a new one.",
                "Reject a recipe from the wrong mode, coding language, or customer-service application.",
                "The coding language is locked until changed explicitly with cog.py --language LANGUAGE.",
                "A completion claim must come from cog.py execution evidence, not from this selector.",
                "Teach reusable parameterised templates; context metadata is part of the prototype."
            ],
        },
        "plan_id": plan["plan_id"],
        "request": plan["request"],
        "context": plan.get("context"),
        "server": plan.get("server"),
        "supplied_params": plan.get("supplied_params", {}),
        "proposed": plan.get("proposed"),
        "candidates": candidates,
        "current_status": plan.get("status"),
        "decision_commands": {
            "accept_proposed": f"./cogllm.py {plan['plan_id']} --accept",
            "accept_named": f"./cogllm.py {plan['plan_id']} --accept RECIPE_ID",
            "teach": f"./cogllm.py {plan['plan_id']} --teach-json '<RECIPE_JSON>'",
        },
    }


def freeze_plan(plan_id: str, recipe_id: str, params: Dict[str, Any], decision: str) -> Dict[str, Any]:
    db, plan = cog.get_plan(plan_id)
    recipe = cog.get_recipe(recipe_id)
    eligible, _, _ = cog.recipe_context_match(recipe, plan.get("context") or {})
    if not eligible:
        raise cog.CogError(f"Recipe {recipe_id} is not eligible for plan context {plan.get('context')}")
    missing = [k for k in recipe.get("required_params", []) if k not in params or params[k] == ""]
    if missing:
        raise cog.CogError("Cannot validate plan; missing parameters: " + ", ".join(missing))
    plan["selected_recipe"] = recipe_id
    plan["recipe_snapshot"] = recipe
    plan["params"] = params
    plan["validated"] = True
    plan["validated_at"] = now_iso()
    plan["validated_by"] = "cogllm"
    plan["selector_decision"] = decision
    plan["status"] = "ready"
    plan["plan_hash"] = cog.canonical_hash(plan)
    db["plans"][plan_id] = plan
    cog.save_plans(db)
    log_event("PLAN_VALIDATED", plan_id=plan_id, recipe_id=recipe_id, decision=decision, params=params, context=plan.get("context"), plan_hash=plan["plan_hash"])
    return plan


def require_reviewed(plan: Dict[str, Any]) -> None:
    if not plan.get("llm_review_requested_at"):
        raise cog.CogError(f"{plan['plan_id']} must be reviewed first: ./cogllm.py {plan['plan_id']}")


def accept(plan_id: str, recipe_id: str | None) -> Dict[str, Any]:
    _, plan = cog.get_plan(plan_id)
    require_reviewed(plan)
    matches = {m["recipe_id"]: m for m in plan.get("candidate_matches", [])}
    if recipe_id is None:
        if not plan.get("proposed"):
            raise cog.CogError("No proposed recipe to accept; teach a recipe instead")
        recipe_id = plan["proposed"]["recipe_id"]
    if recipe_id not in matches:
        raise cog.CogError(f"Recipe {recipe_id} is not a deterministic candidate for {plan_id}")
    log_event("SELECTOR_ACCEPT", plan_id=plan_id, recipe_id=recipe_id, match=matches[recipe_id], context=plan.get("context"))
    return freeze_plan(plan_id, recipe_id, matches[recipe_id]["params"], "accept_existing")


def teach(plan_id: str, raw_json: str) -> Dict[str, Any]:
    _, existing_plan = cog.get_plan(plan_id)
    require_reviewed(existing_plan)
    try:
        recipe = json.loads(raw_json)
    except json.JSONDecodeError as exc:
        raise cog.CogError(f"Invalid recipe JSON: {exc}")
    recipe = normalize_recipe_for_plan(recipe, existing_plan)
    validate_recipe(recipe)
    library = cog.load_library()
    existing = {r["id"] for r in library.get("recipes", [])}
    if recipe["id"] in existing:
        raise cog.CogError(f"Recipe id already exists: {recipe['id']}")
    library.setdefault("recipes", []).append(recipe)
    cog.save_library(library)
    log_event("RECIPE_TAUGHT", plan_id=plan_id, recipe=recipe, context=existing_plan.get("context"))

    db, plan = cog.get_plan(plan_id)
    resolution = cog.resolve_request(plan["request"], plan.get("supplied_params", {}), library, plan.get("context") or {})
    plan["resolution"] = resolution["resolution"]
    plan["candidate_matches"] = resolution["candidate_matches"]
    plan["proposed"] = resolution["proposed"]
    plan["status"] = "awaiting_llm_review"
    db["plans"][plan_id] = plan
    cog.save_plans(db)

    taught_match = next((m for m in resolution["candidate_matches"] if m["recipe_id"] == recipe["id"]), None)
    if taught_match is None:
        raise cog.CogError("Taught recipe does not match the original request in this context; recipe was stored but plan remains unresolved")
    log_event("SELECTOR_TEACH_BIND", plan_id=plan_id, recipe_id=recipe["id"], match=taught_match, context=plan.get("context"))
    return freeze_plan(plan_id, recipe["id"], taught_match["params"], "teach_and_accept")


def tail_log(n: int) -> str:
    if not LOG_PATH.exists():
        return ""
    lines = LOG_PATH.read_text(encoding="utf-8").splitlines()
    return "\n".join(lines[-n:])


def main(argv: List[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Alchemy Cog tiny context-aware LLM selector/teacher")
    parser.add_argument("plan_id", nargs="?", help="Plan to review")
    parser.add_argument("--accept", nargs="?", const="__PROPOSED__", metavar="RECIPE_ID", help="Accept proposed or named deterministic candidate")
    parser.add_argument("--teach-json", metavar="JSON", help="Add a reusable context-aware recipe, bind it to the plan, and accept it")
    parser.add_argument("--log", nargs="?", const="50", metavar="N", help="Show last N cogllm log records")
    args = parser.parse_args(argv)

    log_event("CLI", argv=sys.argv[1:])
    try:
        if args.log is not None:
            print(tail_log(int(args.log)))
            return 0
        if not args.plan_id:
            parser.error("PLAN_ID is required unless --log is used")
        _, plan = cog.get_plan(args.plan_id)
        if args.teach_json is not None:
            updated = teach(args.plan_id, args.teach_json)
            print(json.dumps({"plan_id": updated["plan_id"], "status": updated["status"], "selected_recipe": updated["selected_recipe"], "context": updated.get("context"), "plan_hash": updated["plan_hash"], "next": f"./cog.py --plan {updated['plan_id']} && ./cog.py --do_it {updated['plan_id']}"}, indent=2, sort_keys=True, ensure_ascii=False))
            return 0
        if args.accept is not None:
            rid = None if args.accept == "__PROPOSED__" else args.accept
            updated = accept(args.plan_id, rid)
            print(json.dumps({"plan_id": updated["plan_id"], "status": updated["status"], "selected_recipe": updated["selected_recipe"], "context": updated.get("context"), "plan_hash": updated["plan_hash"], "next": f"./cog.py --plan {updated['plan_id']} && ./cog.py --do_it {updated['plan_id']}"}, indent=2, sort_keys=True, ensure_ascii=False))
            return 0

        packet = review_packet(plan)
        db, stored_plan = cog.get_plan(args.plan_id)
        stored_plan["llm_review_requested_at"] = now_iso()
        stored_plan["llm_review_count"] = int(stored_plan.get("llm_review_count", 0)) + 1
        db["plans"][args.plan_id] = stored_plan
        cog.save_plans(db)
        log_event("REVIEW_REQUEST", plan_id=args.plan_id, packet=packet)
        print(json.dumps(packet, indent=2, sort_keys=True, ensure_ascii=False))
        return 0
    except cog.CogError as exc:
        log_event("ERROR", plan_id=args.plan_id, error=str(exc))
        print(json.dumps({"ok": False, "error": str(exc)}, ensure_ascii=False), file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
