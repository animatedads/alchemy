#!/usr/bin/env python3
"""Acquisition only: immutable official statutory sources for NSW and Queens offence tests.

Run: python3 law/tools/acquire_nswny_statutes.py --jurisdiction all \
       --out /home/hc3/alchemy-autobuild/legal-sources-20261030

No legal proposition or section extraction is certified by this tool.
Every fetched source gets a byte-exact original, text projection and SHA-256
manifest. The exact provision boundary remains MANUAL_REVIEW_REQUIRED.
No Git writes, no secret-scanning bypass, no mutation of existing sources.
"""
from __future__ import annotations
import argparse
from datetime import datetime, timezone
import hashlib
from html import unescape
from html.parser import HTMLParser
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys
from urllib.parse import urlparse
from urllib.request import Request, urlopen

MAX_BYTES = 50 * 1024 * 1024
HOSTS = {
    "legislation.nysenate.gov", "www.nysenate.gov",
    "legislation.nsw.gov.au", "www.legislation.gov.au",
    "uscode.house.gov", "codelibrary.amlegal.com",
}
def item(region, code, label, url, sections, kind="html"):
    return dict(region=region, code=code, label=label, url=url,
                sections=sections, kind=kind)
SOURCES = []
for law, sections in {
    "PEN": ["105.00","105.05","105.20","135.60","135.65","145.00","145.10",
            "155.05","155.20","155.30","155.35","155.40",
            "170.10","170.25","190.25","190.40","190.42","190.60","190.65",
            "190.78","190.80","190.81","260.31","260.32","260.34"],
    "BNK": ["14-A","340"],
    "GOB": ["5-501"],
    "GBS": ["349"],
}.items():
    for section in sections:
        SOURCES.append(item("us/ny", law + section.replace("-", "_"),
            f"NY {law} sec {section}",
            f"https://legislation.nysenate.gov/pdf/laws/{law}{section}",
            [section], "pdf"))
for sec in ["371","641","1028A","1343","1344"]:
    SOURCES.append(item("us/federal", "USC18_" + sec, f"18 USC {sec}",
        f"https://uscode.house.gov/us/usc/t18/s{sec}/", [sec]))
SOURCES.append(item("us/federal", "USC42_408", "42 USC 408",
    "https://uscode.house.gov/us/usc/t42/s408/", ["408"]))
SOURCES.append(item("us/nyc", "NYC_HOME_IMPROVEMENT",
    "NYC Admin Code 20-386/387/393/401",
    "https://codelibrary.amlegal.com/codes/newyorkcity/latest/NYCadmin/0-0-0-215295",
    ["20-386","20-387","20-393","20-401"]))
