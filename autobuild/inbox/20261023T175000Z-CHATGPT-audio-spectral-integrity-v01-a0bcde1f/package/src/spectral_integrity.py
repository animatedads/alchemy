"""Deterministic forensic listening views; never infers utterances or provenance.

NumPy and SoundFile are external processing backends, not evidence authorities.
All methods accept arrays in (samples, channels) form. No silent downmix.
"""
from __future__ import annotations

import argparse
import csv
import hashlib
import json
from pathlib import Path

import numpy as np

SCHEMA = "audio.spectral-integrity/0.1"


def rfft_views(pcm, rate, slot_hz=100, ceiling_hz=8000):
    """Even slot 0..100Hz, odd 100..200Hz; stereo phase retained.

    FFT rectangle-band masks introduce sinc ringing. These are listening views,
    not separation evidence. DC included in even bucket. No gain applied.
    """
    data = np.asarray(pcm, dtype=np.float64)
    if data.ndim == 1:
        data = data[:, None]
    if data.ndim != 2 or data.shape[0] < 2 or not np.isfinite(data).all():
        raise ValueError("expected finite (samples, channels) audio")
    if not (0 < slot_hz < ceiling_hz <= rate / 2):
        raise ValueError("slot/band ceiling outside Nyquist")
    spectrum = np.fft.rfft(data, axis=0)
    freqs = np.fft.rfftfreq(data.shape[0], d=1 / rate)
    active = freqs < ceiling_hz
    odd = active & ((np.floor(freqs / slot_hz).astype(int) % 2) == 1)
    even = active & ~odd
    isolated_odd = np.fft.irfft(spectrum * odd[:, None], n=data.shape[0], axis=0)
    isolated_even = np.fft.irfft(spectrum * even[:, None], n=data.shape[0], axis=0)
    return isolated_odd, isolated_even


def safe_peak_scale(pcm, limit_db=-3.0):
    """Return peak-safe PCM and scale; no independent channel normalization."""
    y = np.asarray(pcm, dtype=np.float64)
    if not np.isfinite(y).all():
        raise ValueError("nonfinite PCM")
    peak = float(np.max(np.abs(y))) if y.size else 0.0
    limit = 10.0 ** (limit_db / 20.0)
    scale = min(1.0, limit / peak) if peak else 1.0
    return y * scale, scale


def preference(odd, even, preferred="odd", relative_db=24.0):
    """Attenuate nonpreferred source relative to preferred (not a peak boost)."""
    if preferred not in {"odd", "even"} or not (0 <= relative_db <= 60):
        raise ValueError("preferred must be odd/even and relative_db 0..60")
    other_gain = 10 ** (-relative_db / 20)
    mixed = odd + other_gain * even if preferred == "odd" else even + other_gain * odd
    return safe_peak_scale(mixed)


