#!/usr/bin/env python3
"""Build the durable Development Floor specialist registry from qualified bootstrap output."""
from __future__ import annotations
import argparse, datetime as dt, hashlib, json, pathlib, re, zipfile

SCHEMA = "development.floor.specialist-registry/0.1"
SOURCE_SCHEMA = "specialist.bootstrap/0.1"

def primary_language(languages):
    if not languages:
        return ""
    return sorted(languages.items(), key=lambda kv: (-int(kv[1]), kv[0].lower()))[0][0]

def normalize(doc):
    if doc.get("schema") != SOURCE_SCHEMA:
        raise ValueError(f"unsupported specialist schema: {doc.get('schema')!r}")
    if str(doc.get("bootstrap_status", "")).lower() != "complete":
        raise ValueError(f"specialist is not complete: {doc.get('specialist_id')}")
    package = doc.get("package") or {}
    summary = doc.get("summary") or {}
    rules = doc.get("domain_rules") or summary.get("domain_rules") or []
    if not rules:
        raise ValueError(f"specialist has no domain rules: {doc.get('specialist_id')}")
    languages = doc.get("languages") or {}
    return {
        "specialist_id": doc["specialist_id"],
        "registration_id": doc["specialist_id"] + "@" + (package.get("archive_sha256", "")[:12] or package.get("name", "unknown")),
        "specialist_title": doc.get("specialist_title", summary.get("specialist_title", "")),
        "bootstrap_status": "complete",
        "package_name": package.get("name", ""),
        "archive_name": package.get("archive_name", ""),
        "archive_sha256": package.get("archive_sha256", ""),
        "languages": languages,
        "primary_language": primary_language(languages),
        "domain_purpose": summary.get("domain_purpose", ""),
        "authoritative_boundaries": summary.get("authoritative_boundaries", []),
        "domain_rules": [
            {
                "id": r.get("id", ""),
                "rule": r.get("rule", ""),
                "why": r.get("why", ""),
                "evidence": r.get("evidence", []),
            }
            for r in rules
        ],
    }

def load_zip(path):
    docs = []
    with zipfile.ZipFile(path) as zf:
        names = sorted(n for n in zf.namelist() if n.endswith("/specialist.json") and "/_work/" not in n)
        for name in names:
            docs.append(normalize(json.loads(zf.read(name))))
    return docs

def load_dir(path):
    docs = []
    for p in sorted(path.rglob("specialist.json")):
        if "_work" in p.parts:
            continue
        docs.append(normalize(json.loads(p.read_text())))
    return docs

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("source", help="qualified bootstrap ZIP or extracted directory")
    ap.add_argument("output")
    ns = ap.parse_args()
    src = pathlib.Path(ns.source)
    docs = load_zip(src) if src.is_file() else load_dir(src)
    def version_key(package_name):
        m = re.search(r"_v([0-9][0-9A-Za-z._-]*)", package_name or "")
        if not m:
            return ((), package_name or "")
        nums = tuple(int(x) for x in re.findall(r"\d+", m.group(1)))
        return (nums, package_name or "")

    grouped = {}
    for index, doc in enumerate(docs):
        doc["source_order"] = index
        grouped.setdefault(doc["specialist_id"].lower(), []).append(doc)
    logical = []
    for key, revisions in sorted(grouped.items()):
        current = max(revisions, key=lambda d: (version_key(d.get("package_name", "")), d["source_order"]))
        for revision in revisions:
            revision["current"] = revision is current
        logical.append({
            "specialist_id": current["specialist_id"],
            "current_registration_id": current["registration_id"],
            "current_package_name": current.get("package_name", ""),
            "revision_count": len(revisions),
            "registration_ids": [r["registration_id"] for r in revisions],
        })

    rule_count = sum(len(d["domain_rules"]) for d in docs)
    out = {
        "schema": SCHEMA,
        "source_schema": SOURCE_SCHEMA,
        "generated_at": dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat(),
        "source_name": src.name,
        "source_sha256": hashlib.sha256(src.read_bytes()).hexdigest() if src.is_file() else "",
        "profile_revision_count": len(docs),
        "logical_specialist_count": len(grouped),
        "domain_rule_count": rule_count,
        "logical_specialists": logical,
        "specialists": docs,
    }
    dest = pathlib.Path(ns.output)
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_text(json.dumps(out, indent=2, sort_keys=True) + "\n")
    print(f"PASS specialist registry logical={len(grouped)} revisions={len(docs)} domain_rules={rule_count} output={dest}")

if __name__ == "__main__":
    main()
