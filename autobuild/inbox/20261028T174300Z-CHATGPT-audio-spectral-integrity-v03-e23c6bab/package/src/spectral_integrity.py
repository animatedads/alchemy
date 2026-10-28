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

SCHEMA = "audio.spectral-integrity/0.3"


def rfft_views(pcm, rate, slot_hz=100, ceiling_hz=8000, offset_hz=0):
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
    if not np.isfinite(offset_hz) or not (0 <= offset_hz < slot_hz):
        raise ValueError("offset_hz must be in [0, slot_hz)")
    spectrum = np.fft.rfft(data, axis=0)
    freqs = np.fft.rfftfreq(data.shape[0], d=1 / rate)
    active = freqs < ceiling_hz
    # Frequencies below the shifted origin remain in the even half bucket.
    # This makes every phase a complementary partition including DC.
    slot_index = np.floor(np.maximum(0.0, freqs - offset_hz) / slot_hz).astype(int)
    odd = active & ((slot_index % 2) == 1)
    even = active & ~odd
    isolated_odd = np.fft.irfft(spectrum * odd[:, None], n=data.shape[0], axis=0)
    isolated_even = np.fft.irfft(spectrum * even[:, None], n=data.shape[0], axis=0)
    return isolated_odd, isolated_even



def synthesize_interleaved(a, b, rate, slot_hz=100, ceiling_hz=8000, offset_hz=0):
    """Positive control: construct a two-source spectral weave with known inputs.

    A is assigned even slots, B odd slots. Identical sample/channel geometry
    is mandatory; the result makes no claim about unknown field material.
    """
    left = np.asarray(a, dtype=np.float64)
    right = np.asarray(b, dtype=np.float64)
    if left.ndim != 2 or right.shape != left.shape:
        raise ValueError("A and B must share 2D sample/channel geometry")
    _, a_even = rfft_views(left, rate, slot_hz, ceiling_hz, offset_hz)
    b_odd, _ = rfft_views(right, rate, slot_hz, ceiling_hz, offset_hz)
    return a_even + b_odd


def bucket_phase_sweep(pcm, rate, slot_hz=100, ceiling_hz=8000,
                       offsets_hz=(0, 25, 50, 75)):
    """Quantify 100 Hz mask-boundary sensitivity without assigning speech labels.

    Each row is a power fraction in the selected passband and an identity
    residual. Fractions depend on window boundaries and do not indicate voices.
    """
    y = np.asarray(pcm, dtype=np.float64)
    if y.ndim == 1:
        y = y[:, None]
    spectrum = np.fft.rfft(y, axis=0)
    freqs = np.fft.rfftfreq(len(y), d=1 / rate)
    passband = np.fft.irfft(spectrum * (freqs < ceiling_hz)[:, None], n=len(y), axis=0)
    total_power = float(np.sum(passband ** 2))
    rows = []
    for offset in offsets_hz:
        odd, even = rfft_views(y, rate, slot_hz, ceiling_hz, offset)
        odd_power = float(np.sum(odd ** 2))
        even_power = float(np.sum(even ** 2))
        residual = float(np.max(np.abs(odd + even - passband)))
        rows.append({"offset_hz": float(offset),
                     "odd_power_fraction": odd_power / total_power if total_power > 0 else 0.,
                     "even_power_fraction": even_power / total_power if total_power > 0 else 0.,
                     "reconstruction_max_abs_error": residual})
    return rows

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
    out = np.asarray(x) * (gain[:, None] if np.asarray(x).ndim == 2 else gain)
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