def rms_envelope(x, rate, window_ms=10):
    """Bounded O(N) moving RMS for a channel-preserving signal."""
    y = np.asarray(x, dtype=np.float64)
    if y.ndim == 2:
        y = np.mean(y * y, axis=1)
    else:
        y = y * y
    win = max(1, int(round(rate * window_ms / 1000)))
    prefix = np.concatenate(([0.0], np.cumsum(y)))
    indices = np.arange(len(y))
    starts = np.maximum(0, indices - win // 2)
    ends = np.minimum(len(y), starts + win)
    return np.sqrt(np.maximum(0, (prefix[ends] - prefix[starts]) / np.maximum(1, ends - starts)))


def bounded_quiet_gain(x, rate, max_extra_db=14.0, window_ms=80):
    """Exploratory pass 2: a measured variable-gain listening transform.

    Gain is never evidence. Local gain may accentuate artefacts or noise.
    """
    env = rms_envelope(x, rate, window_ms=window_ms)
    positive = env[env > 1e-9]
    if not len(positive):
        return np.zeros_like(x), 1.0
    target = float(np.percentile(positive, 75))
    gain = np.clip(target / np.maximum(env, 1e-9), 1.0, 10 ** (max_extra_db / 20))
    out = np.asarray(x) * gain[:, None]
    return safe_peak_scale(out)


def sweep_bands(pcm, rate, width_hz=200, ceiling_hz=4000):
    """Return envelope-only 200-Hz candidates and neutral source views.

    The variance metric is *not* a calibrated probability of speech.
    """
    data = np.asarray(pcm, dtype=np.float64)
    if data.ndim == 1:
        data = data[:, None]
    ft = np.fft.rfft(data, axis=0)
    freqs = np.fft.rfftfreq(len(data), 1 / rate)
    for lo in range(0, ceiling_hz, width_hz):
        hi = lo + width_hz
        mask = (freqs >= lo) & (freqs < hi)
        part = np.fft.irfft(ft * mask[:, None], n=len(data), axis=0)
        env = rms_envelope(part, rate)
        yield {"lo_hz": lo, "hi_hz": hi, "envelope_variance": float(np.var(env)),
               "rms": float(np.sqrt(np.mean(part ** 2)))}, part, env


def harmonic_observations(pcm, rate, f0_hz, lo_hz=200, hi_hz=4000,
                          frame_ms=80, hop_ms=20, tolerance_hz=20):
    """Evaluate local expected-harmonic peaks given EXTERNAL f0 hypothesis.

    No f0 is inferred from the same narrow band. A missing peak is not proof
    of multiple sources. Unvoiced frames must not be interpreted as failures.
    """
    if not (50 <= f0_hz <= 500) or tolerance_hz <= 0:
        raise ValueError("f0_hz must be a sourced 50..500 Hz hypothesis")
    data = np.asarray(pcm, dtype=np.float64)
    if data.ndim == 2:
        data = data.mean(axis=1)  # measurement only; not a replacement PCM
    n = max(16, int(round(frame_ms * rate / 1000)))
    hop = max(1, int(round(hop_ms * rate / 1000)))
    window = np.hanning(n)
    f = np.fft.rfftfreq(n, 1 / rate)
    rows = []
    for start in range(0, max(0, len(data) - n + 1), hop):
        pwr = np.abs(np.fft.rfft(data[start:start + n] * window)) ** 2
        local = pwr[(f >= lo_hz) & (f <= hi_hz)]
        if local.size == 0:
            continue
        floor = float(np.median(local) + 1e-20)
        for k in range(max(1, int(np.ceil(lo_hz / f0_hz))), int(hi_hz // f0_hz) + 1):
            expected = k * f0_hz
            bins = np.abs(f - expected) <= max(tolerance_hz, rate / n)
            actual = float(pwr[bins].max()) if bins.any() else 0.0
            rows.append({"time_s": round((start + n / 2) / rate, 4),
                         "harmonic": k, "expected_hz": expected,
                         "local_peak_to_median": actual / floor})
    return rows


def _load(path):
    import soundfile as sf
    pcm, rate = sf.read(path, always_2d=True, dtype="float64")
    return pcm, rate


def _save(path, signal, rate):
    import soundfile as sf
    sf.write(path, signal, rate, subtype="PCM_24")


def run(input_path, output_dir, tail_s=20, slot_hz=100, limit_hz=8000):
    pcm, rate = _load(input_path)
    count = int(round(tail_s * rate))
    if count <= 0 or len(pcm) < count:
        raise ValueError("requested segment exceeds input duration")
    clip = pcm[-count:]
    out = Path(output_dir)
    out.mkdir(parents=True, exist_ok=True)
    odd, even = rfft_views(clip, rate, slot_hz, limit_hz)
    views = {"original": clip, "odd_only": odd, "even_only": even}
    metrics = []
    for label in ("odd", "even"):
        for db in (12, 24):
            track, scale = preference(odd, even, label, db)
            views[f"{label}_preferred_{db}db"] = track
            metrics.append({"name": f"{label}_preferred_{db}db", "peak_scale": scale})
    for name, signal in views.items():
        _save(out / f"{name}.flac", safe_peak_scale(signal)[0], rate)
    # Evidence-safe manifest excludes source path and potential identity
    source_digest = hashlib.sha256(Path(input_path).read_bytes()).hexdigest()
    manifest = {"schema": SCHEMA, "input_sha256": source_digest,
                "samples": len(clip), "channels": clip.shape[1], "rate_hz": rate,
                "source_offset_s": round((len(pcm)-len(clip)) / rate, 6),
                "slot_hz": slot_hz, "ceiling_hz": limit_hz,
                "nonpreferred_relative_attenuation_db": [12, 24],
                "metrics": metrics,
                "interpretation": "listening views only; no speech, speaker or intent attribution"}
    (out / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    return manifest


def main(argv=None):
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("input", help="locally held input audio; NEVER automatically uploaded")
    p.add_argument("output_dir")
    p.add_argument("--tail-s", type=float, default=20)
    p.add_argument("--slot-hz", type=int, default=100)
    p.add_argument("--ceiling-hz", type=int, default=8000)
    a = p.parse_args(argv)
    print(json.dumps(run(a.input, a.output_dir, a.tail_s, a.slot_hz, a.ceiling_hz), indent=2))


if __name__ == "__main__":
    main()