# NSW legislation is officially served as consolidated Acts, not individually
# verified section-level endpoints. The whole Act is preserved byte-exact.
SOURCES.extend([
 item("nsw/state", "CRIMES_1900_40", "Crimes Act 1900 (NSW)",
      "https://legislation.nsw.gov.au/view/html/inforce/current/act-1900-040",
      ["117","192B","192C","192D","192E","192G","192I","192J","192K",
       "193B","195","249K","249L","249M","249N","249O","253","254","255"]),
 item("nsw/state", "HOME_BUILDING_1989_147", "Home Building Act 1989 (NSW)",
      "https://legislation.nsw.gov.au/view/html/inforce/current/act-1989-147",
      ["4"]),
 item("nsw/state", "CDPV_2007_80",
      "Crimes (Domestic and Personal Violence) Act 2007 (NSW)",
      "https://legislation.nsw.gov.au/view/html/inforce/current/act-2007-080",
      ["7","13"]),
 # Commonwealth legal sources: specific compiled documents, not transient
 # reinterpreted UK texts. Verify that every section appears in the real body.
 item("nsw/federal", "NCCPA_2009_VOL1", "National Consumer Credit Protection Act s29",
      "https://www.legislation.gov.au/C2009A00134/2026-07-01/2026-07-01/text/original/epub/OEBPS/document_1/document_1.html",
      ["29"]),
 item("nsw/federal", "NCCPA_2009_CODE", "National Credit Code Schedule 1",
      "https://www.legislation.gov.au/C2009A00134/2026-07-01/2026-07-01/text/original/epub/OEBPS/document_2/document_2.html",
      ["4","5","6","32A","32B","140","155"]),
 item("nsw/federal", "SOCIAL_SECURITY_ADMIN_1999",
      "Social Security (Administration) Act 1999",
      "https://www.legislation.gov.au/C2004A00580/2026-09-19/2026-09-19/text/original/epub/OEBPS/document_1/document_1.html",
      ["58","215","216","217"]),
 item("nsw/federal", "CRIMINAL_CODE_1995",
      "Criminal Code Act 1995 (Cth)",
      "https://www.legislation.gov.au/C2004A04868/2026-03-14/2026-03-14/text/original/epub/OEBPS/document_1/document_1.html",
      ["11.5","134.2","135.4"]),
 item("nsw/federal", "AUSTRALIAN_CONSUMER_LAW",
      "Competition and Consumer Act 2010 Schedule 2 ACL",
      "https://www.legislation.gov.au/C2004A00109/2026-08-27/2026-08-27/text/original/epub/OEBPS/document_4/document_4.html",
      ["18","21","151"]),
])

