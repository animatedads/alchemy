#!/usr/bin/env python3
"""Optional Chromaprint/AcoustID adapter for Layered Audio.

No API key is stored in source. For lookup set ACOUSTID_API_KEY in the
process environment. Extraction can be used offline when pyacoustid and
Chromaprint/fpcalc are installed.
"""
import argparse
import hashlib
import json
import os
import sys


def fingerprint(path):
    import acoustid
    duration, fp = acoustid.fingerprint_file(path)
    if isinstance(fp, bytes):
        fp = fp.decode("ascii")
    return {
        "schema": "layered-audio.music-fingerprint.v1",
        "provider": "Chromaprint",
        "algorithm": "CHROMAPRINT",
        "duration_seconds": float(duration),
        "fingerprint": fp,
        "fingerprint_encoding": "CHROMAPRINT_BASE64",
        "source_sha256": hashlib.sha256(open(path, "rb").read()).hexdigest(),
    }


def lookup(path, meta="recordings recordingids releases releaseids"):
    import acoustid
    key = os.environ.get("ACOUSTID_API_KEY")
    if not key:
        raise RuntimeError("ACOUSTID_API_KEY is required for network lookup")
    duration, fp = acoustid.fingerprint_file(path)
    if isinstance(fp, bytes):
        fp = fp.decode("ascii")
    rows = []
    for score, recording_id, title, artist in acoustid.lookup(key, fp, duration, meta=meta):
        rows.append({
            "score": float(score),
            "recording_id": recording_id,
            "title": title,
            "artist": artist,
        })
    return {
        "schema": "layered-audio.music-identification.v1",
        "provider": "AcoustID",
        "api": "v2",
        "duration_seconds": float(duration),
        "matches": rows,
    }


def main():
    p = argparse.ArgumentParser()
    p.add_argument("mode", choices=["fingerprint", "lookup"])
    p.add_argument("audio")
    args = p.parse_args()
    data = fingerprint(args.audio) if args.mode == "fingerprint" else lookup(args.audio)
    json.dump(data, sys.stdout, sort_keys=True, separators=(",", ":"))
    sys.stdout.write("\n")


if __name__ == "__main__":
    main()
