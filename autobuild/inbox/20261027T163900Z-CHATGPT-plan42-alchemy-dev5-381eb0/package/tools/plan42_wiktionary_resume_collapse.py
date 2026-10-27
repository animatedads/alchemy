#!/usr/bin/env python3
"""Resume the cheap Wiktionary Plan42 post-pass after extraction has completed.

This does not reread the large Wiktextract JSONL input.  It collapses the already
written per-language TSV files and rebuilds the soundex bucket files.
"""
from __future__ import annotations

import argparse
import re
from pathlib import Path
from typing import Iterable

SUPPORTED_LANGS = [
    "ar", "bg", "ca", "cmn", "cs", "da", "de", "el", "es", "fa", "fi", "fr",
    "grc", "he", "hi", "hu", "it", "ja", "ko", "nl", "no", "pl", "pt", "ro",
    "ru", "sh", "sv", "tr", "uk", "zh",
]


def parse_langs(value: str | Iterable[str] | None) -> list[str]:
    if value is None or value == "":
        return list(SUPPORTED_LANGS)
    if isinstance(value, str):
        value = value.replace(",", " ").split()
    return [str(item).strip() for item in value if str(item).strip()]


def collapse_tsv(path: Path, *, merge: bool = False) -> dict[str, int]:
    """Collapse duplicate first-column rows in place.

    merge=False keeps the first value for each key.
    merge=True merges whitespace-separated values across duplicate rows.
    """
    if not path.exists():
        return {"exists": 0, "input_rows": 0, "output_rows": 0}

    rows: dict[str, str | set[str]] = {}
    order: list[str] = []
    input_rows = 0
    with path.open("r", encoding="utf-8", errors="replace") as handle:
        for raw_line in handle:
            line = raw_line.rstrip("\n")
            if not line:
                continue
            input_rows += 1
            key, value = line.split("\t", 1) if "\t" in line else (line, "")
            if key not in rows:
                rows[key] = set() if merge else value
                order.append(key)
            if merge:
                assert isinstance(rows[key], set)
                rows[key].update(part for part in value.split() if part)

    tmp = path.with_suffix(path.suffix + ".tmp")
    with tmp.open("w", encoding="utf-8") as handle:
        for key in order:
            value_obj = rows[key]
            value = " ".join(sorted(value_obj)) if isinstance(value_obj, set) else value_obj
            handle.write(f"{key}\t{value}\n")
    tmp.replace(path)
    return {"exists": 1, "input_rows": input_rows, "output_rows": len(order)}


def soundex_key(text: str) -> str:
    clean = "".join(ch for ch in str(text).upper() if ch.isalpha())
    if not clean:
        return "Z000"
    codes = {
        "B":"1", "F":"1", "P":"1", "V":"1",
        "C":"2", "G":"2", "J":"2", "K":"2", "Q":"2", "S":"2", "X":"2", "Z":"2",
        "D":"3", "T":"3", "L":"4", "M":"5", "N":"5", "R":"6",
    }
    out = clean[0]
    prev = codes.get(clean[0], "0")
    for ch in clean[1:]:
        code = codes.get(ch, "0")
        if code != "0" and code != prev:
            out += code
        if code != "0":
            prev = code
        if len(out) >= 4:
            break
    return (out + "000")[:4]


def build_soundex_from_ipa(output_dir: Path, lang: str) -> dict[str, int]:
    ipa_path = output_dir / f"{lang}.ipa"
    soundex_path = output_dir / f"{lang}.soundex"
    buckets: dict[str, list[str]] = {}
    if ipa_path.exists():
        with ipa_path.open("r", encoding="utf-8", errors="replace") as handle:
            for raw_line in handle:
                line = raw_line.rstrip("\n")
                if not line or "\t" not in line:
                    continue
                word, ipa = line.split("\t", 1)
                key = soundex_key(ipa or word)
                buckets.setdefault(key, []).append(word)
    with soundex_path.open("w", encoding="utf-8") as handle:
        for key in sorted(buckets):
            handle.write(f"{key}\t{' '.join(buckets[key])}\n")
    return {"buckets": len(buckets), "words": sum(len(v) for v in buckets.values())}


def resume(output_dir: Path, langs: list[str], *, skip_soundex: bool = False) -> dict[str, object]:
    output_dir.mkdir(parents=True, exist_ok=True)
    report: dict[str, object] = {"output_dir": str(output_dir), "languages": {}}
    language_reports: dict[str, object] = {}
    for lang in langs:
        words = collapse_tsv(output_dir / f"{lang}.words", merge=False)
        scope = collapse_tsv(output_dir / f"{lang}.scope", merge=True)
        ipa = collapse_tsv(output_dir / f"{lang}.ipa", merge=False)
        soundex = {"skipped": 1} if skip_soundex else build_soundex_from_ipa(output_dir, lang)
        language_reports[lang] = {"words": words, "scope": scope, "ipa": ipa, "soundex": soundex}
        print(
            f"{lang}: words {words['input_rows']}->{words['output_rows']}  "
            f"scope {scope['input_rows']}->{scope['output_rows']}  "
            f"ipa {ipa['input_rows']}->{ipa['output_rows']}",
            flush=True,
        )
    report["languages"] = language_reports
    return report


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output_dir", required=True)
    parser.add_argument("--target_langs", default="")
    parser.add_argument("--skip_soundex", action="store_true")
    parser.add_argument("--report", default="")
    args = parser.parse_args()

    output_dir = Path(args.output_dir)
    report = resume(output_dir, parse_langs(args.target_langs), skip_soundex=args.skip_soundex)
    if args.report:
        import json
        Path(args.report).write_text(json.dumps(report, indent=2, sort_keys=True), encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
