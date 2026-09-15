"""Audio ASR preparation helpers for ForeignPython.

The functions here deliberately do *not* own transcript semantics. They prepare
resident Torch tensors and return primitive timing/diagnostic values which the
ooRexx audio layer turns into transcript-view evidence.
"""
from __future__ import annotations

import math
from typing import List, Dict

import torch
import torchaudio


def _mono_1d(signal: torch.Tensor) -> torch.Tensor:
    x = signal
    if x.ndim == 2:
        # Canonical Layered Audio input is [1,time]; tolerate [time,1].
        if x.shape[0] == 1:
            x = x[0]
        elif x.shape[1] == 1:
            x = x[:, 0]
        else:
            x = x.mean(dim=0)
    elif x.ndim > 2:
        x = x.reshape(-1)
    return x.detach().to(dtype=torch.float32, device="cpu").contiguous()


def diagnostics(signal: torch.Tensor, sample_rate: int = 16000) -> Dict[str, float]:
    x = _mono_1d(signal)
    if x.numel() == 0:
        return {
            "samples": 0,
            "duration_seconds": 0.0,
            "peak": 0.0,
            "rms": 0.0,
            "rms_dbfs": -120.0,
            "mean": 0.0,
        }
    rms = torch.sqrt(torch.mean(x * x) + 1e-20).item()
    peak = torch.max(torch.abs(x)).item()
    return {
        "samples": int(x.numel()),
        "duration_seconds": float(x.numel()) / float(sample_rate),
        "peak": float(peak),
        "rms": float(rms),
        "rms_dbfs": float(20.0 * math.log10(max(rms, 1e-12))),
        "mean": float(torch.mean(x).item()),
    }


def speech_regions(
    signal: torch.Tensor,
    sample_rate: int = 16000,
    frame_ms: float = 20.0,
    hop_ms: float = 10.0,
    noise_percentile: float = 20.0,
    threshold_margin_db: float = 8.0,
    absolute_floor_db: float = -34.0,
    hangover_ms: float = 180.0,
    merge_gap_ms: float = 650.0,
    pad_ms: float = 350.0,
    min_region_ms: float = 450.0,
    max_region_seconds: float = 12.0,
    overlap_seconds: float = 0.75,
) -> List[Dict[str, float]]:
    """Return conservative speech-like regions using frame RMS energy.

    This is intentionally a *segmentation hypothesis*, not a speech decision.
    It avoids sending long stretches of low-level camera ambience to an RNN-LM
    ASR where the language model can hallucinate fluent text.
    """
    x = _mono_1d(signal)
    n_samples = int(x.numel())
    if n_samples == 0:
        return []

    frame = max(1, int(round(sample_rate * frame_ms / 1000.0)))
    hop = max(1, int(round(sample_rate * hop_ms / 1000.0)))
    if n_samples < frame:
        return [{"start_sample": 0, "end_sample": n_samples, "speech_score": 1.0,
                 "threshold_db": -120.0, "noise_floor_db": -120.0}]

    frames = x.unfold(0, frame, hop)
    rms = torch.sqrt(torch.mean(frames * frames, dim=1) + 1e-20)
    db = 20.0 * torch.log10(torch.clamp(rms, min=1e-12))
    q = float(noise_percentile) / 100.0
    floor = float(torch.quantile(db, q).item())
    threshold = max(floor + float(threshold_margin_db), float(absolute_floor_db))
    active = db > threshold

    # Symmetric hangover/dilation so consonants at phrase edges are not clipped.
    radius = max(0, int(round((hangover_ms / 1000.0) * sample_rate / hop)))
    if radius > 0:
        kernel = torch.ones(1, 1, radius * 2 + 1, dtype=torch.float32)
        a = active.to(torch.float32).reshape(1, 1, -1)
        active = torch.nn.functional.conv1d(a, kernel, padding=radius).reshape(-1) > 0

    raw = []
    i = 0
    m = int(active.numel())
    while i < m:
        if not bool(active[i]):
            i += 1
            continue
        j = i
        while j + 1 < m and bool(active[j + 1]):
            j += 1
        start = i * hop
        end = min(n_samples, j * hop + frame)
        raw.append([start, end])
        i = j + 1

    merge_gap = int(round(sample_rate * merge_gap_ms / 1000.0))
    merged = []
    for start, end in raw:
        if merged and start - merged[-1][1] <= merge_gap:
            merged[-1][1] = max(merged[-1][1], end)
        else:
            merged.append([start, end])

    pad = int(round(sample_rate * pad_ms / 1000.0))
    min_len = int(round(sample_rate * min_region_ms / 1000.0))
    max_len = max(1, int(round(sample_rate * max_region_seconds)))
    overlap = max(0, int(round(sample_rate * overlap_seconds)))
    if overlap >= max_len:
        overlap = max_len // 4

    out = []
    for start, end in merged:
        if end - start < min_len:
            continue
        start = max(0, start - pad)
        end = min(n_samples, end + pad)
        cur = start
        while cur < end:
            stop = min(end, cur + max_len)
            # score is frame occupancy before dilation in this window.
            fi = max(0, cur // hop)
            fj = min(int(db.numel()), max(fi + 1, (stop - frame) // hop + 1))
            if fj > fi:
                score = float(torch.mean((db[fi:fj] > threshold).to(torch.float32)).item())
            else:
                score = 0.0
            out.append({
                "start_sample": int(cur),
                "end_sample": int(stop),
                "speech_score": score,
                "threshold_db": float(threshold),
                "noise_floor_db": float(floor),
            })
            if stop >= end:
                break
            cur = max(cur + 1, stop - overlap)
    return out


def prepare_region(
    signal: torch.Tensor,
    start_sample: int,
    end_sample: int,
    sample_rate: int = 16000,
    highpass_hz: float = 80.0,
    target_rms_dbfs: float = -20.0,
    max_gain_db: float = 12.0,
    peak_limit: float = 0.95,
) -> torch.Tensor:
    """Prepare one speech region without global noise-amplifying peak normalisation."""
    x = _mono_1d(signal)
    start = max(0, int(start_sample))
    end = min(int(x.numel()), int(end_sample))
    if end <= start:
        return torch.empty((1, 0), dtype=torch.float32)
    y = x[start:end].clone()
    y = y - torch.mean(y)
    if highpass_hz and highpass_hz > 0:
        y = torchaudio.functional.highpass_biquad(y, int(sample_rate), float(highpass_hz))

    rms = torch.sqrt(torch.mean(y * y) + 1e-20)
    target = 10.0 ** (float(target_rms_dbfs) / 20.0)
    desired = target / max(float(rms.item()), 1e-12)
    max_gain = 10.0 ** (float(max_gain_db) / 20.0)
    gain = min(desired, max_gain)
    # Do not boost already-hot material; attenuation is allowed.
    y = y * float(gain)

    peak = float(torch.max(torch.abs(y)).item()) if y.numel() else 0.0
    if peak > float(peak_limit) and peak > 0:
        y = y * (float(peak_limit) / peak)
    y = torch.clamp(y, -1.0, 1.0)
    return y.reshape(1, -1).contiguous()
