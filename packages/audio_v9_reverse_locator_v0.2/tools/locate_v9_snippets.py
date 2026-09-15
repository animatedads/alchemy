#!/usr/bin/env python3
"""
V9 reverse locator for historical fcpaphos event snippets.

Purpose
-------
Locate degraded/amplified V9 ``evt_NNNNNN.wav`` snippets back into the
canonical 20231009/20231010 ``*_original.ogg`` camera recordings.

The matcher deliberately does not depend on absolute amplitude.  It uses a
constellation-style spectral landmark fingerprint (frequency/time pattern),
then resolves ambiguous hits with V9 generation and chronological ordering.

This utility is an offline forensic/recovery lane.  It is not part of the
Rexx-native candidate DSP/search execution path.
"""
from __future__ import annotations

import argparse
import collections
import csv
import datetime as _dt
import hashlib
import json
import math
import os
import shutil
from pathlib import Path
import re
import sqlite3
import subprocess
import tempfile
import sys
import wave
from typing import Dict, Iterable, Iterator, List, Optional, Sequence, Tuple

try:
    import numpy as np
except Exception as exc:  # pragma: no cover - explicit production diagnostic
    raise SystemExit(f"numpy is required by the V9 locator: {exc}")

SR = 8000
NFFT = 1024
HOP = 512
ANCHOR_STRIDE = 2
LANDMARK_LAGS = (2, 4, 8)
OFFSET_QUANT_FRAMES = 2
FFT_CHUNK_FRAMES = 2048
FMIN = 120.0
FMAX = 3800.0
BAND_EDGES = (120, 250, 400, 650, 1000, 1500, 2200, 3000, 3800)
INDEX_SCHEMA = "audio.v9.reverse-locator.csr-index/1"
INDEX_HASH_SPACE = 1 << 18
RESULT_SCHEMA = "audio.v9.reverse-locator.result/2"
ORIGINAL_RE = re.compile(r"^(20231009|20231010)_(\d{6})_(tp\d{5})_original\.ogg$")
AMP32_RE = re.compile(r"^(20231009|20231010)_(\d{6})_(tp\d{5})_amp32\.ogg$")
EVENT_RE = re.compile(r"^evt_(\d{6})\.wav$")


def die(msg: str) -> "None":
    raise SystemExit(msg)


