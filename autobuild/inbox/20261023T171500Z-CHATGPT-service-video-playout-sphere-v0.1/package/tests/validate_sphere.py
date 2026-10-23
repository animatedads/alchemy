#!/usr/bin/env python3
"""Static, dependency-free validation of Service Video Playout Gopher sphere.

This does NOT qualify the LLM Gopher loader, foreign runtime, browser or media
hardware. It validates shape and provenance before Autobuild can publish files.
"""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PACK = ROOT / "packs" / "service-video-playout"
SHA = "45108698e6b7166df4181aa4b4008c55479593f1e3a82266542db1029e9c9298"
SOURCE_ROOT = "oorexx_service_video_playout_v0.1-dev3/"
REQUIRED = {
    "svplay.start", "svplay.architecture", "svplay.media", "svplay.devices",
    "svplay.hold", "svplay.ffi", "svplay.scenes", "svplay.qualification",
    "svplay.source-map", "svplay.risks", "svplay.continue",
}

def load(path):
    with path.open("r", encoding="utf-8") as handle:
        return json.load(handle)

def verify():
    meta = load(PACK / "00-sphere.json")
    policy = load(PACK / "01-access-policy.json")
    profile = load(ROOT / "profiles" / "service-video-playout.json")
    corpus = load(PACK / "corpora" / "svplay.lessons.json")
    evidence = load(ROOT / "qualification" / "EVIDENCE.json")
    integration = load(ROOT / "integration.json")
    assert meta["kind"] == "sphere" and meta["id"] == "service-video-playout"
    assert meta["access_policy"] == policy["id"]
    assert policy["kind"] == "access-policy"
    assert all(r["effect"] == "allow" and r["actions"] == ["read"] for r in policy["rules"])
    assert "packs/service-video-playout" in profile["packs"]
    assert profile["id"] == meta["id"]
    assert corpus["kind"] == "corpus" and corpus["sphere"] == meta["id"]
    assert len(corpus["records"]) >= 8
    assert all({"topic", "rule"} <= record.keys() for record in corpus["records"])

    articles = [load(path) for path in sorted((PACK / "articles").glob("*.json"))]
    ids = {a["id"] for a in articles}
    assert ids == REQUIRED, (ids ^ REQUIRED)
    assert set(meta["start_here"]) <= ids
    assert len(meta["start_here"]) >= 5
    for article in articles:
        assert article["kind"] == "article" and article["sphere"] == meta["id"]
        assert article["authority"] in ("project-artifact", "project-doctrine")
        assert len(article["summary"]) > 70
        assert article["invariants"] and isinstance(article["invariants"], list)
        assert isinstance(article["procedure"], list)
        assert article["provenance"]
        for source in article["provenance"]:
            assert source["artifact"] == evidence["artifact"]["name"]
            assert source["sha256"] == SHA
            assert re.fullmatch("[a-f0-9]{64}", source["sha256"])
            assert source["member"].startswith(SOURCE_ROOT)
            assert not source["member"].endswith("/")
            assert source["claim"]
    assert evidence["artifact"]["sha256"] == SHA
    assert evidence["github_source_submission"]["receipt_verified"] is False
    assert evidence["github_source_submission"]["main_published"] is False
    statuses = {a["name"]: a["status"] for a in evidence["qualification"]}
    assert statuses["native-c11-build"] == "PASS"
    assert statuses["ooRexx strict standards"] == "PASS"
    assert statuses["ooRexx/Foreign Runtime dispatch in dev3 environment"] == "NOT_EXECUTED"
    assert statuses["live V4L2 + PipeWire dev3 retest"] == "NOT_TESTED"
    assert statuses["WhatsApp receiver"] == "NOT_TESTED"
    assert statuses["production presentation grant"] == "NOT_IMPLEMENTED"

    assert integration["schema"] == "alchemy.autobuild.integration/0.2"
    assert integration["publish"]["tree"]["path"] == "spheres/service-video-playout-v0.1"
    assert integration["tests"][0]["argv"] == ["python3", "tests/validate_sphere.py"]
    print("PASS: 11 grounded articles, read-only access, profile/corpus, exact SHA and qualification boundaries")

if __name__ == "__main__":
    try:
        verify()
    except (AssertionError, KeyError, OSError, ValueError, TypeError) as exc:
        print(f"FAIL: sphere validation: {exc}", file=sys.stderr)
        sys.exit(1)
