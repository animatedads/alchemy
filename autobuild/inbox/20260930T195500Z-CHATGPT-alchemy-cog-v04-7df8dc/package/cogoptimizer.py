#!/usr/bin/env python3
"""Alchemy Cog usage optimiser.

Read Cog/CogLLM usage, combine one or more manual Cog runs, and propose
improvements to the deterministic recipe library.  This tool is deliberately
read-mostly: it never edits cog_library.json.  An explicitly requested merged
library is written to a separate output file for review.
"""
from __future__ import annotations

import argparse
import collections
import datetime as dt
import json
import os
from pathlib import Path
import re
import sys
import zipfile
from typing import Any, Dict, Iterable, List, Tuple

SCHEMA = "alchemy.cog.optimizer.report/0.1"
DEFAULT_FILES = ("cog_library.json", "cog_plans.json", "cog.log.jsonl", "cogllm.log.jsonl")


def now_iso() -> str:
    return dt.datetime.now(dt.timezone.utc).isoformat()


def canonical(value: Any) -> str:
    return json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False)


def load_json_text(text: str, default: Any) -> Any:
    if not text.strip():
        return default
    return json.loads(text)


def load_jsonl_text(text: str) -> List[Dict[str, Any]]:
    out: List[Dict[str, Any]] = []
    for line_no, line in enumerate(text.splitlines(), start=1):
        if not line.strip():
            continue
        try:
            value = json.loads(line)
        except json.JSONDecodeError as exc:
            out.append({"event": "INVALID_JSONL", "line": line_no, "error": str(exc), "raw": line[:500]})
            continue
        if isinstance(value, dict):
            out.append(value)
    return out


def basename_member(names: Iterable[str], wanted: str) -> str | None:
    matches = [n for n in names if Path(n).name == wanted and not n.endswith("/")]
    if not matches:
        return None
    matches.sort(key=lambda n: (n.count("/"), len(n), n))
    return matches[0]


def empty_bundle(label: str, path: str) -> Dict[str, Any]:
    return {
        "label": label,
        "path": path,
        "library": {"recipes": []},
        "plans": {"plans": {}},
        "cog_log": [],
        "cogllm_log": [],
        "warnings": [],
    }


def load_run(path: Path, label: str | None = None) -> Dict[str, Any]:
    path = path.expanduser().resolve()
    bundle = empty_bundle(label or path.name or str(path), str(path))

    def apply(name: str, text: str) -> None:
        if name == "cog_library.json":
            bundle["library"] = load_json_text(text, {"recipes": []})
        elif name == "cog_plans.json":
            bundle["plans"] = load_json_text(text, {"plans": {}})
        elif name == "cog.log.jsonl":
            bundle["cog_log"] = load_jsonl_text(text)
        elif name == "cogllm.log.jsonl":
            bundle["cogllm_log"] = load_jsonl_text(text)

    if path.is_dir():
        for name in DEFAULT_FILES:
            p = path / name
            if p.exists():
                apply(name, p.read_text(encoding="utf-8"))
            else:
                bundle["warnings"].append(f"missing {name}")
        return bundle

    if zipfile.is_zipfile(path):
        with zipfile.ZipFile(path) as zf:
            names = zf.namelist()
            for wanted in DEFAULT_FILES:
                member = basename_member(names, wanted)
                if member is None:
                    bundle["warnings"].append(f"missing {wanted}")
                    continue
                apply(wanted, zf.read(member).decode("utf-8", errors="replace"))
        return bundle

    if path.is_file() and path.suffix.lower() == ".json":
        raw = load_json_text(path.read_text(encoding="utf-8"), {})
        if isinstance(raw, dict) and any(k in raw for k in ("library", "plans", "cog_log", "cogllm_log")):
            bundle["library"] = raw.get("library", bundle["library"])
            bundle["plans"] = raw.get("plans", bundle["plans"])
            bundle["cog_log"] = raw.get("cog_log", [])
            bundle["cogllm_log"] = raw.get("cogllm_log", [])
            return bundle
        name = path.name
        if name in DEFAULT_FILES:
            apply(name, path.read_text(encoding="utf-8"))
            return bundle

    if path.is_file() and path.suffix.lower() == ".jsonl":
        events = load_jsonl_text(path.read_text(encoding="utf-8"))
        if "cogllm" in path.name.lower():
            bundle["cogllm_log"] = events
        else:
            bundle["cog_log"] = events
        return bundle

    raise ValueError(f"Unsupported Cog run source: {path}")


