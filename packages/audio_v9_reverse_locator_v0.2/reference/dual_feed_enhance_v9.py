#!/usr/bin/env python3
"""
dual_feed_enhance_v9_ai_scene.py
=================================
Forensic Audio Enhancement — V9 AI Acoustic Scene Mapper

Concept:
    Detect acoustic events, classify them with AI from short samples, estimate
    their acoustic space, then render an output that suppresses nuisance spaces
    and protects/amplifies intelligence-bearing spaces.

This is intentionally built as a staged pipeline:

    --scan        deterministic acoustic event discovery
    --classify    AI classification of short event samples
    --map-spaces  event grouping / acoustic-space map
    --render      space-aware suppress/protect render
    --all         scan + classify + map-spaces + render

Works with:
    - single camera / single mic tracks
    - dual camera / dual feed projects
    - more than two active streams, though localisation is currently strongest
      for the first two camera groups returned by ForensicHelper.

Required:
    forensic_helper.py beside this script or importable on PYTHONPATH.

AI:
    --ai-provider openai      uses OpenAI audio-capable chat completion style call
    --ai-provider deepthought uses feature-only JSON classification prompt
    --ai-provider none        no AI; uses deterministic fallback labels

API keys:
    openai_key.txt
    deepthought_key.txt

Examples:
    python dual_feed_enhance_v9_ai_scene.py --yaml fcpaphos_project.yaml --tier amp32 \
        --start "2023-10-10 00:00:01" --end "2023-10-11 00:00:01" \
        --ai-provider openai --all --out fcpaphos/v9_scene_2023-10-10.ogg

    python dual_feed_enhance_v9_ai_scene.py --yaml fcpaphos_project.yaml --tier amp32 --scan

    python dual_feed_enhance_v9_ai_scene.py --yaml fcpaphos_project.yaml --tier amp32 \
        --classify --ai-provider deepthought

Outputs:
    <pid>_v9_events.jsonl
    <pid>_v9_ai_classes.jsonl
    <pid>_v9_spaces.json
    <pid>_v9_policy.json
    <pid>_v9_scene_manifest.json
    <out>
"""

from __future__ import annotations

import argparse
import base64
import json
import math
import os
import pickle
import re
import shutil
import subprocess
import sys
import time
import wave
from dataclasses import dataclass, asdict
from datetime import datetime, timedelta
from pathlib import Path
from typing import Any, Dict, Iterable, List, Optional, Tuple

import numpy as np
import soundfile as sf
import librosa
from scipy import signal
from scipy.ndimage import uniform_filter1d

from forensic_helper import ForensicHelper as fh


# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

SR = 22050
N_FFT = 2048
HOP_LENGTH = N_FFT // 4

DEFAULT_SCAN_BLOCK_SEC = 4.0
DEFAULT_SCAN_HOP_SEC = 2.0
DEFAULT_RENDER_BLOCK_SEC = 8.0
DEFAULT_RENDER_HOP_SEC = 4.0
DEFAULT_SNIPPET_MARGIN_SEC = 2.0
DEFAULT_MAX_AI_EVENTS = 300
MAX_LAG_SEC = 0.25

MEDIA_SUFFIXES = {".ogg", ".wav", ".flac", ".mp3", ".m4a", ".aac", ".mp4", ".mov", ".mkv", ".webm", ".avi"}

SUPPRESS_CLASSES = {
    "aircon": 18,
    "fan": 15,
    "electrical_hum": 24,
    "car": 12,
    "motorbike": 12,
    "cat": 10,
    "dog": 8,
    "alarm": 18,
    "siren": 18,
    "rain": 10,
    "wind": 10,
    "music": 10,
    "radio": 10,
}

PROTECT_CLASSES = {
    "speech": 10,
    "voice": 10,
    "conversation": 10,
    "footstep": 4,
    "door": 3,
    "impact": 3,
    "unknown_structured": 5,
}

CLASS_BANDS = {
    "cat": [(650, 5200)],
    "dog": [(250, 3000)],
    "car": [(20, 450)],
    "motorbike": [(30, 900)],
    "aircon": [(40, 500), (900, 2400)],
    "fan": [(40, 600)],
    "electrical_hum": [(45, 65), (95, 125), (145, 185), (195, 245)],
    "alarm": [(700, 4500)],
    "siren": [(450, 5200)],
    "rain": [(1200, 9000)],
    "wind": [(20, 700)],
    "music": [(60, 8000)],
    "radio": [(250, 5000)],
    "speech": [(120, 6500)],
    "voice": [(120, 6500)],
    "conversation": [(120, 6500)],
    "unknown_structured": [(100, 6500)],
}


# ---------------------------------------------------------------------------
# Data models
# ---------------------------------------------------------------------------

@dataclass
class Event:
    event_id: str
    start: str
    end: str
    center: str
    channels: List[str]
    peak_hz: float
    rms_db: float
    z_rms: float
    spectral_flux: float
    tonality: float
    harmonicity: float
    modulation_2_8hz: float
    low_rumble: float
    source_files: List[str]
    snippet_path: Optional[str] = None


@dataclass
class Classification:
    event_id: str
    label: str
    confidence: float
    suppress: bool
    protect: bool
    reason: str
    provider: str
    raw: Dict[str, Any]


@dataclass
class SpaceEstimate:
    event_id: str
    space_id: str
    method: str
    near: str
    range_bucket: str
    lag_samples: Optional[int]
    lag_confidence: float
    ild_db: Optional[float]
    echo_delay_ms: Optional[float]
    stability: float


# ---------------------------------------------------------------------------
# General helpers
# ---------------------------------------------------------------------------

def parse_time_arg(s: Optional[str], default_dt: datetime, project_date: Optional[datetime] = None) -> datetime:
    if not s:
        return default_dt
    if "-" in s:
        parsed = fh.parse_dt(s)
        if parsed:
            return parsed
    base = project_date or default_dt
    parsed = fh.parse_dt(f"{base:%Y-%m-%d} {s}:00")
    if parsed:
        return parsed
    raise ValueError(f"Could not parse time argument: {s!r}")


def project_id_from_yaml(yaml_path: str) -> str:
    return os.path.splitext(os.path.basename(yaml_path))[0]