def windowed_bucket_views(pcm, rate, slot_hz=100, ceiling_hz=8000,
                          offset_hz=0, frame_samples=4096, hop_samples=None):
    """Windowed STFT complementary views, with local (not circular) ringing.

    Periodic sqrt-Hann WOLA with explicit zero padding. Every original sample
    has strictly positive accumulated window^2 weight; odd+even reconstructs
    the corresponding STFT-bandlimited signal, not an unfiltered source.
    This is a different listening method from full-clip FFT buckets.
    """
    x = np.asarray(pcm, dtype=np.float64)
    if x.ndim == 1:
        x = x[:, None]
    if x.ndim != 2 or len(x) < 2 or not np.isfinite(x).all():
        raise ValueError("finite (samples, channels) audio required")
    if not (0 < slot_hz < ceiling_hz <= rate / 2) or not np.isfinite(offset_hz) or not (0 <= offset_hz < slot_hz):
        raise ValueError("invalid frequency geometry")
    n = int(frame_samples)
    hop = n // 4 if hop_samples is None else int(hop_samples)
    if n < 64 or n % 2 or hop < 1 or hop > n // 2:
        raise ValueError("frame must be even >=64 and hop <= half frame")
    pad = n
    padded = np.pad(x, ((pad, pad+n), (0, 0)))
    win = np.sqrt(np.maximum(0.0, np.hanning(n+1)[:-1]))
    freq = np.fft.rfftfreq(n, d=1/rate)
    # At the exact Nyquist ceiling, retain the Nyquist bin to permit
    # perfect full-band WOLA reconstruction; otherwise ceiling is exclusive.
    active = (freq < ceiling_hz) | ((ceiling_hz == rate / 2) & (freq == rate / 2))
    slot = np.floor(np.maximum(0, freq - offset_hz) / slot_hz).astype(np.int64)
    odd_mask = (active & ((slot % 2) == 1))[:, None]
    even_mask = (active & ~((slot % 2) == 1))[:, None]
    out_odd = np.zeros_like(padded)
    out_even = np.zeros_like(padded)
    weight = np.zeros((len(padded), 1), dtype=np.float64)
    for i in range(0, len(padded) - n + 1, hop):
        frame = padded[i:i+n] * win[:, None]
        ft = np.fft.rfft(frame, axis=0)
        a = np.fft.irfft(ft * odd_mask, n=n, axis=0) * win[:, None]
        b = np.fft.irfft(ft * even_mask, n=n, axis=0) * win[:, None]
        out_odd[i:i+n] += a
        out_even[i:i+n] += b
        weight[i:i+n] += win[:, None] ** 2
    region = slice(pad, pad + len(x))
    denom = weight[region]
    if np.any(denom <= 0):
        raise RuntimeError("window overlap failed to cover source")
    return out_odd[region] / denom, out_even[region] / denom


def oracle_template_projection(mixture, source_a, source_b, rate,
                               slot_hz=100, ceiling_hz=8000, offset_hz=0):
    """Known-source experimental control: fit A/B coefficients per parity.

    This is NOT an unknown-source detector. Both exact source PCM references
    are mandatory; unknown natural audio cannot supply those references.
    Returns per-bucket aggregate least-squares coefficients and relative fit
    error, with real and imaginary FFT parts participating equally.
    """
    x = np.asarray(mixture, dtype=np.float64)
    a = np.asarray(source_a, dtype=np.float64)
    b = np.asarray(source_b, dtype=np.float64)
    if x.ndim != 2 or x.shape != a.shape or x.shape != b.shape or len(x) < 64:
        raise ValueError("oracle requires three equal-geometry 2D PCM sources")
    if not np.isfinite(x).all() or not np.isfinite(a).all() or not np.isfinite(b).all():
        raise ValueError("nonfinite source")
    if not (0 < slot_hz < ceiling_hz <= rate/2) or not (0 <= offset_hz < slot_hz):
        raise ValueError("invalid frequency geometry")
    f = np.fft.rfftfreq(len(x), d=1/rate)
    slot = np.floor(np.maximum(0, f-offset_hz)/slot_hz).astype(np.int64)
    fx, fa, fb = (np.fft.rfft(y, axis=0) for y in (x,a,b))
    rows = []
    for parity in ("even", "odd"):
        mask = (f < ceiling_hz) & (slot % 2 == (1 if parity == "odd" else 0))
        if not np.any(mask):
            raise ValueError("no bins in parity region")
        X, A, B = fx[mask].ravel(), fa[mask].ravel(), fb[mask].ravel()
        design = np.column_stack([np.r_[A.real,A.imag], np.r_[B.real,B.imag]])
        response = np.r_[X.real,X.imag]
        coeff, _, rank, _ = np.linalg.lstsq(design, response, rcond=None)
        residual = float(np.linalg.norm(response - design @ coeff) / max(np.linalg.norm(response),1e-12))
        rows.append({"bucket": parity, "source_a_coefficient": float(coeff[0]),
                     "source_b_coefficient": float(coeff[1]),
                     "relative_fit_residual": residual, "design_rank": int(rank)})
    return rows