def run_bytes(argv: Sequence[str]) -> bytes:
    p = subprocess.run(argv, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if p.returncode:
        raise RuntimeError(f"command failed rc={p.returncode}: {' '.join(argv)}\n{p.stderr.decode(errors='replace')}")
    return p.stdout


def require_tool(name: str) -> None:
    from shutil import which
    if not which(name):
        die(f"required executable not found: {name}")


def naive_seconds(dt: _dt.datetime) -> float:
    return (dt - _dt.datetime(1970, 1, 1)).total_seconds()


def parse_original_name(name: str) -> Tuple[_dt.datetime, str]:
    m = ORIGINAL_RE.match(name)
    if not m:
        raise ValueError(name)
    d, hhmmss, cam = m.groups()
    dt = _dt.datetime.strptime(d + hhmmss, "%Y%m%d%H%M%S")
    return dt, cam


def feed_family(path: Path) -> str:
    """Return canonical feed family from the admitted ed209i directory layout."""
    parts = {p.lower() for p in path.parts}
    if "camera_fc" in parts:
        return "fc"
    if "camera_fd" in parts:
        return "fd"
    return "unknown"


def amp32_to_original(name: str) -> Optional[str]:
    m = AMP32_RE.match(name)
    if not m:
        return None
    return f"{m.group(1)}_{m.group(2)}_{m.group(3)}_original.ogg"


def wav_channels(path: Path) -> int:
    with wave.open(str(path), "rb") as w:
        return int(w.getnchannels())


def wav_duration(path: Path) -> float:
    with wave.open(str(path), "rb") as w:
        return w.getnframes() / float(w.getframerate())


def ffprobe_duration(path: Path) -> float:
    out = run_bytes([
        "ffprobe", "-v", "error", "-show_entries", "format=duration",
        "-of", "default=nw=1:nk=1", str(path),
    ]).decode().strip()
    return float(out)


def decode_f32(path: Path, channel: Optional[int] = None, ss: Optional[float] = None,
               duration: Optional[float] = None) -> np.ndarray:
    argv = ["ffmpeg", "-v", "error"]
    if ss is not None:
        argv += ["-ss", f"{max(0.0, ss):.6f}"]
    argv += ["-i", str(path)]
    if duration is not None:
        argv += ["-t", f"{max(0.01, duration):.6f}"]
    if channel is None:
        argv += ["-vn", "-ac", "1"]
    else:
        argv += ["-vn", "-af", f"pan=mono|c0=c{channel}"]
    argv += ["-ar", str(SR), "-f", "f32le", "pipe:1"]
    raw = run_bytes(argv)
    if not raw:
        return np.zeros(0, dtype=np.float32)
    return np.frombuffer(raw, dtype="<f4").astype(np.float32, copy=False)


def decode_f32_file(path: Path, out_path: Path) -> None:
    argv = [
        "ffmpeg", "-y", "-v", "error", "-i", str(path), "-vn", "-ac", "1",
        "-ar", str(SR), "-f", "f32le", str(out_path),
    ]
    p = subprocess.run(argv, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
    if p.returncode:
        raise RuntimeError(f"command failed rc={p.returncode}: {' '.join(argv)}\n{p.stderr.decode(errors='replace')}")


def frame_peaks(y: np.ndarray) -> List[Tuple[int, int, int]]:
    """Return (frame_no, strongest_qfreq, second_qfreq) landmarks.

    FFTs are vectorised in bounded chunks so indexing multi-day source media is
    practical without materialising a whole-file spectrogram.
    """
    if len(y) < NFFT:
        y = np.pad(y, (0, NFFT - len(y)))
    nframes = 1 + (len(y) - NFFT) // HOP
    if nframes <= 0:
        return []
    window = np.hanning(NFFT).astype(np.float32)
    freqs = np.fft.rfftfreq(NFFT, d=1.0 / SR)
    valid = np.where((freqs >= FMIN) & (freqs <= FMAX))[0]
    band_masks = []
    for lo, hi in zip(BAND_EDGES[:-1], BAND_EDGES[1:]):
        idx = np.where((freqs >= lo) & (freqs < hi))[0]
        if len(idx):
            band_masks.append(idx)
    out: List[Tuple[int, int, int]] = []
    base = np.arange(NFFT, dtype=np.int64)
    for first in range(0, nframes, FFT_CHUNK_FRAMES):
        count = min(FFT_CHUNK_FRAMES, nframes - first)
        starts = (first + np.arange(count, dtype=np.int64)) * HOP
        frames = y[starts[:, None] + base[None, :]]
        mag = np.abs(np.fft.rfft(frames * window[None, :], axis=1)) + 1e-12
        logm = np.log(mag)
        meds = np.median(logm[:, valid], axis=1)
        scores = np.empty((count, len(band_masks)), dtype=np.float32)
        qfreq = np.empty((count, len(band_masks)), dtype=np.uint8)
        for bi, idx in enumerate(band_masks):
            local_rel = np.argmax(logm[:, idx], axis=1)
            local = idx[local_rel]
            vals = logm[np.arange(count), local]
            scores[:, bi] = vals - meds
            hz = freqs[local]
            qfreq[:, bi] = np.clip(np.rint(hz / 31.25), 0, 255).astype(np.uint8)
        if not band_masks:
            out.extend((first + i, 0, 0) for i in range(count))
            continue
        order = np.argsort(scores, axis=1)
        best = order[:, -1]
        second = order[:, -2] if len(band_masks) > 1 else best
        for i in range(count):
            out.append((first + i, int(qfreq[i, best[i]]), int(qfreq[i, second[i]])))
    return out


def landmark_hashes(y: np.ndarray) -> List[Tuple[int, int]]:
    """Return (packed_hash, anchor_frame).  Pattern is gain insensitive."""
    peaks = frame_peaks(y)
    rows: List[Tuple[int, int]] = []
    if not peaks:
        return rows
    for i in range(0, len(peaks), ANCHOR_STRIDE):
        frame, f1, f1b = peaks[i]
        # Same-frame frequency geometry.
        rows.append((((0 << 16) | (f1 << 8) | f1b), frame))
        for code, lag in enumerate(LANDMARK_LAGS, start=1):
            j = i + lag
            if j >= len(peaks):
                continue
            _, f2, _ = peaks[j]
            rows.append((((code << 16) | (f1 << 8) | f2), frame))
            rows.append((((code << 16) | (f1b << 8) | f2), frame))
    return rows


def list_snippets(root: Path) -> List[Dict[str, object]]:
    rows = []
    for p in sorted(root.rglob("evt_*.wav")):
        m = EVENT_RE.match(p.name)
        if not m:
            continue
        rows.append({
            "event_id": p.stem,
            "event_no": int(m.group(1)),
            "path": str(p.resolve()),
            "channels": wav_channels(p),
            "duration": wav_duration(p),
            "size": p.stat().st_size,
            "mtime": p.stat().st_mtime,
            "category": p.parent.name,
        })
    return rows


def list_originals(root: Path) -> List[Dict[str, object]]:
    rows = []
    for p in sorted(root.rglob("*.ogg")):
        m = ORIGINAL_RE.match(p.name)
        if not m:
            continue
        dt, cam = parse_original_name(p.name)
        rows.append({
            "name": p.name,
            "path": str(p.resolve()),
            "start": dt.strftime("%Y-%m-%d %H:%M:%S"),
            "start_seconds": naive_seconds(dt),
            "camera": cam,
            "feed": feed_family(p),
            "size_bytes": p.stat().st_size,
            "mtime_ns": p.stat().st_mtime_ns,
        })
    return rows


def noncanonical_oggs(root: Path) -> List[str]:
    bad = []
    for p in root.rglob("*.ogg"):
        if not ORIGINAL_RE.match(p.name):
            bad.append(str(p.resolve()))
    return sorted(bad)


def load_generation_map(path: Optional[Path]) -> Dict[str, Dict[str, str]]:
    if path is None:
        return {}
    out: Dict[str, Dict[str, str]] = {}
    with path.open(newline="", encoding="utf-8") as f:
        r = csv.DictReader(f, delimiter="\t")
        for row in r:
            out[row["event_id"]] = row
    return out


def load_events_jsonl(path: Optional[Path]) -> Dict[str, Dict[str, object]]:
    if path is None:
        return {}
    out = {}
    with path.open(encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if line:
                row = json.loads(line)
                out[row["event_id"]] = row
    return out


def _index_work_dir(index_path: Path) -> Path:
    return index_path.with_name(index_path.name + ".building")


def _write_csr_from_spools(index_path: Path, sources: List[Dict[str, object]],
                           spool_paths: List[Path], counts: np.ndarray,
                           fingerprint: str, total_posts: int) -> None:
    """Seal a direct-address inverted index from per-source posting spools.

    Hashes occupy only 18 bits, so offsets[hash:hash+2] gives a direct packed
    posting slice.  This avoids the very expensive SQLite CREATE INDEX over
    ~17M rows used by v0.1.
    """
    work = _index_work_dir(index_path)
    if work.exists():
        shutil.rmtree(work)
    work.mkdir(parents=True)
    offsets = np.empty(INDEX_HASH_SPACE + 1, dtype=np.uint64)
    offsets[0] = 0
    np.cumsum(counts.astype(np.uint64, copy=False), out=offsets[1:])
    if int(offsets[-1]) != int(total_posts):
        die(f"CSR count mismatch: offsets={int(offsets[-1])} postings={total_posts}")
    np.save(work / "offsets.npy", offsets, allow_pickle=False)
    source_ids = np.lib.format.open_memmap(work / "source_ids.npy", mode="w+", dtype=np.uint16, shape=(total_posts,))
    frames = np.lib.format.open_memmap(work / "frames.npy", mode="w+", dtype=np.uint32, shape=(total_posts,))
    cursor = offsets[:-1].copy()
    for sid, sp in enumerate(spool_paths, start=1):
        arr = np.load(sp, mmap_mode="r", allow_pickle=False)
        if len(arr) == 0:
            continue
        hashes = np.asarray(arr[:, 0], dtype=np.int64)
        fr = np.asarray(arr[:, 1], dtype=np.uint32)
        order = np.argsort(hashes, kind="stable")
        hs = hashes[order]
        fs = fr[order]
        uniq, first, cnt = np.unique(hs, return_index=True, return_counts=True)
        bases = np.repeat(cursor[uniq], cnt)
        local = np.arange(len(hs), dtype=np.uint64) - np.repeat(first.astype(np.uint64), cnt)
        pos = bases + local
        source_ids[pos] = sid
        frames[pos] = fs
        cursor[uniq] += cnt.astype(np.uint64)
        print(f"[csr] packed {sid:3d}/{len(spool_paths)} postings={len(arr)}", flush=True)
    source_ids.flush(); frames.flush()
    del source_ids, frames
    if not np.array_equal(cursor, offsets[1:]):
        die("CSR fill mismatch: not every counted posting was packed")
    meta = {
        "schema": INDEX_SCHEMA,
        "fingerprint": fingerprint,
        "hash_space": INDEX_HASH_SPACE,
        "postings": int(total_posts),
        "source_id_dtype": "uint16",
        "frame_dtype": "uint32",
        "sources": sources,
    }
    (work / "meta.json").write_text(json.dumps(meta, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    if index_path.exists():
        if index_path.is_dir():
            shutil.rmtree(index_path)
        else:
            index_path.unlink()
    work.rename(index_path)


def build_index(index_path: Path, originals_root: Path, expect_originals: int = 120) -> None:
    require_tool("ffmpeg")
    require_tool("ffprobe")
    originals = list_originals(originals_root)
    bad_names = noncanonical_oggs(originals_root)
    if bad_names:
        die(f"canonical-original admission failed: {len(bad_names)} noncanonical .ogg names present; first={bad_names[0]}")
    if expect_originals and len(originals) != expect_originals:
        die(f"canonical-original admission failed: expected {expect_originals}, found {len(originals)}")
    feeds = collections.Counter(str(r.get("feed", "unknown")) for r in originals)
    if set(feeds) != {"fc", "fd"}:
        die(f"canonical-original feed admission failed: expected camera_fc + camera_fd, found {dict(feeds)}")
    parent = index_path.parent
    parent.mkdir(parents=True, exist_ok=True)
    staging = parent / (index_path.name + ".spool")
    if staging.exists():
        shutil.rmtree(staging)
    staging.mkdir()
    counts = np.zeros(INDEX_HASH_SPACE, dtype=np.uint64)
    total_posts = 0
    sources: List[Dict[str, object]] = []
    spool_paths: List[Path] = []
    try:
        for sid, row in enumerate(originals, start=1):
            p = Path(str(row["path"]))
            dur = ffprobe_duration(p)
            src = {
                "source_id": sid, "name": row["name"], "path": str(p),
                "start_seconds": float(row["start_seconds"]), "duration": float(dur),
                "camera": row["camera"], "feed": row["feed"],
                "size_bytes": int(row["size_bytes"]), "mtime_ns": int(row["mtime_ns"]),
            }
            sources.append(src)
            with tempfile.NamedTemporaryFile(prefix="v9-index-", suffix=".f32", dir=str(parent), delete=False) as tf:
                tmp_raw = Path(tf.name)
            try:
                decode_f32_file(p, tmp_raw)
                y = np.memmap(tmp_raw, dtype="<f4", mode="r")
                posts = landmark_hashes(y)
                del y
            finally:
                try: tmp_raw.unlink()
                except FileNotFoundError: pass
            arr = np.asarray(posts, dtype=np.uint32).reshape((-1, 2))
            sp = staging / f"{sid:04d}.npy"
            np.save(sp, arr, allow_pickle=False)
            spool_paths.append(sp)
            if len(arr):
                counts += np.bincount(arr[:, 0].astype(np.int64), minlength=INDEX_HASH_SPACE).astype(np.uint64)
            total_posts += len(arr)
            print(f"[index] {sid:3d}/{len(originals)} {p.name} dur={dur:.1f}s landmarks={len(arr)} total={total_posts}", flush=True)
        print(f"[index] packing direct hash index; landmarks={total_posts}", flush=True)
        _write_csr_from_spools(index_path, sources, spool_paths, counts,
                               f"sr={SR};nfft={NFFT};hop={HOP};anchor={ANCHOR_STRIDE};lags={LANDMARK_LAGS}", total_posts)
    finally:
        shutil.rmtree(staging, ignore_errors=True)
    print(f"[index] complete index={index_path} sources={len(originals)} landmarks={total_posts}")


def convert_sqlite_index(sqlite_path: Path, index_path: Path, originals_root: Path,
                         expect_originals: int = 120) -> None:
    """Salvage v0.1's committed postings without decoding originals again.

    This intentionally requires the old writer to be stopped/completed first;
    it performs two sequential table scans and never needs postings_hash.
    """
    if not sqlite_path.is_file():
        die(f"v0.1 SQLite index not found: {sqlite_path}")
    con = sqlite3.connect(f"file:{sqlite_path}?mode=ro", uri=True, timeout=2.0)
    try:
        rows = list(con.execute("SELECT source_id,name,path,start_seconds,duration,camera,feed,size_bytes,mtime_ns FROM sources ORDER BY source_id"))
        if expect_originals and len(rows) != expect_originals:
            die(f"v0.1 salvage admission failed: expected {expect_originals} sources, found {len(rows)}")
        sources = [{
            "source_id": int(sid), "name": str(name), "path": str(path),
            "start_seconds": float(start), "duration": float(dur), "camera": str(cam), "feed": str(feed),
            "size_bytes": int(size_bytes), "mtime_ns": int(mtime_ns),
        } for sid,name,path,start,dur,cam,feed,size_bytes,mtime_ns in rows]
        current = {str(r["name"]): r for r in list_originals(originals_root)}
        if set(current) != {str(r["name"]) for r in sources}:
            die("v0.1 salvage refused: current canonical source-name set differs from SQLite source set")
        for src in sources:
            now = current[str(src["name"])]
            if (str(now["feed"]), int(now["size_bytes"]), int(now["mtime_ns"])) != (str(src["feed"]), int(src["size_bytes"]), int(src["mtime_ns"])):
                die(f"v0.1 salvage refused: source identity changed for {src['name']}")
        counts = np.zeros(INDEX_HASH_SPACE, dtype=np.uint64)
        total = 0
        cur = con.execute("SELECT hash FROM postings")
        while True:
            got = cur.fetchmany(250000)
            if not got: break
            h = np.fromiter((int(r[0]) for r in got), dtype=np.int64, count=len(got))
            counts += np.bincount(h, minlength=INDEX_HASH_SPACE).astype(np.uint64)
            total += len(got)
            if total % 2000000 < 250000:
                print(f"[salvage] counted {total} postings", flush=True)
        work = _index_work_dir(index_path)
        if work.exists(): shutil.rmtree(work)
        work.mkdir(parents=True)
        offsets = np.empty(INDEX_HASH_SPACE + 1, dtype=np.uint64); offsets[0]=0
        np.cumsum(counts, out=offsets[1:])
        np.save(work / "offsets.npy", offsets, allow_pickle=False)
        sids_out = np.lib.format.open_memmap(work / "source_ids.npy", mode="w+", dtype=np.uint16, shape=(total,))
        frames_out = np.lib.format.open_memmap(work / "frames.npy", mode="w+", dtype=np.uint32, shape=(total,))
        cursor = offsets[:-1].copy()
        done = 0
        cur = con.execute("SELECT hash,source_id,frame FROM postings")
        while True:
            got = cur.fetchmany(250000)
            if not got: break
            arr = np.asarray(got, dtype=np.int64)
            hashes = arr[:,0]; sidv=arr[:,1].astype(np.uint16); frv=arr[:,2].astype(np.uint32)
            order=np.argsort(hashes, kind="stable"); hs=hashes[order]; sv=sidv[order]; fv=frv[order]
            uniq, first, cnt=np.unique(hs, return_index=True, return_counts=True)
            bases=np.repeat(cursor[uniq], cnt)
            local=np.arange(len(hs), dtype=np.uint64)-np.repeat(first.astype(np.uint64), cnt)
            pos=bases+local
            sids_out[pos]=sv; frames_out[pos]=fv; cursor[uniq]+=cnt.astype(np.uint64)
            done += len(got)
            if done % 2000000 < 250000:
                print(f"[salvage] packed {done}/{total} postings", flush=True)
        sids_out.flush(); frames_out.flush(); del sids_out, frames_out
        if not np.array_equal(cursor, offsets[1:]):
            die("v0.1 salvage CSR fill mismatch")
        meta={"schema":INDEX_SCHEMA,"fingerprint":f"sr={SR};nfft={NFFT};hop={HOP};anchor={ANCHOR_STRIDE};lags={LANDMARK_LAGS}","hash_space":INDEX_HASH_SPACE,"postings":int(total),"source_id_dtype":"uint16","frame_dtype":"uint32","sources":sources,"salvaged_from":str(sqlite_path)}
        (work/"meta.json").write_text(json.dumps(meta,indent=2,sort_keys=True)+"\n",encoding="utf-8")
        if index_path.exists():
            shutil.rmtree(index_path) if index_path.is_dir() else index_path.unlink()
        work.rename(index_path)
        print(f"[salvage] complete index={index_path} postings={total}")
    finally:
        con.close()


class CsrIndex:
    def __init__(self, path: Path):
        self.path = path
        try:
            self.meta = json.loads((path / "meta.json").read_text(encoding="utf-8"))
        except Exception as exc:
            die(f"cannot read locator index {path}: {exc}")
        if self.meta.get("schema") != INDEX_SCHEMA:
            die(f"unsupported/missing locator index schema in {path}: {self.meta.get('schema')!r}")
        self.offsets = np.load(path / "offsets.npy", mmap_mode="r", allow_pickle=False)
        self.source_ids = np.load(path / "source_ids.npy", mmap_mode="r", allow_pickle=False)
        self.frames = np.load(path / "frames.npy", mmap_mode="r", allow_pickle=False)
        if len(self.offsets) != INDEX_HASH_SPACE + 1:
            die(f"invalid CSR offsets length in {path}")
        if len(self.source_ids) != len(self.frames) or len(self.source_ids) != int(self.offsets[-1]):
            die(f"invalid CSR posting geometry in {path}")
        self.sources = {int(r["source_id"]): dict(r) for r in self.meta.get("sources", [])}

    def close(self) -> None:
        self.offsets = None; self.source_ids = None; self.frames = None


def source_rows(index: CsrIndex) -> Dict[int, Dict[str, object]]:
    return index.sources


def validate_index_sources(index: CsrIndex, originals_root: Path) -> None:
    current = {str(r["name"]): r for r in list_originals(originals_root)}
    indexed = {str(r["name"]): r for r in index.sources.values()}
    if set(current) != set(indexed):
        missing = sorted(set(indexed) - set(current)); added = sorted(set(current) - set(indexed))
        die(f"stale locator index: canonical source-name set changed; missing={missing[:3]} added={added[:3]}")
    for name, r in current.items():
        old = indexed[name]
        now = {"feed": str(r["feed"]), "size_bytes": int(r["size_bytes"]), "mtime_ns": int(r["mtime_ns"])}
        was = {"feed": str(old["feed"]), "size_bytes": int(old["size_bytes"]), "mtime_ns": int(old["mtime_ns"])}
        if now != was:
            die(f"stale locator index: source identity changed for {name}; indexed={was} current={now}; rebuild index")


def query_channel(index: CsrIndex, y: np.ndarray, top_k: int) -> List[Dict[str, object]]:
    qrows = landmark_hashes(y)
    if not qrows:
        return []
    qby: Dict[int, List[int]] = collections.defaultdict(list)
    for h, qf in qrows:
        qby[int(h)].append(int(qf))
    sources = source_rows(index)
    votes: Dict[Tuple[int, int], float] = collections.defaultdict(float)
    raw_votes: Dict[Tuple[int, int], int] = collections.defaultdict(int)
    for h, qframes in qby.items():
        if h < 0 or h >= INDEX_HASH_SPACE:
            continue
        lo=int(index.offsets[h]); hi=int(index.offsets[h+1])
        n=hi-lo
        if n <= 0:
            continue
        sidv=np.asarray(index.source_ids[lo:hi], dtype=np.int64)
        sfv=np.asarray(index.frames[lo:hi], dtype=np.int64)
        weight=1.0/math.log(2.5+n)
        for qf in qframes:
            oq=np.rint((sfv-qf)/OFFSET_QUANT_FRAMES).astype(np.int64)
            keys=(sidv << 32) | (oq & 0xffffffff)
            uk,cnt=np.unique(keys,return_counts=True)
            for key,c in zip(uk.tolist(),cnt.tolist()):
                sid=int(key >> 32); u=int(key & 0xffffffff); oqv=u if u < 0x80000000 else u-0x100000000
                k=(sid,oqv); votes[k]+=weight*int(c); raw_votes[k]+=int(c)
    dur=len(y)/SR
    cand=[]
    for (sid,oq),w in votes.items():
        s=sources.get(sid)
        if not s: continue
        off_frames=oq*OFFSET_QUANT_FRAMES; off_sec=off_frames*HOP/SR
        if off_sec < -0.5 or off_sec > float(s["duration"])-max(0.5,dur)+0.5: continue
        abs_sec=float(s["start_seconds"])+off_sec
        cand.append({"source_id":sid,"source":s["name"],"camera":s["camera"],"feed":s["feed"],"offset_sec":off_sec,"absolute_seconds":abs_sec,"vote":float(w),"raw_votes":int(raw_votes[(sid,oq)])})
    cand.sort(key=lambda x:(x["vote"],x["raw_votes"]),reverse=True)
    return cand[:top_k]

def pair_dual(a: List[Dict[str, object]], b: List[Dict[str, object]], top_k: int,
              tolerance: float = 2.5) -> List[Dict[str, object]]:
    pairs = []
    for ca in a:
        for cb in b:
            fa, fb = str(ca.get("feed", "unknown")), str(cb.get("feed", "unknown"))
            # Production dual-feed V9 snippets are FC+FD channels.  Refuse same-feed
            # pairings when the canonical directory identity is known.
            if fa != "unknown" and fb != "unknown" and {fa, fb} != {"fc", "fd"}:
                continue
            delta = abs(float(ca["absolute_seconds"]) - float(cb["absolute_seconds"]))
            if delta > tolerance:
                continue
            score = float(ca["vote"]) + float(cb["vote"]) + 2.0 / (1.0 + delta)
            pairs.append({
                "absolute_seconds": (float(ca["absolute_seconds"]) + float(cb["absolute_seconds"])) / 2.0,
                "score": score,
                "agreement_sec": delta,
                "channel0": ca,
                "channel1": cb,
                "method": "dual_landmark_joint",
            })
    pairs.sort(key=lambda x: x["score"], reverse=True)
    return pairs[:top_k]


def metadata_candidates(event: Dict[str, object], originals_by_name: Dict[str, Dict[str, object]]) -> List[Dict[str, object]]:
    # V9 wrote snippets starting two seconds before event.start by default.
    start = _dt.datetime.strptime(str(event["start"]), "%Y-%m-%d %H:%M:%S.%f") - _dt.timedelta(seconds=2)
    abs_sec = naive_seconds(start)
    out = []
    for src in event.get("source_files", []) or []:
        original = amp32_to_original(str(src))
        if not original or original not in originals_by_name:
            continue
        s = originals_by_name[original]
        off = abs_sec - float(s["start_seconds"])
        out.append({
            "source": original,
            "camera": s["camera"],
            "feed": s["feed"],
            "offset_sec": off,
            "absolute_seconds": abs_sec,
            "vote": 0.0,
            "raw_votes": 0,
            "method": "v9_metadata_seed",
        })
    return out


def iso_from_seconds(sec: float) -> str:
    return (_dt.datetime(1970, 1, 1) + _dt.timedelta(seconds=float(sec))).strftime("%Y-%m-%d %H:%M:%S.%f")[:-3]


def sequence_path(event_results: List[Dict[str, object]], tolerance: float = 3.0) -> Dict[str, Dict[str, object]]:
    """Viterbi-like monotonic path over ranked candidate locations."""
    rows = [r for r in event_results if r.get("candidates")]
    rows.sort(key=lambda r: int(r["event_no"]))
    if not rows:
        return {}
    dp: List[List[Tuple[float, Optional[int]]]] = []
    for i, row in enumerate(rows):
        cs = row["candidates"]
        cur: List[Tuple[float, Optional[int]]] = []
        for j, c in enumerate(cs):
            base = float(c.get("score", c.get("vote", 0.0)))
            if i == 0:
                cur.append((base, None)); continue
            best = (-1e100, None)
            prev_cs = rows[i - 1]["candidates"]
            for k, pc in enumerate(prev_cs):
                pscore = dp[i - 1][k][0]
                if pscore <= -1e90:
                    continue
                dt = float(c["absolute_seconds"]) - float(pc["absolute_seconds"])
                if dt < -tolerance:
                    continue
                # Small preference for non-decreasing distinct times; acoustic evidence dominates.
                trans = 0.15 if dt >= 0 else -0.25
                val = pscore + base + trans
                if val > best[0]:
                    best = (val, k)
            cur.append(best)
        dp.append(cur)
    if not dp[-1]:
        return {}
    j = max(range(len(dp[-1])), key=lambda x: dp[-1][x][0])
    if dp[-1][j][0] <= -1e90:
        return {}
    chosen: Dict[str, Dict[str, object]] = {}
    for i in range(len(rows) - 1, -1, -1):
        row = rows[i]
        chosen[str(row["event_id"])] = row["candidates"][j]
        prev = dp[i][j][1]
        if prev is None:
            break
        j = prev
    return chosen


def cmd_inventory(args: argparse.Namespace) -> None:
    snippets = list_snippets(Path(args.snippets))
    originals_root = Path(args.originals)
    originals = list_originals(originals_root)
    bad_names = noncanonical_oggs(originals_root)
    if bad_names:
        die(f"original admission failed: {len(bad_names)} noncanonical .ogg names present; first={bad_names[0]}")
    gens = load_generation_map(Path(args.generations) if args.generations else None)
    by_channels = collections.Counter(int(r["channels"]) for r in snippets)
    by_gen = collections.Counter(gens.get(str(r["event_id"]), {}).get("generation", "unknown") for r in snippets)
    by_feed = collections.Counter(str(r.get("feed", "unknown")) for r in originals)
    print(json.dumps({
        "schema": "audio.v9.reverse-locator.inventory/1",
        "snippets": len(snippets),
        "snippet_channels": dict(sorted(by_channels.items())),
        "snippet_generations": dict(sorted(by_gen.items())),
        "canonical_originals": len(originals),
        "original_feeds": dict(sorted(by_feed.items())),
        "original_name_rule": ORIGINAL_RE.pattern,
    }, indent=2, sort_keys=True))
    if args.expect_snippets and len(snippets) != args.expect_snippets:
        die(f"snippet admission failed: expected {args.expect_snippets}, found {len(snippets)}")
    if args.expect_single and by_channels.get(1, 0) != args.expect_single:
        die(f"single-feed admission failed: expected {args.expect_single}, found {by_channels.get(1, 0)}")
    if args.expect_dual and by_channels.get(2, 0) != args.expect_dual:
        die(f"dual-feed admission failed: expected {args.expect_dual}, found {by_channels.get(2, 0)}")
    unexpected = {k:v for k,v in by_channels.items() if k not in (1,2)}
    if unexpected:
        die(f"snippet channel admission failed: unexpected channel counts {unexpected}")
    if args.expect_originals and len(originals) != args.expect_originals:
        die(f"original admission failed: expected {args.expect_originals}, found {len(originals)}")
    if set(by_feed) != {"fc", "fd"}:
        die(f"original feed admission failed: expected camera_fc + camera_fd, found {dict(by_feed)}")
    bad_layout = [r for r in snippets if (int(r["channels"]) == 1 and r.get("category") != "single_feed") or (int(r["channels"]) == 2 and r.get("category") != "dual_feed")]
    if bad_layout:
        die(f"snippet layout admission failed: {len(bad_layout)} files are not under the channel-correct single_feed/dual_feed directory")


def cmd_seed_report(args: argparse.Namespace) -> None:
    originals = list_originals(Path(args.originals))
    oby = {str(r["name"]): r for r in originals}
    events = load_events_jsonl(Path(args.events))
    gens = load_generation_map(Path(args.generations))
    snippets = list_snippets(Path(args.snippets))
    outp = Path(args.output)
    outp.parent.mkdir(parents=True, exist_ok=True)
    rows = []
    for s in snippets:
        eid = str(s["event_id"])
        generation = gens.get(eid, {}).get("generation", "unknown")
        if generation != args.seed_generation or eid not in events:
            continue
        cs = metadata_candidates(events[eid], oby)
        for c in cs:
            rows.append({
                "event_id": eid,
                "generation": generation,
                "snippet": s["path"],
                "snippet_channels": s["channels"],
                "feed": c.get("feed", ""),
                "source": c["source"],
                "offset_sec": f"{float(c['offset_sec']):.3f}",
                "absolute_time": iso_from_seconds(float(c["absolute_seconds"])),
                "method": c["method"],
            })
    with outp.open("w", newline="", encoding="utf-8") as f:
        fields = ["event_id", "generation", "snippet", "snippet_channels", "feed", "source", "offset_sec", "absolute_time", "method"]
        w = csv.DictWriter(f, fieldnames=fields, delimiter="\t")
        w.writeheader(); w.writerows(rows)
    print(f"[seed] wrote {len(rows)} source mappings for {len(set(r['event_id'] for r in rows))} snippets -> {outp}")


def cmd_locate(args: argparse.Namespace) -> None:
    require_tool("ffmpeg")
    index = CsrIndex(Path(args.index))
    validate_index_sources(index, Path(args.originals))
    snippets = list_snippets(Path(args.snippets))
    gens = load_generation_map(Path(args.generations) if args.generations else None)
    events = load_events_jsonl(Path(args.events) if args.events else None)
    originals = list_originals(Path(args.originals))
    oby = {str(r["name"]): r for r in originals}
    results = []
    for ix, s in enumerate(snippets, start=1):
        eid = str(s["event_id"]); chn = int(s["channels"])
        generation = gens.get(eid, {}).get("generation", "unknown")
        channel_candidates = []
        for ch in range(chn):
            y = decode_f32(Path(str(s["path"])), channel=ch)
            channel_candidates.append(query_channel(index, y, args.top_k_channel))
        if chn >= 2:
            candidates = pair_dual(channel_candidates[0], channel_candidates[1], args.top_k)
        else:
            candidates = []
            for c in channel_candidates[0][:args.top_k]:
                candidates.append({
                    "absolute_seconds": c["absolute_seconds"],
                    "score": c["vote"],
                    "channel0": c,
                    "method": "mono_landmark",
                })
        seeds = []
        if eid in events and (not args.seed_generation or generation == args.seed_generation):
            seeds = metadata_candidates(events[eid], oby)
        # Metadata seed boosts any acoustic candidate agreeing in wall-clock time.
        if seeds:
            seed_times = [float(x["absolute_seconds"]) for x in seeds]
            for c in candidates:
                d = min(abs(float(c["absolute_seconds"]) - t) for t in seed_times)
                c["metadata_delta_sec"] = d
                if d <= 2.5:
                    c["score"] = float(c["score"]) + 5.0 / (1.0 + d)
        candidates.sort(key=lambda x: float(x.get("score", 0.0)), reverse=True)
        result = {
            "schema": RESULT_SCHEMA,
            "event_id": eid,
            "event_no": s["event_no"],
            "generation": generation,
            "snippet": s["path"],
            "channels": chn,
            "duration": s["duration"],
            "metadata_seeds": seeds,
            "candidates": candidates[:args.top_k],
        }
        results.append(result)
        best = candidates[0] if candidates else None
        print(f"[locate] {ix:3d}/{len(snippets)} {eid} gen={generation} ch={chn} best={iso_from_seconds(best['absolute_seconds']) if best else '-'} score={best.get('score',0):.3f if best else 0}", flush=True) if False else print(
            f"[locate] {ix:3d}/{len(snippets)} {eid} gen={generation} ch={chn} " +
            (f"best={iso_from_seconds(float(best['absolute_seconds']))} score={float(best.get('score',0.0)):.3f}" if best else "best=-"), flush=True)
    # Resolve sequence independently per generation.
    chosen = {}
    for gen in sorted({str(r["generation"]) for r in results}):
        sub = [r for r in results if str(r["generation"]) == gen]
        path = sequence_path(sub)
        chosen.update(path)
    out_jsonl = Path(args.output_jsonl)
    out_tsv = Path(args.output_tsv)
    out_jsonl.parent.mkdir(parents=True, exist_ok=True)
    with out_jsonl.open("w", encoding="utf-8") as f:
        for r in results:
            c = chosen.get(str(r["event_id"])) or (r["candidates"][0] if r["candidates"] else None)
            r["chosen"] = c
            if c is not None:
                try:
                    r["chosen_rank"] = r["candidates"].index(c) + 1
                except ValueError:
                    r["chosen_rank"] = 0
            else:
                r["chosen_rank"] = 0
            f.write(json.dumps(r, sort_keys=True) + "\n")
    with out_tsv.open("w", newline="", encoding="utf-8") as f:
        fields = ["event_id", "generation", "channels", "absolute_time", "chosen_rank", "chosen_score", "top_score", "runner_up_score", "method", "feed_ch0", "source_ch0", "offset_ch0", "feed_ch1", "source_ch1", "offset_ch1", "metadata_delta_sec"]
        w = csv.DictWriter(f, fieldnames=fields, delimiter="\t"); w.writeheader()
        for r in results:
            c = r.get("chosen")
            if not c:
                w.writerow({"event_id": r["event_id"], "generation": r["generation"], "channels": r["channels"]}); continue
            c0 = c.get("channel0", {}) or {}; c1 = c.get("channel1", {}) or {}
            scores = [float(x.get("score", 0.0)) for x in r.get("candidates", [])]
            chosen_rank = int(r.get("chosen_rank", 0))
            w.writerow({
                "event_id": r["event_id"], "generation": r["generation"], "channels": r["channels"],
                "absolute_time": iso_from_seconds(float(c["absolute_seconds"])),
                "chosen_rank": chosen_rank,
                "chosen_score": f"{float(c.get('score',0.0)):.6f}",
                "top_score": f"{scores[0]:.6f}" if scores else "",
                "runner_up_score": f"{scores[1]:.6f}" if len(scores) > 1 else "",
                "method": c.get("method", ""),
                "feed_ch0": c0.get("feed", ""), "source_ch0": c0.get("source", ""), "offset_ch0": f"{float(c0.get('offset_sec',0.0)):.3f}" if c0 else "",
                "feed_ch1": c1.get("feed", ""), "source_ch1": c1.get("source", ""), "offset_ch1": f"{float(c1.get('offset_sec',0.0)):.3f}" if c1 else "",
                "metadata_delta_sec": f"{float(c.get('metadata_delta_sec',-1.0)):.3f}" if "metadata_delta_sec" in c else "",
            })
    index.close()
    print(f"[locate] wrote {out_tsv} and {out_jsonl}")


def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(description="Locate V9 event WAV snippets in canonical 20231009/20231010 originals")
    sp = p.add_subparsers(dest="cmd", required=True)
    q = sp.add_parser("inventory")
    q.add_argument("--snippets", required=True); q.add_argument("--originals", required=True)
    q.add_argument("--generations"); q.add_argument("--expect-snippets", type=int, default=671); q.add_argument("--expect-originals", type=int, default=120); q.add_argument("--expect-single", type=int, default=89); q.add_argument("--expect-dual", type=int, default=582)
    q.set_defaults(func=cmd_inventory)
    q = sp.add_parser("build-index")
    q.add_argument("--originals", required=True); q.add_argument("--index", required=True); q.add_argument("--expect-originals", type=int, default=120)
    q.set_defaults(func=lambda a: build_index(Path(a.index), Path(a.originals), a.expect_originals))
    q = sp.add_parser("convert-sqlite")
    q.add_argument("--sqlite", required=True); q.add_argument("--originals", required=True); q.add_argument("--index", required=True); q.add_argument("--expect-originals", type=int, default=120)
    q.set_defaults(func=lambda a: convert_sqlite_index(Path(a.sqlite), Path(a.index), Path(a.originals), a.expect_originals))
    q = sp.add_parser("seed-report")
    q.add_argument("--snippets", required=True); q.add_argument("--originals", required=True); q.add_argument("--events", required=True); q.add_argument("--generations", required=True)
    q.add_argument("--seed-generation", default="gen3_current801"); q.add_argument("--output", required=True)
    q.set_defaults(func=cmd_seed_report)
    q = sp.add_parser("locate")
    q.add_argument("--snippets", required=True); q.add_argument("--originals", required=True); q.add_argument("--index", required=True)
    q.add_argument("--generations"); q.add_argument("--events"); q.add_argument("--seed-generation", default="gen3_current801")
    q.add_argument("--top-k-channel", type=int, default=24); q.add_argument("--top-k", type=int, default=12)
    q.add_argument("--output-tsv", required=True); q.add_argument("--output-jsonl", required=True)
    q.set_defaults(func=cmd_locate)
    return p


def main() -> None:
    args = build_parser().parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