def ensure_parent(path: str) -> None:
    parent = os.path.dirname(os.path.abspath(path))
    if parent:
        os.makedirs(parent, exist_ok=True)


def dt_to_str(dt: datetime) -> str:
    return dt.strftime("%Y-%m-%d %H:%M:%S.%f")[:-3]


def str_to_dt(s: str) -> datetime:
    for fmt in ("%Y-%m-%d %H:%M:%S.%f", "%Y-%m-%d %H:%M:%S"):
        try:
            return datetime.strptime(s, fmt)
        except ValueError:
            pass
    # Trim milliseconds if stored as 3 decimals
    if "." in s:
        base, frac = s.split(".", 1)
        frac = (frac + "000000")[:6]
        return datetime.strptime(base + "." + frac, "%Y-%m-%d %H:%M:%S.%f")
    raise ValueError(s)


def jsonl_write(path: str, rows: Iterable[Dict[str, Any]]) -> None:
    ensure_parent(path)
    with open(path, "w", encoding="utf-8") as f:
        for row in rows:
            f.write(json.dumps(row, ensure_ascii=False, sort_keys=True) + "\n")


def jsonl_read(path: str) -> List[Dict[str, Any]]:
    if not os.path.exists(path):
        return []
    rows = []
    with open(path, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if line:
                rows.append(json.loads(line))
    return rows


def safe(y: np.ndarray) -> np.ndarray:
    return np.nan_to_num(y, nan=0.0, posinf=0.0, neginf=0.0).astype(np.float32, copy=False)


def rms_db(y: np.ndarray) -> float:
    y = safe(y)
    r = float(np.sqrt(np.mean(y * y) + 1e-12))
    return 20.0 * math.log10(max(r, 1e-12))


def pad_or_trim(y: np.ndarray, n: int) -> np.ndarray:
    if len(y) >= n:
        return y[:n].astype(np.float32, copy=False)
    return np.pad(y, (0, n - len(y))).astype(np.float32, copy=False)


def active_streams_at(streams: List[Dict[str, Any]], t: datetime) -> List[Dict[str, Any]]:
    return [s for s in streams if s["start_dt"] <= t < s["end_dt"]]


def choose_channels(active: List[Dict[str, Any]]) -> Dict[str, Dict[str, Any]]:
    """
    Return one active stream per camera label.

    If multiple tiers of the same camera are active because the YAML has all
    original/amp/enhanced variants, the tier filter should have already narrowed
    them. If duplicates remain, use the most recent start.
    """
    by_cam: Dict[str, Dict[str, Any]] = {}
    for s in sorted(active, key=lambda x: x["start_dt"]):
        by_cam[s.get("cam_id", "Unknown")] = s
    return by_cam


def load_project_streams(yaml_path: str, tier: str, t0: datetime, t1: datetime) -> List[Dict[str, Any]]:
    raw = fh.get_active_streams(yaml_path, t0, t1, max_assumed_hours=96, tier=tier)
    # Some helper versions do not apply tier exactly for generated files, so do a second pass.
    tier_l = (tier or "").lower()
    if tier_l:
        filtered = []
        for s in raw:
            hay = " ".join(str(s.get(k, "")) for k in ("filter", "type", "path")).lower()
            if tier_l in hay or (tier_l == "amp32" and ("+32db" in hay or "raw amp" in hay)):
                filtered.append(s)
        raw = filtered
    raw.sort(key=lambda x: (x["start_dt"], x.get("cam_id", ""), x.get("path", "")))
    return raw


# ---------------------------------------------------------------------------
# Feature extraction
# ---------------------------------------------------------------------------

def spectral_features(y: np.ndarray, sr: int = SR) -> Dict[str, float]:
    y = safe(y)
    if not np.any(y):
        return {
            "peak_hz": 0.0,
            "spectral_flux": 0.0,
            "tonality": 0.0,
            "harmonicity": 0.0,
            "modulation_2_8hz": 0.0,
            "low_rumble": 0.0,
        }

    S = librosa.stft(y, n_fft=N_FFT, hop_length=HOP_LENGTH)
    mag = np.abs(S) + 1e-12
    freqs = librosa.fft_frequencies(sr=sr, n_fft=N_FFT)

    mean_spec = np.mean(mag, axis=1)
    peak_idx = int(np.argmax(mean_spec))
    peak_hz = float(freqs[peak_idx])

    diff = np.diff(mag, axis=1)
    flux = float(np.mean(np.maximum(diff, 0.0)) / (np.mean(mag) + 1e-12))

    # Tonality: peakiness relative to median.
    tonality = float(np.max(mean_spec) / (np.median(mean_spec) + 1e-12))
    tonality = float(np.clip(tonality / 60.0, 0.0, 1.0))

    # Harmonicity: autocorrelation of magnitude spectrum, weak but cheap.
    spec = mean_spec.copy()
    spec /= np.max(spec) + 1e-12
    ac = np.correlate(spec, spec, mode="full")[len(spec)-1:]
    if len(ac) > 5 and ac[0] > 1e-12:
        harmonicity = float(np.max(ac[3:min(len(ac), 120)]) / (ac[0] + 1e-12))
    else:
        harmonicity = 0.0
    harmonicity = float(np.clip(harmonicity * 5.0, 0.0, 1.0))

    # Syllabic modulation in 2–8 Hz from RMS envelope.
    env = librosa.feature.rms(S=mag)[0]
    frame_rate = sr / HOP_LENGTH
    if len(env) > 24 and np.max(env) > 1e-10:
        try:
            b, a = signal.butter(2, [2 / (frame_rate / 2), 8 / (frame_rate / 2)], btype="band")
            mod = signal.filtfilt(b, a, env)
            modulation = float(np.sqrt(np.mean(mod * mod)) / (np.mean(env) + 1e-12))
        except Exception:
            modulation = 0.0
    else:
        modulation = 0.0
    modulation = float(np.clip(modulation / 1.5, 0.0, 1.0))

    low = mean_spec[(freqs >= 20) & (freqs <= 250)].sum()
    total = mean_spec[(freqs >= 20) & (freqs <= 9000)].sum() + 1e-12
    low_rumble = float(np.clip(low / total, 0.0, 1.0))

    return {
        "peak_hz": peak_hz,
        "spectral_flux": flux,
        "tonality": tonality,
        "harmonicity": harmonicity,
        "modulation_2_8hz": modulation,
        "low_rumble": low_rumble,
    }


def deterministic_label_from_features(features: Dict[str, float]) -> Tuple[str, float, str]:
    peak = features.get("peak_hz", 0.0)
    tonality = features.get("tonality", 0.0)
    harm = features.get("harmonicity", 0.0)
    mod = features.get("modulation_2_8hz", 0.0)
    rumble = features.get("low_rumble", 0.0)
    flux = features.get("spectral_flux", 0.0)

    if mod > 0.35 and 120 <= peak <= 4500:
        return "speech", 0.45, "deterministic: speech-like syllabic modulation"
    if rumble > 0.55 and peak < 350:
        return "car", 0.42, "deterministic: low-frequency rumble dominance"
    if tonality > 0.5 and 700 <= peak <= 4500:
        return "alarm", 0.42, "deterministic: narrow tonal peak in alarm band"
    if harm > 0.45 and 600 <= peak <= 5200:
        return "cat", 0.35, "deterministic: harmonic high-frequency event"
    if flux > 0.8:
        return "impact", 0.35, "deterministic: high spectral flux transient"
    return "unknown_structured", 0.25, "deterministic fallback"


# ---------------------------------------------------------------------------
# Event scanning
# ---------------------------------------------------------------------------

def scan_events(args: argparse.Namespace, streams: List[Dict[str, Any]], t0: datetime, t1: datetime) -> List[Event]:
    block_sec = float(args.scan_block_sec)
    hop_sec = float(args.scan_hop_sec)
    block_samples = int(block_sec * SR)

    # First pass: collect per-hop metrics.
    metrics: List[Dict[str, Any]] = []
    t = t0
    idx = 0
    print("[scan] first pass: measuring acoustic energy/structure")
    while t < t1:
        active = choose_channels(active_streams_at(streams, t))
        channel_blocks = []
        source_files = []

        for cam, s in sorted(active.items()):
            y = fh.read_stream_block(s, t, block_sec, SR)
            y = pad_or_trim(y, block_samples)
            if np.any(y):
                channel_blocks.append(y)
                source_files.append(os.path.basename(s.get("path", "")))

        if channel_blocks:
            y_mix = np.mean(np.vstack(channel_blocks), axis=0)
            rd = rms_db(y_mix)
            feats = spectral_features(y_mix)
        else:
            rd = -120.0
            feats = spectral_features(np.zeros(block_samples, dtype=np.float32))

        metrics.append({
            "idx": idx,
            "t": t,
            "rms_db": rd,
            "features": feats,
            "channels": sorted(active.keys()),
            "source_files": sorted(set(source_files)),
        })

        idx += 1
        t += timedelta(seconds=hop_sec)

        if idx % 500 == 0:
            print(f"  [scan] {idx} hops at {t:%Y-%m-%d %H:%M:%S}", end="\r")

    if not metrics:
        return []

    rms_vals = np.array([m["rms_db"] for m in metrics], dtype=float)
    finite = rms_vals[np.isfinite(rms_vals)]
    med = float(np.median(finite)) if len(finite) else -80.0
    mad = float(np.median(np.abs(finite - med))) if len(finite) else 1.0
    robust_sigma = max(1.4826 * mad, 2.5)
    raw_threshold = med + float(args.scan_z) * robust_sigma

    # Audio is normally bounded near 0 dBFS. On very noisy/amplified CCTV,
    # median + N*sigma can become a positive/impossible threshold, which yields
    # zero detections. Clamp the threshold to a sane upper bound.
    threshold = max(float(args.min_rms_db), min(raw_threshold, float(args.max_scan_threshold_db)))

    print(
        f"\n[scan] median={med:.1f} dB, robust_sigma={robust_sigma:.1f}, "
        f"raw_threshold={raw_threshold:.1f} dB, threshold={threshold:.1f} dB"
    )

    candidate_flags = []
    for m in metrics:
        feats = m["features"]
        structured = (
            feats["spectral_flux"] > args.min_flux or
            feats["tonality"] > args.min_tonality or
            feats["harmonicity"] > args.min_harmonicity or
            feats["modulation_2_8hz"] > args.min_modulation
        )
        loud = m["rms_db"] >= threshold
        candidate_flags.append(bool(loud and structured and m["channels"]))

    # Merge adjacent candidates.
    events: List[Event] = []
    i = 0
    event_no = 0
    while i < len(metrics):
        if not candidate_flags[i]:
            i += 1
            continue
        j = i
        while j + 1 < len(metrics) and candidate_flags[j + 1]:
            j += 1

        # Expand slightly.
        si = max(0, i - 1)
        sj = min(len(metrics) - 1, j + 1)
        group = metrics[si:sj + 1]

        start = group[0]["t"]
        end = group[-1]["t"] + timedelta(seconds=block_sec)
        center = start + (end - start) / 2

        best = max(group, key=lambda x: x["rms_db"])
        feats = best["features"]
        z = (best["rms_db"] - med) / robust_sigma

        event = Event(
            event_id=f"evt_{event_no:06d}",
            start=dt_to_str(start),
            end=dt_to_str(end),
            center=dt_to_str(center),
            channels=sorted(set(ch for g in group for ch in g["channels"])),
            peak_hz=float(feats["peak_hz"]),
            rms_db=float(best["rms_db"]),
            z_rms=float(z),
            spectral_flux=float(feats["spectral_flux"]),
            tonality=float(feats["tonality"]),
            harmonicity=float(feats["harmonicity"]),
            modulation_2_8hz=float(feats["modulation_2_8hz"]),
            low_rumble=float(feats["low_rumble"]),
            source_files=sorted(set(sf for g in group for sf in g["source_files"])),
        )
        events.append(event)
        event_no += 1
        i = j + 1

    # Rank/limit only if requested; default keeps all.
    if args.max_events and len(events) > args.max_events:
        events.sort(key=lambda e: (e.z_rms, e.tonality + e.harmonicity + e.modulation_2_8hz), reverse=True)
        events = events[:args.max_events]
        events.sort(key=lambda e: e.start)

    out_events = args.events_file or f"{args.pid}_v9_events.jsonl"
    jsonl_write(out_events, [asdict(e) for e in events])
    print(f"[scan] wrote {len(events)} events to {out_events}")
    return events


# ---------------------------------------------------------------------------
# Snippet extraction
# ---------------------------------------------------------------------------

def write_event_snippet(
    event: Event,
    streams: List[Dict[str, Any]],
    snippet_dir: str,
    margin_sec: float = DEFAULT_SNIPPET_MARGIN_SEC,
    max_sec: float = 10.0,
) -> Optional[str]:
    os.makedirs(snippet_dir, exist_ok=True)

    start = str_to_dt(event.start) - timedelta(seconds=margin_sec)
    end = str_to_dt(event.end) + timedelta(seconds=margin_sec)
    dur = min(max_sec, max(1.0, (end - start).total_seconds()))
    samples = int(dur * SR)

    active = choose_channels(active_streams_at(streams, start + timedelta(seconds=dur / 2)))
    if not active:
        return None

    cams = sorted(active.keys())
    blocks = []
    for cam in cams[:2]:
        y = fh.read_stream_block(active[cam], start, dur, SR)
        blocks.append(pad_or_trim(y, samples))

    if not blocks:
        return None
    if len(blocks) == 1:
        data = blocks[0]
    else:
        data = np.vstack(blocks).T

    out = os.path.join(snippet_dir, f"{event.event_id}.wav")
    sf.write(out, data, SR, subtype="PCM_16")
    return out


# ---------------------------------------------------------------------------
# AI classification
# ---------------------------------------------------------------------------

def read_key(provider: str) -> str:
    key_file = "openai_key.txt" if provider == "openai" else f"{provider}_key.txt"
    try:
        return Path(key_file).read_text().strip()
    except Exception:
        return ""


def extract_json_object(text: str) -> Dict[str, Any]:
    text = (text or "").strip()
    text = text.replace("```json", "").replace("```", "").strip()
    try:
        return json.loads(text)
    except Exception:
        pass

    m = re.search(r"\{.*\}", text, flags=re.S)
    if m:
        return json.loads(m.group(0))
    raise ValueError(f"No JSON object in model response: {text[:300]!r}")


def classification_prompt(event: Event, policy: Dict[str, Any], include_audio: bool) -> str:
    suppress_names = sorted(policy.get("suppress_classes", SUPPRESS_CLASSES).keys())
    protect_names = sorted(policy.get("protect_classes", PROTECT_CLASSES).keys())

    return f"""
You are classifying a short forensic CCTV audio event.

Return ONLY valid JSON with these keys:
{{
  "class": "one of: speech, cat, dog, bird, car, motorbike, aircon, fan, alarm, siren, door, impact, footstep, rain, wind, music, radio, electrical_hum, unknown_structured, unknown_noise",
  "confidence": 0.0,
  "suppress": true,
  "protect": false,
  "reason": "short reason",
  "traits": ["brief acoustic traits"]
}}

Policy:
- Suppress classes: {suppress_names}
- Protect classes: {protect_names}
- Unknown structured sounds should usually be protected, not suppressed.
- Never classify as speech unless speech/voice/conversation is plausible.
- If uncertain, use unknown_structured or unknown_noise.

Event features:
- id: {event.event_id}
- time: {event.center}
- rms_db: {event.rms_db:.1f}
- peak_hz: {event.peak_hz:.1f}
- spectral_flux: {event.spectral_flux:.3f}
- tonality: {event.tonality:.3f}
- harmonicity: {event.harmonicity:.3f}
- modulation_2_8hz: {event.modulation_2_8hz:.3f}
- low_rumble: {event.low_rumble:.3f}
- channels: {event.channels}
- audio_attached: {include_audio}
""".strip()


def classify_with_openai(event: Event, snippet_path: Optional[str], policy: Dict[str, Any], model: str) -> Dict[str, Any]:
    """
    OpenAI audio classification.

    Uses an audio-capable chat-completions style payload. If the specific model
    or account does not support audio input, this function falls back to a
    text-only feature prompt so the pipeline can still proceed.
    """
    import requests

    api_key = read_key("openai")
    if not api_key:
        raise RuntimeError("Missing openai_key.txt")

    prompt = classification_prompt(event, policy, include_audio=bool(snippet_path))
    headers = {"Authorization": f"Bearer {api_key}", "Content-Type": "application/json"}

    content: List[Dict[str, Any]] = [{"type": "text", "text": prompt}]

    if snippet_path and os.path.exists(snippet_path):
        with open(snippet_path, "rb") as f:
            b64 = base64.b64encode(f.read()).decode("ascii")
        content.append({
            "type": "input_audio",
            "input_audio": {
                "data": b64,
                "format": "wav"
            }
        })

    payload = {
        "model": model,
        "messages": [{"role": "user", "content": content}],
        "temperature": 0.1,
        "response_format": {"type": "json_object"},
    }

    url = "https://api.openai.com/v1/chat/completions"
    r = requests.post(url, headers=headers, json=payload, timeout=60)

    # Fallback for models/accounts that reject input_audio.
    if r.status_code >= 400 and snippet_path:
        fallback_payload = {
            "model": "gpt-4o",
            "messages": [{"role": "user", "content": classification_prompt(event, policy, include_audio=False)}],
            "temperature": 0.1,
            "response_format": {"type": "json_object"},
        }
        r = requests.post(url, headers=headers, json=fallback_payload, timeout=60)

    r.raise_for_status()
    data = r.json()
    text = data["choices"][0]["message"]["content"]
    return extract_json_object(text)


def classify_with_deepthought(event: Event, snippet_path: Optional[str], policy: Dict[str, Any], model: str) -> Dict[str, Any]:
    """
    DeepThought classifier.

    This is feature-prompt based because the local helper's DeepThought route is
    treated as OpenAI-compatible text chat. If your DeepThought endpoint supports
    audio, adapt this function to attach the WAV.
    """
    import requests

    api_key = read_key("deepthought")
    if not api_key:
        raise RuntimeError("Missing deepthought_key.txt")

    prompt = classification_prompt(event, policy, include_audio=False)
    headers = {"Authorization": f"Bearer {api_key}", "Content-Type": "application/json"}
    payload = {
        "model": model,
        "messages": [{"role": "user", "content": prompt}],
        "temperature": 0.1,
        "response_format": {"type": "json_object"},
    }
    url = os.environ.get("DEEPTHOUGHT_API_URL", "https://api.deepthought.ai/v1/chat/completions")
    r = requests.post(url, headers=headers, json=payload, timeout=60)
    r.raise_for_status()
    data = r.json()
    text = data["choices"][0]["message"]["content"]
    return extract_json_object(text)


def normalise_classification(event: Event, raw: Dict[str, Any], provider: str) -> Classification:
    label = str(raw.get("class") or raw.get("label") or "unknown_structured").strip().lower()
    label = label.replace(" ", "_")
    conf = float(raw.get("confidence", 0.25) or 0.25)
    conf = float(np.clip(conf, 0.0, 1.0))

    suppress = bool(raw.get("suppress", label in SUPPRESS_CLASSES))
    protect = bool(raw.get("protect", label in PROTECT_CLASSES or label.startswith("unknown")))

    # Safety: speech/unknown protected unless explicit high-confidence suppress.
    if label in {"speech", "voice", "conversation", "unknown_structured"}:
        suppress = False
        protect = True

    reason = str(raw.get("reason") or "")
    return Classification(
        event_id=event.event_id,
        label=label,
        confidence=conf,
        suppress=suppress,
        protect=protect,
        reason=reason,
        provider=provider,
        raw=raw,
    )


def classify_events(args: argparse.Namespace, streams: List[Dict[str, Any]]) -> List[Classification]:
    event_rows = jsonl_read(args.events_file or f"{args.pid}_v9_events.jsonl")
    events = [Event(**row) for row in event_rows]
    if not events:
        print("[classify] no events found; run --scan first")
        return []

    policy = load_or_create_policy(args)
    snippet_dir = args.snippet_dir or f"{args.pid}_v9_snippets"
    provider = args.ai_provider

    existing_rows = jsonl_read(args.classes_file or f"{args.pid}_v9_ai_classes.jsonl")
    existing = {row["event_id"]: row for row in existing_rows if "event_id" in row}
    classifications: List[Classification] = [Classification(**row) for row in existing_rows if row.get("event_id")]

    to_process = [e for e in events if e.event_id not in existing]
    to_process.sort(key=lambda e: e.z_rms, reverse=True)

    if args.max_ai_events:
        to_process = to_process[:args.max_ai_events]

    print(f"[classify] existing={len(existing)}, pending={len(to_process)}, provider={provider}")

    for i, event in enumerate(to_process, start=1):
        snippet = write_event_snippet(event, streams, snippet_dir, args.snippet_margin_sec, args.snippet_max_sec)
        event.snippet_path = snippet

        raw: Dict[str, Any]
        try:
            if provider == "openai":
                raw = classify_with_openai(event, snippet, policy, args.openai_model)
            elif provider == "deepthought":
                raw = classify_with_deepthought(event, snippet, policy, args.deepthought_model)
            elif provider == "none":
                label, conf, reason = deterministic_label_from_features(asdict(event))
                raw = {"class": label, "confidence": conf, "suppress": label in SUPPRESS_CLASSES, "protect": label in PROTECT_CLASSES or label.startswith("unknown"), "reason": reason}
            else:
                raise RuntimeError(f"Unsupported provider: {provider}")
        except Exception as exc:
            label, conf, reason = deterministic_label_from_features(asdict(event))
            raw = {
                "class": label,
                "confidence": conf,
                "suppress": label in SUPPRESS_CLASSES,
                "protect": label in PROTECT_CLASSES or label.startswith("unknown"),
                "reason": f"AI failed: {exc}; {reason}",
                "error": str(exc),
            }

        cls = normalise_classification(event, raw, provider)
        classifications.append(cls)

        # Append incrementally so long runs can resume.
        with open(args.classes_file or f"{args.pid}_v9_ai_classes.jsonl", "a", encoding="utf-8") as f:
            f.write(json.dumps(asdict(cls), ensure_ascii=False, sort_keys=True) + "\n")

        print(f"  [classify] {i}/{len(to_process)} {event.event_id}: {cls.label} conf={cls.confidence:.2f} suppress={cls.suppress}")

    return classifications


# ---------------------------------------------------------------------------
# Space mapping
# ---------------------------------------------------------------------------

def gcc_phat_lag(y_a: np.ndarray, y_b: np.ndarray, max_delay_sec: float = MAX_LAG_SEC) -> Tuple[int, float]:
    y_a = safe(y_a)
    y_b = safe(y_b)
    n = len(y_a) + len(y_b) - 1
    nfft = 1 << int(np.ceil(np.log2(max(n, 2))))
    A = np.fft.rfft(y_a, n=nfft)
    B = np.fft.rfft(y_b, n=nfft)
    cross = A * np.conj(B)
    cc = np.fft.irfft(cross / (np.abs(cross) + 1e-10), n=nfft)
    max_lag = int(max_delay_sec * SR)
    search = np.concatenate([cc[-max_lag:], cc[:max_lag + 1]])
    abs_search = np.abs(search)
    idx = int(np.argmax(abs_search))
    lag = idx - max_lag
    peak = float(abs_search[idx])
    med = float(np.median(abs_search) + 1e-12)
    conf = peak / med
    return lag, conf


def estimate_echo_delay_ms(y: np.ndarray) -> Optional[float]:
    y = safe(y)
    if not np.any(y):
        return None
    try:
        onset = librosa.onset.onset_strength(y=y, sr=SR)
        if len(onset) < 10 or np.max(onset) <= 1e-12:
            return None
        ac = librosa.autocorrelate(onset, max_size=int(0.18 * SR / HOP_LENGTH))
        min_frames = max(1, int(0.012 * SR / HOP_LENGTH))
        ac[:min_frames] = 0
        peaks, props = signal.find_peaks(ac, distance=2, prominence=np.max(ac) * 0.08)
        if len(peaks) == 0:
            return None
        return float(peaks[0] * HOP_LENGTH / SR * 1000.0)
    except Exception:
        return None


def estimate_space_for_event(event: Event, streams: List[Dict[str, Any]]) -> SpaceEstimate:
    center = str_to_dt(event.center)
    active = choose_channels(active_streams_at(streams, center))
    cams = sorted(active.keys())

    dur = max(1.0, min(8.0, (str_to_dt(event.end) - str_to_dt(event.start)).total_seconds()))
    samples = int(dur * SR)

    if len(cams) >= 2:
        cam_a, cam_b = cams[0], cams[1]
        y_a = pad_or_trim(fh.read_stream_block(active[cam_a], center - timedelta(seconds=dur / 2), dur, SR), samples)
        y_b = pad_or_trim(fh.read_stream_block(active[cam_b], center - timedelta(seconds=dur / 2), dur, SR), samples)

        lag, conf = gcc_phat_lag(y_a, y_b)
        rms_a = rms_db(y_a)
        rms_b = rms_db(y_b)
        ild = rms_a - rms_b
        near = cam_a if ild > 3 else cam_b if ild < -3 else "between"
        lag_bin = int(round(lag / 25.0) * 25)
        space_id = f"dual_lag_{lag_bin:+05d}_{near.replace(' ', '_')}"
        stability = float(np.clip(conf / 20.0, 0.0, 1.0))
        return SpaceEstimate(
            event_id=event.event_id,
            space_id=space_id,
            method="dual_tdoa_ild",
            near=near,
            range_bucket="unknown",
            lag_samples=int(lag),
            lag_confidence=float(conf),
            ild_db=float(ild),
            echo_delay_ms=None,
            stability=stability,
        )

    if len(cams) == 1:
        cam = cams[0]
        y = pad_or_trim(fh.read_stream_block(active[cam], center - timedelta(seconds=dur / 2), dur, SR), samples)
        echo = estimate_echo_delay_ms(y)
        rd = rms_db(y)

        if echo is None:
            range_bucket = "diffuse"
        elif echo < 25:
            range_bucket = "near"
        elif echo < 80:
            range_bucket = "mid"
        else:
            range_bucket = "far_echoic"

        space_id = f"single_{cam.replace(' ', '_')}_{range_bucket}"
        stability = 0.4 if echo is None else float(np.clip(1.0 - min(echo, 150.0) / 180.0, 0.2, 0.8))
        return SpaceEstimate(
            event_id=event.event_id,
            space_id=space_id,
            method="single_echo_range",
            near=cam,
            range_bucket=range_bucket,
            lag_samples=None,
            lag_confidence=0.0,
            ild_db=None,
            echo_delay_ms=echo,
            stability=stability,
        )

    return SpaceEstimate(
        event_id=event.event_id,
        space_id="no_active_stream",
        method="none",
        near="unknown",
        range_bucket="unknown",
        lag_samples=None,
        lag_confidence=0.0,
        ild_db=None,
        echo_delay_ms=None,
        stability=0.0,
    )


def map_spaces(args: argparse.Namespace, streams: List[Dict[str, Any]]) -> Dict[str, Any]:
    event_rows = jsonl_read(args.events_file or f"{args.pid}_v9_events.jsonl")
    class_rows = jsonl_read(args.classes_file or f"{args.pid}_v9_ai_classes.jsonl")
    events = [Event(**row) for row in event_rows]
    class_by_event = {row["event_id"]: row for row in class_rows if "event_id" in row}

    estimates: List[SpaceEstimate] = []
    for i, event in enumerate(events, start=1):
        estimates.append(estimate_space_for_event(event, streams))
        if i % 200 == 0:
            print(f"  [spaces] mapped {i}/{len(events)}", end="\r")

    spaces: Dict[str, Dict[str, Any]] = {}
    for est in estimates:
        cls = class_by_event.get(est.event_id, {})
        label = cls.get("label", "unclassified")
        suppress = bool(cls.get("suppress", False))
        protect = bool(cls.get("protect", False))

        sp = spaces.setdefault(est.space_id, {
            "space_id": est.space_id,
            "method": est.method,
            "events": [],
            "class_counts": {},
            "suppress_count": 0,
            "protect_count": 0,
            "default_action": "preserve",
        })
        sp["events"].append(est.event_id)
        sp["class_counts"][label] = sp["class_counts"].get(label, 0) + 1
        if suppress:
            sp["suppress_count"] += 1
        if protect:
            sp["protect_count"] += 1

    for sp in spaces.values():
        if sp["suppress_count"] > sp["protect_count"] and sp["suppress_count"] >= 2:
            sp["default_action"] = "suppress_if_class_matches"
        elif sp["protect_count"] > 0:
            sp["default_action"] = "protect"
        else:
            sp["default_action"] = "preserve"

    out = {
        "project": args.pid,
        "created_at": datetime.now().isoformat(timespec="seconds"),
        "spaces": sorted(spaces.values(), key=lambda x: x["space_id"]),
        "event_spaces": [asdict(e) for e in estimates],
    }

    path = args.spaces_file or f"{args.pid}_v9_spaces.json"
    ensure_parent(path)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(out, f, indent=2, sort_keys=True)
    print(f"\n[spaces] wrote {len(spaces)} spaces / {len(estimates)} event estimates to {path}")
    return out


# ---------------------------------------------------------------------------
# Render
# ---------------------------------------------------------------------------

def load_or_create_policy(args: argparse.Namespace) -> Dict[str, Any]:
    path = args.policy_file or f"{args.pid}_v9_policy.json"
    if os.path.exists(path):
        with open(path, "r", encoding="utf-8") as f:
            return json.load(f)

    policy = {
        "suppress_classes": SUPPRESS_CLASSES,
        "protect_classes": PROTECT_CLASSES,
        "class_bands": CLASS_BANDS,
        "never_hard_delete": True,
        "max_suppression_db": 24,
        "preserve_unknown": True,
        "created_at": datetime.now().isoformat(timespec="seconds"),
    }
    with open(path, "w", encoding="utf-8") as f:
        json.dump(policy, f, indent=2, sort_keys=True)
    return policy


def attenuation_mask_for_events(
    block_start: datetime,
    block_end: datetime,
    events: List[Event],
    classes: Dict[str, Classification],
    policy: Dict[str, Any],
    n_frames: int,
    freqs: np.ndarray,
) -> np.ndarray:
    mask = np.ones((len(freqs), n_frames), dtype=np.float32)

    suppress_classes = policy.get("suppress_classes", SUPPRESS_CLASSES)
    class_bands = policy.get("class_bands", CLASS_BANDS)
    max_supp = float(policy.get("max_suppression_db", 24))

    block_dur = max(1e-6, (block_end - block_start).total_seconds())

    for event in events:
        e0 = str_to_dt(event.start)
        e1 = str_to_dt(event.end)
        if e1 < block_start or e0 > block_end:
            continue

        cls = classes.get(event.event_id)
        if not cls or not cls.suppress:
            continue

        label = cls.label
        supp_db = float(suppress_classes.get(label, 8))
        supp_db = min(supp_db, max_supp)
        gain = 10 ** (-supp_db / 20.0)

        overlap0 = max(block_start, e0)
        overlap1 = min(block_end, e1)
        f0 = int(np.floor(((overlap0 - block_start).total_seconds() / block_dur) * n_frames))
        f1 = int(np.ceil(((overlap1 - block_start).total_seconds() / block_dur) * n_frames))
        f0 = max(0, min(n_frames - 1, f0))
        f1 = max(f0 + 1, min(n_frames, f1))

        bands = class_bands.get(label) or [(80, 6500)]
        for lo, hi in bands:
            band = (freqs >= float(lo)) & (freqs <= float(hi))
            if np.any(band):
                mask[band, f0:f1] = np.minimum(mask[band, f0:f1], gain)

    # Smooth time/frequency edges to reduce obvious artifacts.
    if mask.shape[1] > 3:
        mask = uniform_filter1d(mask, size=3, axis=1)
    if mask.shape[0] > 5:
        mask = uniform_filter1d(mask, size=5, axis=0)
    return np.clip(mask, 10 ** (-max_supp / 20.0), 1.0)


def protection_gain_for_events(
    block_start: datetime,
    block_end: datetime,
    events: List[Event],
    classes: Dict[str, Classification],
    policy: Dict[str, Any],
) -> float:
    protect_classes = policy.get("protect_classes", PROTECT_CLASSES)
    gain_db = 0.0
    for event in events:
        e0 = str_to_dt(event.start)
        e1 = str_to_dt(event.end)
        if e1 < block_start or e0 > block_end:
            continue
        cls = classes.get(event.event_id)
        if cls and cls.protect:
            gain_db = max(gain_db, float(protect_classes.get(cls.label, 3)))
    return min(gain_db, 12.0)


def render_scene(args: argparse.Namespace, streams: List[Dict[str, Any]], t0: datetime, t1: datetime) -> str:
    events = [Event(**row) for row in jsonl_read(args.events_file or f"{args.pid}_v9_events.jsonl")]
    cls_rows = jsonl_read(args.classes_file or f"{args.pid}_v9_ai_classes.jsonl")
    classes = {row["event_id"]: Classification(**row) for row in cls_rows if "event_id" in row}

    if not events:
        print("[render] no events found; output will be a helper-consistent mix")

    policy = load_or_create_policy(args)

    out_path = args.out or f"{args.pid}_v9_ai_scene.ogg"
    ensure_parent(out_path)

    block_sec = float(args.render_block_sec)
    hop_sec = float(args.render_hop_sec)
    block_samples = int(block_sec * SR)
    hop_samples = int(hop_sec * SR)
    win = signal.windows.hann(block_samples, sym=False).astype(np.float32)

    ola = np.zeros(block_samples * 2, dtype=np.float32)
    ola_w = np.zeros(block_samples * 2, dtype=np.float32)

    fmt = "OGG" if out_path.lower().endswith(".ogg") else None
    subtype = "VORBIS" if fmt == "OGG" else None

    freqs = librosa.fft_frequencies(sr=SR, n_fft=N_FFT)

    t = t0
    blocks = 0
    with sf.SoundFile(out_path, mode="w", samplerate=SR, channels=1, format=fmt, subtype=subtype) as out_f:
        while t < t1:
            active = choose_channels(active_streams_at(streams, t))
            blocks_y = []

            for cam, s in sorted(active.items())[:2]:
                y = fh.read_stream_block(s, t, block_sec, SR)
                blocks_y.append(pad_or_trim(y, block_samples))

            if not blocks_y:
                y_mix = fh.generate_comfort_noise(block_samples, db=-60).astype(np.float32)
            elif len(blocks_y) == 1:
                y_mix = blocks_y[0]
            else:
                # Basic dual mix. Spatial suppression is event/space-based in the mask;
                # future versions can replace this with source-separated TDOA masks.
                y_mix = 0.5 * blocks_y[0] + 0.5 * blocks_y[1]

            block_end = t + timedelta(seconds=block_sec)
            local_events = [e for e in events if str_to_dt(e.end) >= t and str_to_dt(e.start) <= block_end]

            S = librosa.stft(safe(y_mix), n_fft=N_FFT, hop_length=HOP_LENGTH)
            mask = attenuation_mask_for_events(t, block_end, local_events, classes, policy, S.shape[1], freqs)
            S2 = S * mask

            y_out = librosa.istft(S2, hop_length=HOP_LENGTH, length=block_samples)
            protect_db = protection_gain_for_events(t, block_end, local_events, classes, policy)
            if protect_db > 0:
                y_out *= 10 ** (protect_db / 20.0)

            # Safety limiter at block level; no per-hop normalisation.
            peak = np.max(np.abs(y_out))
            if peak > 1.0:
                y_out = y_out / peak * 0.98

            ola[:block_samples] += safe(y_out) * win
            ola_w[:block_samples] += win

            chunk = ola[:hop_samples] / np.maximum(ola_w[:hop_samples], 1e-8)
            out_f.write(safe(chunk))

            ola[:block_samples] = ola[hop_samples:hop_samples + block_samples]
            ola[block_samples:] = 0
            ola_w[:block_samples] = ola_w[hop_samples:hop_samples + block_samples]
            ola_w[block_samples:] = 0

            t += timedelta(seconds=hop_sec)
            blocks += 1
            if blocks % 100 == 0:
                pct = 100.0 * (t - t0).total_seconds() / max(1.0, (t1 - t0).total_seconds())
                print(f"  [render] {pct:5.1f}% {t:%Y-%m-%d %H:%M:%S}", end="\r")

    manifest = {
        "project": args.pid,
        "yaml": args.yaml,
        "tier": args.tier,
        "start": dt_to_str(t0),
        "end": dt_to_str(t1),
        "out": out_path,
        "events": args.events_file or f"{args.pid}_v9_events.jsonl",
        "classes": args.classes_file or f"{args.pid}_v9_ai_classes.jsonl",
        "spaces": args.spaces_file or f"{args.pid}_v9_spaces.json",
        "policy": args.policy_file or f"{args.pid}_v9_policy.json",
        "created_at": datetime.now().isoformat(timespec="seconds"),
    }
    manifest_path = f"{args.pid}_v9_scene_manifest.json"
    with open(manifest_path, "w", encoding="utf-8") as f:
        json.dump(manifest, f, indent=2, sort_keys=True)

    print(f"\n[render] wrote {out_path}")
    print(f"[render] wrote manifest {manifest_path}")
    return out_path


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(description="V9 AI acoustic scene mapper")
    p.add_argument("--yaml", required=True, help="Project YAML")
    p.add_argument("--tier", default="amp32", help="Tier/filter to use, e.g. amp32, plus20, enhanced, original")
    p.add_argument("--start", help="Start time: full timestamp or HH:MM")
    p.add_argument("--end", help="End time: full timestamp or HH:MM")
    p.add_argument("--out", help="Rendered output file")

    p.add_argument("--scan", action="store_true")
    p.add_argument("--classify", action="store_true")
    p.add_argument("--map-spaces", action="store_true", dest="map_spaces")
    p.add_argument("--render", action="store_true")
    p.add_argument("--all", action="store_true")

    p.add_argument("--events-file")
    p.add_argument("--classes-file")
    p.add_argument("--spaces-file")
    p.add_argument("--policy-file")
    p.add_argument("--snippet-dir")

    p.add_argument("--scan-block-sec", type=float, default=DEFAULT_SCAN_BLOCK_SEC)
    p.add_argument("--scan-hop-sec", type=float, default=DEFAULT_SCAN_HOP_SEC)
    p.add_argument("--scan-z", type=float, default=1.6)
    p.add_argument("--min-rms-db", type=float, default=-48.0)
    p.add_argument("--max-scan-threshold-db", type=float, default=-12.0,
                   help="Upper clamp for event RMS threshold. Prevents loud/noisy projects from producing impossible positive dBFS thresholds.")
    p.add_argument("--min-flux", type=float, default=0.12)
    p.add_argument("--min-tonality", type=float, default=0.10)
    p.add_argument("--min-harmonicity", type=float, default=0.10)
    p.add_argument("--min-modulation", type=float, default=0.08)
    p.add_argument("--max-events", type=int, default=0, help="Limit retained scan events; 0 means no limit")

    p.add_argument("--ai-provider", default="openai", choices=["openai", "deepthought", "none"])
    p.add_argument("--openai-model", default=os.environ.get("OPENAI_AUDIO_MODEL", "gpt-4o-audio-preview"))
    p.add_argument("--deepthought-model", default=os.environ.get("DEEPTHOUGHT_MODEL", "deepthought-core"))
    p.add_argument("--max-ai-events", type=int, default=DEFAULT_MAX_AI_EVENTS)
    p.add_argument("--snippet-margin-sec", type=float, default=DEFAULT_SNIPPET_MARGIN_SEC)
    p.add_argument("--snippet-max-sec", type=float, default=10.0)

    p.add_argument("--render-block-sec", type=float, default=DEFAULT_RENDER_BLOCK_SEC)
    p.add_argument("--render-hop-sec", type=float, default=DEFAULT_RENDER_HOP_SEC)

    return p


def main() -> None:
    args = build_parser().parse_args()
    args.pid = project_id_from_yaml(args.yaml)

    # Resolve project stream bounds.
    with open(args.yaml, "r", encoding="utf-8") as f:
        import yaml
        config = yaml.safe_load(f) or {}

    starts = [fh.parse_dt(e.get("start")) for e in config.get("files", []) if isinstance(e, dict) and e.get("start")]
    starts = [s for s in starts if s]
    if not starts:
        raise SystemExit("No start times in YAML.")

    default_start = min(starts)
    default_end = max(starts) + timedelta(hours=4)
    t0 = parse_time_arg(args.start, default_start, default_start)
    t1 = parse_time_arg(args.end, default_end, default_start)
    if t1 <= t0:
        raise SystemExit("End time must be after start time.")

    print("=" * 72)
    print("V9 AI Acoustic Scene Mapper")
    print(f"Project : {args.pid}")
    print(f"Tier    : {args.tier}")
    print(f"Window  : {t0:%Y-%m-%d %H:%M:%S} -> {t1:%Y-%m-%d %H:%M:%S}")
    print("=" * 72)

    streams = load_project_streams(args.yaml, args.tier, t0, t1)
    if not streams:
        raise SystemExit(f"No streams found for tier={args.tier!r} in requested window.")

    print(f"[init] active stream candidates: {len(streams)}")

    do_scan = args.scan or args.all
    do_classify = args.classify or args.all
    do_map = args.map_spaces or args.all
    do_render = args.render or args.all

    if not any([do_scan, do_classify, do_map, do_render]):
        print("No action selected. Use --scan, --classify, --map-spaces, --render, or --all.")
        return

    if do_scan:
        scan_events(args, streams, t0, t1)

    if do_classify:
        classify_events(args, streams)

    if do_map:
        map_spaces(args, streams)

    if do_render:
        render_scene(args, streams, t0, t1)


if __name__ == "__main__":
    main()