def control_examples(a, b, rate, slot_hz=100, ceiling_hz=8000, offset_hz=0):
    """Provenance-controlled negative/positive family, never a field claim.

    Single/notched A, natural concurrent A+B, and deliberately woven A/B.
    Identical timing and geometry; callers must handle level matching separately.
    """
    aa = np.asarray(a, dtype=np.float64)
    bb = np.asarray(b, dtype=np.float64)
    if aa.ndim != 2 or aa.shape != bb.shape or not np.isfinite(aa).all() or not np.isfinite(bb).all():
        raise ValueError("two equal, finite stereo or mono-2D references required")
    _, even_a = rfft_views(aa, rate, slot_hz, ceiling_hz, offset_hz)
    return {
        "single_a": aa.copy(),
        "notched_single_a": even_a,
        "ordinary_overlay": aa + bb,
        "engineered_weave": synthesize_interleaved(aa,bb,rate,slot_hz,ceiling_hz,offset_hz),
    }


def blind_control_codes(conditions, seed=7301):
    """Deterministic blinded presentation labels; return private key separately.

    Keep the returned mapping private until listening decisions are recorded.
    It does not provide encryption or secure allocation of human participants.
    """
    from random import Random
    keys = list(conditions)
    if not keys or len(set(keys)) != len(keys):
        raise ValueError("nonempty unique conditions required")
    ids = list(range(len(keys)))
    Random(seed).shuffle(ids)
    return {"T%03d" % idx: keys[i] for idx, i in zip(ids,range(len(keys)))}

def _load(path):
    import soundfile as sf
    pcm, rate = sf.read(path, always_2d=True, dtype="float64")
    return pcm, rate


def _save(path, signal, rate):
    import soundfile as sf
    sf.write(path, signal, rate, subtype="PCM_24")


def run(input_path, output_dir, tail_s=20, slot_hz=100, limit_hz=8000,
        offsets_hz=(0, 25, 50, 75)):
    pcm, rate = _load(input_path)
    count = int(round(tail_s * rate))
    if count <= 0 or len(pcm) < count:
        raise ValueError("requested segment exceeds input duration")
    clip = pcm[-count:]
    out = Path(output_dir)
    out.mkdir(parents=True, exist_ok=True)
    odd, even = rfft_views(clip, rate, slot_hz, limit_hz)
    phase_rows = bucket_phase_sweep(clip, rate, slot_hz, limit_hz, offsets_hz)
    with (out / "phase_sensitivity.csv").open("w", newline="") as fh:
        w = csv.DictWriter(fh, fieldnames=list(phase_rows[0].keys()))
        w.writeheader()
        w.writerows(phase_rows)
    views = {"original": clip, "odd_only": odd, "even_only": even}
    metrics = []
    for label in ("odd", "even"):
        for db in (12, 24):
            track, scale = preference(odd, even, label, db)
            views[f"{label}_preferred_{db}db"] = track
            metrics.append({"name": f"{label}_preferred_{db}db", "peak_scale": scale})
    # Export additional preferred views at shifted bucket origins for blind review.
    if not offsets_hz:
        raise ValueError("at least one phase offset is required")
    for offset in offsets_hz:
        if float(offset) == 0:
            continue
        shifted_odd, shifted_even = rfft_views(clip, rate, slot_hz, limit_hz, offset)
        for pref in ("odd", "even"):
            val, _ = preference(shifted_odd, shifted_even, pref, 24)
            offset_tag = f"{float(offset):g}".replace(".", "p")
            views[f"offset_{offset_tag}hz_{pref}_preferred_24db"] = val
    for name, signal in views.items():
        _save(out / f"{name}.flac", safe_peak_scale(signal)[0], rate)
    # Evidence-safe manifest excludes source path and potential identity
    source_digest = hashlib.sha256(Path(input_path).read_bytes()).hexdigest()
    manifest = {"schema": SCHEMA, "input_sha256": source_digest,
                "samples": len(clip), "channels": clip.shape[1], "rate_hz": rate,
                "source_offset_s": round((len(pcm)-len(clip)) / rate, 6),
                "slot_hz": slot_hz, "ceiling_hz": limit_hz,
                "phase_offsets_hz": [float(v) for v in offsets_hz],
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
    p.add_argument("--offsets-hz", default="0,25,50,75",
                   help="comma separated bucket origins (Hz) for phase sensitivity")
    a = p.parse_args(argv)
    offsets = tuple(float(s.strip()) for s in a.offsets_hz.split(","))
    if not offsets:
        raise ValueError("at least one offset required")
    print(json.dumps(run(a.input, a.output_dir, a.tail_s, a.slot_hz, a.ceiling_hz, offsets), indent=2))


if __name__ == "__main__":
    main()