def load_rules(path: Path) -> Dict[str, Any]:
    if not path.exists():
        return {"version": "missing", "rules": []}
    return json.loads(path.read_text(encoding="utf-8"))


def rule_map(rules: Dict[str, Any]) -> Dict[str, Dict[str, Any]]:
    return {r.get("id"): r for r in rules.get("rules", []) if isinstance(r, dict) and r.get("id")}


def enabled(rmap: Dict[str, Dict[str, Any]], rule_id: str) -> bool:
    rule = rmap.get(rule_id)
    return bool(rule and rule.get("enabled", True))


def plans_from(bundle: Dict[str, Any]) -> List[Dict[str, Any]]:
    raw = bundle.get("plans", {}).get("plans", {})
    if isinstance(raw, dict):
        values = list(raw.values())
    elif isinstance(raw, list):
        values = raw
    else:
        values = []
    values = [p for p in values if isinstance(p, dict)]
    values.sort(key=lambda p: (str(p.get("created_at", "")), str(p.get("plan_id", ""))))
    return values


def recursively_timed_out(value: Any) -> bool:
    if isinstance(value, dict):
        if value.get("timed_out") is True:
            return True
        return any(recursively_timed_out(v) for v in value.values())
    if isinstance(value, list):
        return any(recursively_timed_out(v) for v in value)
    return False


def observed_requests(bundles: List[Dict[str, Any]]) -> List[str]:
    out: List[str] = []
    for b in bundles:
        for e in b.get("cog_log", []):
            if e.get("event") == "REQUEST" and isinstance(e.get("request"), str):
                out.append(e["request"])
    return out


def recipe_usage(bundles: List[Dict[str, Any]]) -> Tuple[collections.Counter, collections.Counter]:
    selected: collections.Counter[str] = collections.Counter()
    taught: collections.Counter[str] = collections.Counter()
    for b in bundles:
        for p in plans_from(b):
            rid = p.get("selected_recipe")
            if rid:
                selected[str(rid)] += 1
            if p.get("selector_decision") == "teach_and_accept" and rid:
                taught[str(rid)] += 1
    return selected, taught


