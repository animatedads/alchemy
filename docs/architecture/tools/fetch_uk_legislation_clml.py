#!/usr/bin/env python3
"""Fetch exact six user-requested UK legislation CLML XML endpoints with provenance.

No enactment-date inference: "latest" consolidated XML is NOT necessarily the
text applicable when a historic alleged offence occurred. Run section-level
as-at checks separately. Exit nonzero if any source cannot be validated.
Standard library only. Does not write back to GitHub.
"""
from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
from pathlib import Path
import sys
from urllib.request import Request, urlopen
from xml.etree import ElementTree as ET

ACTS = (
    ("fraud_act_2006", 2006, 35, "Fraud Act 2006"),
    ("theft_act_1968", 1968, 60, "Theft Act 1968"),
    ("fsma_2000", 2000, 8, "Financial Services and Markets Act 2000"),
    ("ssaa_1992", 1992, 5, "Social Security Administration Act 1992"),
    ("poca_2002", 2002, 29, "Proceeds of Crime Act 2002"),
    ("criminal_law_act_1977", 1977, 45, "Criminal Law Act 1977"),
)
MAX_BYTES = 100 * 1024 * 1024


def fetch_one(slug: str, year: int, chapter: int, title: str, out: Path) -> dict:
    url = f"https://www.legislation.gov.uk/ukpga/{year}/{chapter}/data.xml"
    req = Request(url, headers={
        "User-Agent": "Alchemy-Offence-Law-Intake/0.1 (research; contact project owner)",
        "Accept": "application/xml,text/xml;q=0.9,*/*;q=0.1",
    })
    requested_at = dt.datetime.now(dt.timezone.utc).isoformat()
    with urlopen(req, timeout=60) as response:
        status = response.status
        final_url = response.url
        content_type = response.headers.get("Content-Type", "")
        raw = response.read(MAX_BYTES + 1)

    if status != 200:
        raise ValueError(f"HTTP {status}")
    if len(raw) == 0 or len(raw) > MAX_BYTES:
        raise ValueError(f"invalid XML response size {len(raw)}")
    if "xml" not in content_type.lower():
        raise ValueError(f"not XML content type: {content_type!r}")
    # XML must parse; HTML response bodies must never be accepted as statutes.
    root = ET.fromstring(raw)
    local_root = root.tag.rsplit("}", 1)[-1].lower()
    if local_root in ("html", "error", "errorresponse", "rss"):
        raise ValueError(f"wrong XML root: {root.tag!r}")
    digest = hashlib.sha256(raw).hexdigest()
    filename = f"{slug}_{digest[:16]}.xml"
    (out / filename).write_bytes(raw)
    return {
        "title": title,
        "requested_url": url,
        "final_url": final_url,
        "http_status": status,
        "content_type": content_type,
        "fetched_at_utc": requested_at,
        "bytes": len(raw),
        "sha256": digest,
        "root_tag": root.tag,
        "root_attributes": {str(k): str(v) for k, v in root.attrib.items()},
        "raw_filename": filename,
        "latest_or_as_at": "LATEST_ENDPOINT; HISTORIC APPLICABILITY UNVERIFIED",
        "legislative_extent_and_commencement": "NOT YET ASSESSED",
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", default="legislation_clml", help="Output directory")
    args = parser.parse_args()
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    manifest = {"contract": "alchemy-legislation-fetch/0.1",
                "sources": [], "errors": [],
                "warning": "Not an as-at legal opinion; check commencement and provision history."}
    for act in ACTS:
        try:
            result = fetch_one(*act, out)
            manifest["sources"].append(result)
            print("PASS", act[3], result["bytes"], result["sha256"])
        except Exception as exc:
            err = {"title": act[3], "requested_url": f"https://www.legislation.gov.uk/ukpga/{act[1]}/{act[2]}/data.xml",
                   "error": f"{type(exc).__name__}: {exc}"}
            manifest["errors"].append(err)
            print("FAIL", err["title"], err["error"], file=sys.stderr)
    manifest["complete"] = len(manifest["sources"]) == len(ACTS) and not manifest["errors"]
    (out / "fetch_manifest.json").write_text(
        json.dumps(manifest, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    return 0 if manifest["complete"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
