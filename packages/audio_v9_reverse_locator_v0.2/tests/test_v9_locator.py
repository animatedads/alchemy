#!/usr/bin/env python3
"""Qualification tests for the offline V9 reverse locator."""
from __future__ import annotations
import csv
import argparse
import importlib.util
import json
import os
import sqlite3
import subprocess
import tempfile
import wave
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
MOD = ROOT / "tools" / "locate_v9_snippets.py"
spec = importlib.util.spec_from_file_location("v9loc", MOD)
loc = importlib.util.module_from_spec(spec)
assert spec.loader is not None
spec.loader.exec_module(loc)


def write_wav(path: Path, y: np.ndarray, sr: int = 8000) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(sr)
        w.writeframes((np.clip(y, -1, 1) * 32767).astype("<i2").tobytes())


def write_stereo_wav(path: Path, left: np.ndarray, right: np.ndarray, sr: int = 22050) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    n = min(len(left), len(right))
    inter = np.column_stack([np.clip(left[:n], -1, 1), np.clip(right[:n], -1, 1)])
    with wave.open(str(path), "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(sr)
        w.writeframes((inter * 32767).astype("<i2").tobytes())


def synthetic_signal(seed: int, dur: int = 50, sr: int = 8000) -> np.ndarray:
    t = np.arange(sr * dur, dtype=np.float64) / sr
    rng = np.random.default_rng(seed)
    phase = 2 * np.pi * (310 * t + 45 * np.sin(2 * np.pi * 0.09 * t))
    y = 0.08 * np.sin(phase)
    y += 0.05 * np.sin(2 * np.pi * (820 + 120 * np.sin(2 * np.pi * 0.13 * t)) * t)
    y *= 0.45 + 0.55 * np.sin(2 * np.pi * 0.71 * t) ** 2
    for c in (6.2, 14.7, 22.1, 29.4, 36.8, 44.1):
        y += 0.14 * np.exp(-0.5 * ((t - c) / 0.08) ** 2) * np.sin(2 * np.pi * 1700 * t)
    y += 0.005 * rng.standard_normal(len(t))
    return y.astype(np.float32)


def test_generation_proof() -> None:
    gen = {}
    with (ROOT / "reference" / "V9_SNIPPET_GENERATIONS.tsv").open(newline="", encoding="utf-8") as f:
        for r in csv.DictReader(f, delimiter="\t"):
            gen[r["event_id"]] = r["generation"]
    assert len(gen) == 671
    assert sum(v == "gen1_legacy" for v in gen.values()) == 71
    assert sum(v == "gen2_legacy" for v in gen.values()) == 300
    assert sum(v == "gen3_current801" for v in gen.values()) == 300

    events = [json.loads(x) for x in (ROOT / "reference" / "V9_GEN3_EVENTS.jsonl").read_text().splitlines() if x.strip()]
    assert len(events) == 801
    assert [r["event_id"] for r in events] == [f"evt_{i:06d}" for i in range(801)]
    starts = [r["start"] for r in events]
    assert starts == sorted(starts)

    old = {eid for eid, g in gen.items() if g in {"gen1_legacy", "gen2_legacy"}}
    pending = [r for r in events if r["event_id"] not in old]
    expected = {r["event_id"] for r in sorted(pending, key=lambda r: r["z_rms"], reverse=True)[:300]}
    actual = {eid for eid, g in gen.items() if g == "gen3_current801"}
    assert expected == actual, "gen3 must exactly reproduce V9 pending/z_rms/max_ai_events=300 selection"


def test_gain_clipped_dual_match() -> None:
    with tempfile.TemporaryDirectory() as td:
        d = Path(td)
        fc = d / "orig" / "camera_fc"
        fd = d / "orig" / "camera_fd"
        fc.mkdir(parents=True)
        fd.mkdir(parents=True)
        sr = 8000
        yfc = synthetic_signal(1)
        yfd = synthetic_signal(2) * 0.9
        t = np.arange(len(yfd)) / sr
        yfd += (0.025 * np.sin(2 * np.pi * 1170 * t)).astype(np.float32)

        wfc = fc / "fc.wav"
        wfd = fd / "fd.wav"
        write_wav(wfc, yfc, sr)
        write_wav(wfd, yfd, sr)
        ofc = fc / "20231009_080000_tp00206_original.ogg"
        ofd = fd / "20231009_075955_tp00015_original.ogg"
        subprocess.check_call(["ffmpeg", "-y", "-v", "error", "-i", str(wfc), str(ofc)])
        subprocess.check_call(["ffmpeg", "-y", "-v", "error", "-i", str(wfd), str(ofd)])

        dbp = d / "index.v9idx"
        loc.build_index(dbp, d / "orig", expect_originals=2)
        con = loc.CsrIndex(dbp)
        try:
            # Same wall-clock instant: FC +20 s == FD +25 s.  Apply extreme
            # amplification/nonlinear clipping to model the historical amp32 path.
            gain = 10 ** (32 / 20)
            q0 = np.tanh(yfc[20 * sr:30 * sr] * gain * 0.7).astype(np.float32)
            q1 = np.tanh(yfd[25 * sr:35 * sr] * gain * 0.7).astype(np.float32)
            a = loc.query_channel(con, q0, 8)
            b = loc.query_channel(con, q1, 8)
            pairs = loc.pair_dual(a, b, 5)
            assert pairs
            best = pairs[0]
            assert best["channel0"]["feed"] == "fc"
            assert best["channel1"]["feed"] == "fd"
            assert best["channel0"]["source"] == ofc.name
            assert best["channel1"]["source"] == ofd.name
            assert abs(float(best["channel0"]["offset_sec"]) - 20.0) < 0.25
            assert abs(float(best["channel1"]["offset_sec"]) - 25.0) < 0.25
            assert float(best["agreement_sec"]) < 0.25
            loc.validate_index_sources(con, d / "orig")
            st = ofc.stat()
            os.utime(ofc, ns=(st.st_atime_ns, st.st_mtime_ns + 1_000_000_000))
            try:
                loc.validate_index_sources(con, d / "orig")
            except SystemExit:
                pass
            else:
                raise AssertionError("stale source index must fail closed after source identity change")
        finally:
            con.close()




def test_salvage_v1_sqlite() -> None:
    with tempfile.TemporaryDirectory() as td:
        d = Path(td)
        fc = d / "orig" / "camera_fc"; fd = d / "orig" / "camera_fd"
        fc.mkdir(parents=True); fd.mkdir(parents=True)
        sr = 8000
        yfc = synthetic_signal(11, dur=20); yfd = synthetic_signal(12, dur=20)
        wfc=d/"fc.wav"; wfd=d/"fd.wav"; write_wav(wfc,yfc,sr); write_wav(wfd,yfd,sr)
        ofc=fc/"20231009_080000_tp00206_original.ogg"; ofd=fd/"20231009_075955_tp00015_original.ogg"
        subprocess.check_call(["ffmpeg","-y","-v","error","-i",str(wfc),str(ofc)])
        subprocess.check_call(["ffmpeg","-y","-v","error","-i",str(wfd),str(ofd)])
        originals=loc.list_originals(d/"orig")
        old=d/"v1.sqlite"; con=sqlite3.connect(old)
        con.execute("CREATE TABLE sources(source_id INTEGER PRIMARY KEY, name TEXT UNIQUE, path TEXT, start_seconds REAL, duration REAL, camera TEXT, feed TEXT, size_bytes INTEGER, mtime_ns INTEGER)")
        con.execute("CREATE TABLE postings(hash INTEGER NOT NULL, source_id INTEGER NOT NULL, frame INTEGER NOT NULL)")
        for sid,row in enumerate(originals,start=1):
            path=Path(str(row["path"])); dur=loc.ffprobe_duration(path)
            con.execute("INSERT INTO sources VALUES(?,?,?,?,?,?,?,?,?)",(sid,row["name"],str(path),row["start_seconds"],dur,row["camera"],row["feed"],row["size_bytes"],row["mtime_ns"]))
            y=loc.decode_f32(path)
            con.executemany("INSERT INTO postings VALUES(?,?,?)",((h,sid,fr) for h,fr in loc.landmark_hashes(y)))
        con.commit(); con.close()
        new=d/"salvaged.v9idx"
        loc.convert_sqlite_index(old,new,d/"orig",expect_originals=2)
        idx=loc.CsrIndex(new)
        try:
            q=np.tanh(yfc[5*sr:15*sr]*(10**(32/20))*0.7).astype(np.float32)
            c=loc.query_channel(idx,q,5)
            assert c and c[0]["source"]==ofc.name
            assert abs(float(c[0]["offset_sec"])-5.0)<0.25
            assert idx.meta.get("salvaged_from")==str(old)
        finally:
            idx.close()


def test_production_layout_admission() -> None:
    with tempfile.TemporaryDirectory() as td:
        d = Path(td)
        snippets = d / "snippets"
        originals = d / "originals"
        (snippets / "single_feed").mkdir(parents=True)
        (snippets / "dual_feed").mkdir(parents=True)
        (originals / "camera_fc").mkdir(parents=True)
        (originals / "camera_fd").mkdir(parents=True)
        # Tiny files are enough for inventory; channel geometry is authoritative.
        mono = np.zeros(2205, dtype=np.float32)
        write_wav(snippets / "single_feed" / "evt_000001.wav", mono, 22050)
        write_stereo_wav(snippets / "dual_feed" / "evt_000002.wav", mono, mono, 22050)
        # Encode valid canonical originals so noncanonical admission can be tested.
        w = d / "x.wav"; write_wav(w, np.zeros(8000, dtype=np.float32), 8000)
        subprocess.check_call(["ffmpeg", "-y", "-v", "error", "-i", str(w), str(originals / "camera_fc" / "20231009_080000_tp00206_original.ogg")])
        subprocess.check_call(["ffmpeg", "-y", "-v", "error", "-i", str(w), str(originals / "camera_fd" / "20231009_080001_tp00015_original.ogg")])
        a = argparse.Namespace(snippets=str(snippets), originals=str(originals), generations=None, expect_snippets=2, expect_originals=2, expect_single=1, expect_dual=1)
        loc.cmd_inventory(a)
        bad = originals / "camera_fc" / "20231009_080000_20231009_080000_tp00206_original.ogg"
        bad.write_bytes(b"bad")
        try:
            loc.cmd_inventory(a)
        except SystemExit:
            pass
        else:
            raise AssertionError("noncanonical original name must fail closed")


def main() -> None:
    test_generation_proof()
    print("PASS V9 generation provenance/selection proof")
    test_production_layout_admission()
    print("PASS V9 FC/FD + single/dual production admission")
    test_salvage_v1_sqlite()
    print("PASS V9 v0.1 SQLite postings salvage -> CSR")
    test_gain_clipped_dual_match()
    print("PASS V9 +32dB/clipped FC/FD landmark recovery")
    print("PASS ALL V9 REVERSE LOCATOR TESTS")


if __name__ == "__main__":
    main()
