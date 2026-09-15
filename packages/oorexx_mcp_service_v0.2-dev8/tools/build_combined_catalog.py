#!/usr/bin/env python3
"""Build the MCP Project Service composite component catalog.

This is a packaging/qualification utility only.  Runtime MCP service code reads
catalog/components.json and has no Python dependency.
"""
import argparse, hashlib, json
from pathlib import Path


def load(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--runtime", default="catalog/runtime_components.json")
    ap.add_argument("--spheres", default="catalog/sphere_components.json")
    ap.add_argument("--output", default="catalog/components.json")
    args=ap.parse_args()
    runtime=load(Path(args.runtime))
    spheres=load(Path(args.spheres))
    out={
        "schema":"oorexx.mcp.component.catalog/2",
        "sourceArtifact":runtime.get("sourceArtifact",""),
        "sourceSha256":runtime.get("sourceSha256",""),
        "sources":[
            {"kind":"api-rollup","artifact":runtime.get("sourceArtifact",""),"sha256":runtime.get("sourceSha256","")},
            {"kind":"sphere-rollup","artifact":spheres.get("sourceArtifact",""),"sha256":spheres.get("sourceSha256","")},
        ],
        "components":runtime["components"]+spheres["components"],
    }
    Path(args.output).write_text(json.dumps(out,indent=2,ensure_ascii=False)+"\n",encoding="utf-8")
    ids={r["componentId"] for r in out["components"]}
    print(f"wrote {args.output}: entries={len(out['components'])} uniqueComponentIds={len(ids)}")

if __name__=="__main__":
    main()