def initial_misses(bundles: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    out: List[Dict[str, Any]] = []
    for b in bundles:
        for e in b.get("cog_log", []):
            if e.get("event") == "REQUEST" and e.get("resolution") == "X":
                out.append({"source": b["label"], "plan_id": e.get("plan_id"), "request": e.get("request"), "params": e.get("supplied_params", {})})
    return out


def execution_stats(bundles: List[Dict[str, Any]]) -> Dict[str, Any]:
    total = complete = failed = timed_out = 0
    failures: List[Dict[str, Any]] = []
    for b in bundles:
        for p in plans_from(b):
            ex = p.get("execution")
            if not ex:
                continue
            total += 1
            status = ex.get("status") or p.get("status")
            if status == "complete":
                complete += 1
            else:
                failed += 1
                failures.append({"source": b["label"], "plan_id": p.get("plan_id"), "recipe": p.get("selected_recipe"), "request": p.get("request"), "result": ex.get("result")})
            if recursively_timed_out(ex.get("result")):
                timed_out += 1
    return {"executed": total, "complete": complete, "failed": failed, "timed_out": timed_out, "failures": failures}


def sequence_counts(bundles: List[Dict[str, Any]], lengths: List[int]) -> Dict[int, collections.Counter]:
    counts: Dict[int, collections.Counter] = {n: collections.Counter() for n in lengths}
    for b in bundles:
        seq = [p.get("selected_recipe") for p in plans_from(b) if p.get("status") == "complete" and p.get("selected_recipe")]
        for n in lengths:
            for i in range(0, max(0, len(seq) - n + 1)):
                counts[n][tuple(seq[i:i+n])] += 1
    return counts


def recipe_ids(bundle: Dict[str, Any]) -> Dict[str, Dict[str, Any]]:
    return {str(r.get("id")): r for r in bundle.get("library", {}).get("recipes", []) if isinstance(r, dict) and r.get("id")}


def pattern_collisions(current: Dict[str, Any], requests: List[str]) -> List[Dict[str, Any]]:
    recipes = current.get("library", {}).get("recipes", [])
    out = []
    for request in sorted(set(requests)):
        hits = []
        for r in recipes:
            for pattern in r.get("patterns", []):
                try:
                    if re.fullmatch(pattern, request.strip(), flags=re.IGNORECASE):
                        hits.append(r.get("id"))
                        break
                except re.error:
                    pass
        hits = sorted(set(h for h in hits if h))
        if len(hits) > 1:
            out.append({"request": request, "recipes": hits})
    return out


def duplicate_actions(current: Dict[str, Any]) -> List[Dict[str, Any]]:
    buckets: Dict[str, List[str]] = collections.defaultdict(list)
    for r in current.get("library", {}).get("recipes", []):
        if r.get("id") and isinstance(r.get("action"), dict):
            buckets[canonical(r["action"])].append(str(r["id"]))
    return [{"recipes": sorted(ids)} for ids in buckets.values() if len(ids) > 1]


def overspecialized(current: Dict[str, Any]) -> List[Dict[str, Any]]:
    out = []
    numbered = re.compile(r"^(.*?)(\d+)$")
    for r in current.get("library", {}).get("recipes", []):
        groups: Dict[str, List[str]] = collections.defaultdict(list)
        for param in r.get("required_params", []):
            m = numbered.match(str(param))
            if m:
                groups[m.group(1)].append(str(param))
        suspicious = {k: sorted(v) for k, v in groups.items() if len(v) >= 2}
        if suspicious:
            out.append({
                "recipe": r.get("id"),
                "numbered_parameters": suspicious,
                "suggestion": "Review for collection/variadic parameterisation or a family of arity-independent recipes."
            })
    return out


def propose_merged_library(current: Dict[str, Any], manuals: List[Dict[str, Any]]) -> Tuple[Dict[str, Any], List[Dict[str, Any]], List[str]]:
    base = json.loads(json.dumps(current.get("library", {"catalog_version": "0.1", "recipes": []})))
    base.setdefault("recipes", [])
    by_id = {str(r.get("id")): r for r in base["recipes"] if r.get("id")}
    imports: List[Dict[str, Any]] = []
    conflicts: List[str] = []
    for b in manuals:
        for r in b.get("library", {}).get("recipes", []):
            rid = str(r.get("id", ""))
            if not rid:
                continue
            if rid not in by_id:
                copied = json.loads(json.dumps(r))
                copied["merge_provenance"] = b["label"]
                base["recipes"].append(copied)
                by_id[rid] = copied
                imports.append({"recipe": rid, "source": b["label"]})
            elif canonical(by_id[rid]) != canonical(r):
                conflicts.append(rid)
    base["optimizer_merge"] = {"generated_at": now_iso(), "sources": [b["label"] for b in manuals], "conflicts_skipped": sorted(set(conflicts))}
    return base, imports, sorted(set(conflicts))


def analyse(current: Dict[str, Any], manuals: List[Dict[str, Any]], rules: Dict[str, Any]) -> Dict[str, Any]:
    bundles = [current] + manuals
    rmap = rule_map(rules)
    selected, taught = recipe_usage(bundles)
    misses = initial_misses(bundles)
    execs = execution_stats(bundles)
    requests = observed_requests(bundles)
    current_recipes = recipe_ids(current)
    all_plans = sum(len(plans_from(b)) for b in bundles)
    proposals: List[Dict[str, Any]] = []

    if enabled(rmap, "MISS_TO_RECIPE"):
        by_request: Dict[str, List[Dict[str, Any]]] = collections.defaultdict(list)
        for m in misses:
            by_request[str(m.get("request"))].append(m)
        for req, items in sorted(by_request.items(), key=lambda kv: (-len(kv[1]), kv[0])):
            proposals.append({"rule": "MISS_TO_RECIPE", "priority": "high" if len(items) > 1 else "normal", "request": req, "count": len(items), "evidence": items[:5], "proposal": "Ensure this miss is covered by a reusable parameterised recipe if the learned execution proved successful."})

    if enabled(rmap, "OVERSPECIALIZED_ARITY"):
        for item in overspecialized(current):
            proposals.append({"rule": "OVERSPECIALIZED_ARITY", "priority": "normal", **item})

    if enabled(rmap, "PATTERN_COLLISION"):
        for item in pattern_collisions(current, requests):
            proposals.append({"rule": "PATTERN_COLLISION", "priority": "high", **item, "proposal": "Refine patterns or priorities so deterministic selection has one clearly best candidate."})

    if enabled(rmap, "DUPLICATE_ACTION"):
        for item in duplicate_actions(current):
            proposals.append({"rule": "DUPLICATE_ACTION", "priority": "low", **item, "proposal": "Consider aliasing or merging these recipes if their intent boundaries are not materially different."})

    seq_rule = rmap.get("COMPOSITE_SEQUENCE", {})
    if enabled(rmap, "COMPOSITE_SEQUENCE"):
        lengths = [int(x) for x in seq_rule.get("sequence_lengths", [2, 3])]
        min_count = int(seq_rule.get("min_count", 2))
        counts = sequence_counts(bundles, lengths)
        for n in lengths:
            for seq, count in counts[n].most_common():
                if count < min_count:
                    break
                proposals.append({"rule": "COMPOSITE_SEQUENCE", "priority": "normal", "sequence": list(seq), "count": count, "proposal": "Review this repeated successful sequence as a composite recipe; preserve each child recipe's validation and evidence semantics."})

    if enabled(rmap, "TIMEOUT_RECOVERY") and execs["timed_out"]:
        for f in execs["failures"]:
            if recursively_timed_out(f.get("result")):
                proposals.append({"rule": "TIMEOUT_RECOVERY", "priority": "high", "recipe": f.get("recipe"), "request": f.get("request"), "evidence": f.get("result"), "proposal": "Add an evidence-driven timeout diagnostic/recovery recipe. Do not merely increase timeout blindly."})

    if enabled(rmap, "FAILURE_RECOVERY"):
        for f in execs["failures"]:
            if not recursively_timed_out(f.get("result")):
                proposals.append({"rule": "FAILURE_RECOVERY", "priority": "high", "recipe": f.get("recipe"), "request": f.get("request"), "evidence": f.get("result"), "proposal": "Consider a deterministic diagnostic or recovery recipe keyed by this failure evidence."})

    merged_candidate, imports, conflicts = propose_merged_library(current, manuals)
    if enabled(rmap, "MANUAL_RUN_RECIPE_IMPORT"):
        for item in imports:
            proposals.append({"rule": "MANUAL_RUN_RECIPE_IMPORT", "priority": "normal", **item, "proposal": "Recipe exists in a merged manual run but not the current library; review for import."})
        for rid in conflicts:
            proposals.append({"rule": "MANUAL_RUN_RECIPE_IMPORT", "priority": "high", "recipe": rid, "proposal": "Same recipe id differs across runs. Resolve manually; optimizer will not overwrite it."})

    unused_rule = rmap.get("UNUSED_RECIPE", {})
    if enabled(rmap, "UNUSED_RECIPE") and all_plans >= int(unused_rule.get("min_observed_plans", 10)):
        for rid in sorted(current_recipes):
            if selected[rid] == 0:
                proposals.append({"rule": "UNUSED_RECIPE", "priority": "low", "recipe": rid, "proposal": "No selections in the merged corpus. Review usefulness; do not delete automatically."})

    usage_rows = []
    all_ids = sorted(set(selected) | set(taught) | set(current_recipes))
    for rid in all_ids:
        usage_rows.append({"recipe": rid, "selected": selected[rid], "taught": taught[rid], "deterministic_reuse_estimate": max(0, selected[rid] - taught[rid]), "in_current_library": rid in current_recipes})

    source_rows = []
    for b in bundles:
        source_rows.append({"label": b["label"], "path": b["path"], "plans": len(plans_from(b)), "recipes": len(b.get("library", {}).get("recipes", [])), "cog_log_events": len(b.get("cog_log", [])), "cogllm_log_events": len(b.get("cogllm_log", [])), "warnings": b.get("warnings", [])})

    return {
        "schema": SCHEMA,
        "generated_at": now_iso(),
        "rules_version": rules.get("version"),
        "sources": source_rows,
        "metrics": {
            "plans": all_plans,
            "initial_misses": len(misses),
            "recipes_taught": sum(taught.values()),
            "recipe_selections": sum(selected.values()),
            "deterministic_reuse_estimate": sum(max(0, selected[r] - taught[r]) for r in selected),
            "executed": execs["executed"],
            "complete": execs["complete"],
            "failed": execs["failed"],
            "timed_out": execs["timed_out"],
        },
        "recipe_usage": usage_rows,
        "initial_miss_evidence": misses,
        "proposals": proposals,
        "merge_preview": {"import_candidates": imports, "conflicts": conflicts, "merged_recipe_count": len(merged_candidate.get("recipes", []))},
    }


def main(argv: List[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Analyse Cog usage and propose deterministic recipe optimisations")
    parser.add_argument("--cog-home", default=os.environ.get("COG_HOME", str(Path(__file__).resolve().parent)), help="Current Cog home directory")
    parser.add_argument("--merge-run", action="append", default=[], metavar="PATH", help="Merge a manual Cog run directory, ZIP, combined JSON, or JSONL into the analysis; repeatable")
    parser.add_argument("--rules", default="cog_optimizer_rules.json", help="Optimizer rule file (relative to Cog home unless absolute)")
    parser.add_argument("--output", metavar="PATH", help="Write optimisation report JSON")
    parser.add_argument("--write-merged-library", metavar="PATH", help="Write a review-only merged library candidate; never overwrites the live library")
    parser.add_argument("--summary", action="store_true", help="Print compact metrics/proposal summary instead of the full report")
    args = parser.parse_args(argv)

    home = Path(args.cog_home).expanduser().resolve()
    rules_path = Path(args.rules).expanduser()
    if not rules_path.is_absolute():
        rules_path = home / rules_path

    try:
        current = load_run(home, label="current")
        manuals = [load_run(Path(p), label=f"manual:{Path(p).name}") for p in args.merge_run]
        rules = load_rules(rules_path)
        report = analyse(current, manuals, rules)

        if args.output:
            out = Path(args.output).expanduser()
            if not out.is_absolute():
                out = home / out
            out.write_text(json.dumps(report, indent=2, sort_keys=True, ensure_ascii=False) + "\n", encoding="utf-8")
            report["report_output"] = str(out)

        if args.write_merged_library:
            merged, imports, conflicts = propose_merged_library(current, manuals)
            out = Path(args.write_merged_library).expanduser()
            if not out.is_absolute():
                out = home / out
            out.write_text(json.dumps(merged, indent=2, sort_keys=True, ensure_ascii=False) + "\n", encoding="utf-8")
            report["merged_library_output"] = str(out)
            report["merged_library_imports"] = imports
            report["merged_library_conflicts"] = conflicts

        if args.summary:
            print(json.dumps({"schema": report["schema"], "metrics": report["metrics"], "proposal_count": len(report["proposals"]), "merge_preview": report["merge_preview"], "sources": report["sources"]}, indent=2, sort_keys=True, ensure_ascii=False))
        else:
            print(json.dumps(report, indent=2, sort_keys=True, ensure_ascii=False))
        return 0
    except Exception as exc:
        print(json.dumps({"ok": False, "error": str(exc), "type": type(exc).__name__}, ensure_ascii=False), file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())