class PlainText(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.buf = []
        self.skip = 0
    def handle_starttag(self, tag, attrs):
        if tag in ("style","script","noscript","svg"):
            self.skip += 1
        if not self.skip and tag in ("p","div","li","h1","h2","h3","h4",
                                    "tr","br","article","section","table"):
            self.buf.append("\n")
    def handle_endtag(self, tag):
        if tag in ("style","script","noscript","svg") and self.skip:
            self.skip -= 1
        elif not self.skip and tag in ("p","div","li","h1","h2","h3",
                                      "h4","tr","article","section"):
            self.buf.append("\n")
    def handle_data(self, data):
        if not self.skip:
            self.buf.append(data)
    def result(self):
        lines = []
        for line in "".join(self.buf).splitlines():
            line = re.sub(r"[ \t]+", " ", unescape(line)).strip()
            if line:
                lines.append(line)
        return "\n".join(lines) + "\n"

def get(src):
    target = src["url"]
    if urlparse(target).hostname not in HOSTS:
        raise ValueError("non-allowlisted source host")
    req = Request(target, headers={
        "User-Agent": "Alchemy-Law-Corpus/0.1 (documentary statutory text capture)",
        "Accept": "application/pdf,text/html,application/xhtml+xml;q=0.9,*/*;q=0.1"})
    with urlopen(req, timeout=90) as response:
        code = response.status
        final_url = response.url
        mime = response.headers.get("Content-Type","")
        data = response.read(MAX_BYTES+1)
    if urlparse(final_url).hostname not in HOSTS:
        raise ValueError("redirect outside allowlisted source hosts: " + final_url)
    if code != 200 or not data or len(data) > MAX_BYTES:
        raise ValueError(f"invalid status or size: HTTP {code}, bytes={len(data)}")
    if src["kind"] == "pdf":
        if not data.startswith(b"%PDF-") or "pdf" not in mime.lower():
            raise ValueError("expected PDF; response is not valid PDF")
    else:
        prefix = data[:4096].lower()
        if "html" not in mime.lower() or not (b"<html" in prefix or b"<!doctype html" in prefix):
            raise ValueError("expected HTML statute; unexpected response body/type")
    return data, final_url, mime

def to_text(src, raw_path, data):
    if src["kind"] == "pdf":
        if shutil.which("pdftotext") is None:
            raise RuntimeError("pdftotext absent; raw PDF retained, text NOT extracted")
        cp = subprocess.run(["pdftotext","-layout","-enc","UTF-8",str(raw_path),"-"],
                            capture_output=True, text=True, check=False)
        if cp.returncode or not cp.stdout.strip():
            raise RuntimeError(f"pdftotext failed rc={cp.returncode}: {cp.stderr[-500:]}")
        return cp.stdout
    parser = PlainText()
    parser.feed(data.decode("utf-8",errors="replace"))
    return parser.result()

def run(args):
    out = Path(args.out).resolve()
    out.mkdir(parents=True, exist_ok=True)
    target = [s for s in SOURCES if args.jurisdiction == "all" or
              (args.jurisdiction == "us" and s["region"].startswith("us/")) or
              (args.jurisdiction == "nsw" and s["region"].startswith("nsw/"))]
    manifest = {"schema":"alchemy.law.acquisition/0.1",
                "retrieval_utc":datetime.now(timezone.utc).isoformat(),
                "source_version_policy":"PINNED_BY_RAW_SHA256_AND_FINAL_URL",
                "historical_applicability":"NOT_ASSESSED_EVENT_DATES_UNKNOWN",
                "legal_text_validation":"MANUAL_PROVISION_BOUNDARY_REVIEW_REQUIRED",
                "complete":False, "files":[], "errors":[]}
    for src in target:
        status={"region":src["region"],"code":src["code"],
                "title":src["label"],"requested_url":src["url"],
                "requested_sections":src["sections"],
                "section_text_verified":False}
        try:
            data, final_url, mime = get(src)
            sha=hashlib.sha256(data).hexdigest()
            relative=Path(src["region"]) / (src["code"]+"_"+sha[:16])
            raw=out / (str(relative)+("."+src["kind"]))
            raw.parent.mkdir(parents=True, exist_ok=True)
            if raw.exists():
                if hashlib.sha256(raw.read_bytes()).hexdigest()!=sha:
                    raise ValueError("existing immutable raw-path hash mismatch")
            else:
                raw.write_bytes(data)
            status.update({"http_status":200,"final_url":final_url,
                           "content_type":mime,"byte_count":len(data),
                           "raw_sha256":sha,"raw_path":str(raw.relative_to(out)),
                           "fetched_at_utc":datetime.now(timezone.utc).isoformat()})
            text = to_text(src, raw, data)
            if len(text.strip()) < 40:
                raise ValueError("text too short to be statute")
            text_path=out / (str(relative)+".txt")
            if text_path.exists() and text_path.read_text(encoding="utf-8") != text:
                raise ValueError("existing text projection differs; don't overwrite")
            text_path.write_text(text,encoding="utf-8")
            status.update({"text_path":str(text_path.relative_to(out)),
                           "text_sha256":hashlib.sha256(text.encode()).hexdigest(),
                           "text_chars":len(text),
                           "text_status":"DOCUMENT_TEXT_UNREVIEWED",
                           "source_format":src["kind"],"retrieval_ok":True})
            # For whole-act sources this is the FULL DOCUMENT text,
            # not a certified clean section excerpt. Never treat TOC hits as
            # proof of a specific section being captured.
            print("FETCHED",src["code"],len(data),sha[:16])
            manifest["files"].append(status)
        except Exception as exc:
            status["error"]=f"{type(exc).__name__}: {exc}"
            manifest["errors"].append(status)
            print("ERROR",src["code"],status["error"],file=sys.stderr)
    manifest["complete"]=not manifest["errors"] and len(manifest["files"])==len(target)
    (out/"source_manifest.json").write_text(json.dumps(manifest,indent=2)+ "\n",encoding="utf-8")
    print("RESULT",len(manifest["files"]),"of",len(target),
          "raw+text", "COMPLETE" if manifest["complete"] else "PARTIAL")
    return 0 if manifest["complete"] else 1

if __name__=="__main__":
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument("--jurisdiction",choices=["us","nsw","all"],default="all")
    p.add_argument("--out",required=True)
    sys.exit(run(p.parse_args()))
