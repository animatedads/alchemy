"""Reference audio-processing implementations distilled from pyaudprocessing.

The public functions are intentionally regular and free of project/timeline I/O.
They consume NumPy-compatible arrays or ForeignBuffer memoryviews and return
plain tuples/NumPy arrays suitable for ForeignPython proxy traversal.

These are reference implementations, not declarations that one algorithm is
preferred for every recording.
"""
from __future__ import annotations

import math
from typing import Any, Iterable, Mapping

import numpy as np
from scipy import ndimage, signal

try:
    import librosa
except Exception:  # pragma: no cover - provider reports unavailable at runtime
    librosa = None



class _SequenceBox:
    """Keep composite Python results resident so ndarray children are not eagerly Rexxified."""
    def __init__(self, items):
        self._items = tuple(items)
    def __len__(self):
        return len(self._items)
    def __getitem__(self, index):
        return self._items[index]

def _f32_1d(x: Any) -> np.ndarray:
    if isinstance(x, memoryview):
        a = np.frombuffer(x, dtype="<f4")
    else:
        a = np.asarray(x, dtype=np.float32)
    return np.nan_to_num(a.reshape(-1), nan=0.0, posinf=0.0, neginf=0.0)


def _pair(a: Any, b: Any) -> tuple[np.ndarray, np.ndarray]:
    aa, bb = _f32_1d(a), _f32_1d(b)
    n = min(aa.size, bb.size)
    return aa[:n], bb[:n]


def _need_librosa() -> None:
    if librosa is None:
        raise RuntimeError("librosa is unavailable")


def _stft(x: np.ndarray, n_fft: int, hop: int) -> np.ndarray:
    _need_librosa()
    return librosa.stft(x, n_fft=n_fft, hop_length=hop)


def _istft(X: np.ndarray, hop: int, length: int) -> np.ndarray:
    _need_librosa()
    return np.asarray(librosa.istft(X, hop_length=hop, length=length), dtype=np.float32)


def runtime_info() -> tuple[str, str, str, str]:
    return (
        "audio_processing_foreign/0.21",
        np.__version__,
        getattr(signal, "__module__", "scipy.signal").split(".")[0],
        getattr(librosa, "__version__", "unavailable") if librosa is not None else "unavailable",
    )


def channel_statistics(a: Any, b: Any | None = None) -> tuple:
    aa = _f32_1d(a)
    rms_a = float(np.sqrt(np.mean(aa * aa))) if aa.size else 0.0
    peak_a = float(np.max(np.abs(aa))) if aa.size else 0.0
    if b is None:
        return ("ok", int(aa.size), rms_a, peak_a)
    aa, bb = _pair(aa, b)
    rms_b = float(np.sqrt(np.mean(bb * bb))) if bb.size else 0.0
    peak_b = float(np.max(np.abs(bb))) if bb.size else 0.0
    if aa.size < 2 or np.std(aa) == 0 or np.std(bb) == 0:
        corr = 0.0
    else:
        corr = float(np.corrcoef(aa, bb)[0, 1])
    return ("ok", int(aa.size), rms_a, peak_a, rms_b, peak_b, corr)


def gcc_phat(a: Any, b: Any, sample_rate: int, max_lag_sec: float = 0.2) -> tuple:
    aa, bb = _pair(a, b)
    if aa.size == 0:
        return ("ok", 0, 0.0, 0.0, 0.0)
    aa = aa - aa.mean()
    bb = bb - bb.mean()
    if not np.any(aa) or not np.any(bb):
        return ("ok", 0, 0.0, 0.0, 0.0)
    nfft = 1 << int(np.ceil(np.log2(max(2, aa.size + bb.size - 1))))
    A = np.fft.rfft(aa, nfft)
    B = np.fft.rfft(bb, nfft)
    R = A * np.conj(B)
    cc = np.fft.irfft(R / (np.abs(R) + 1e-10), nfft)
    max_lag = max(1, min(int(float(max_lag_sec) * int(sample_rate)), aa.size - 1))
    search = np.concatenate([cc[-max_lag:], cc[: max_lag + 1]])
    abs_search = np.abs(search)
    idx = int(np.argmax(abs_search))
    lag = idx - max_lag
    peak = float(abs_search[idx])
    med = float(np.median(abs_search) + 1e-12)
    confidence = peak / med
    return ("ok", lag, float(lag / sample_rate), float(lag / sample_rate * 1000.0), confidence)


def envelope_lag(a: Any, b: Any, sample_rate: int, max_lag_sec: float = 0.2, smoothing_sec: float = 0.015) -> tuple:
    aa, bb = _pair(a, b)
    if aa.size == 0:
        return ("ok", 0, 0.0, 0.0, 0.0)
    ea = np.abs(signal.hilbert(aa))
    eb = np.abs(signal.hilbert(bb))
    kernel = max(5, int(float(smoothing_sec) * int(sample_rate)) | 1)
    if kernel >= aa.size:
        kernel = max(3, (aa.size // 2) * 2 - 1)
    if kernel >= 3:
        ea = signal.medfilt(ea, kernel_size=kernel)
        eb = signal.medfilt(eb, kernel_size=kernel)
    ea = (ea - ea.mean()) / (ea.std() + 1e-9)
    eb = (eb - eb.mean()) / (eb.std() + 1e-9)
    corr = signal.correlate(ea, eb, mode="full")
    lags = np.arange(-len(eb) + 1, len(ea))
    mask = np.abs(lags) <= int(float(max_lag_sec) * int(sample_rate))
    sub, sub_lags = corr[mask], lags[mask]
    idx = int(np.argmax(sub))
    lag = int(sub_lags[idx])
    score = float(sub[idx] / max(1, aa.size))
    return ("ok", lag, float(lag / sample_rate), float(lag / sample_rate * 1000.0), score)


def cross_ambiguity_lag(a: Any, b: Any, sample_rate: int, max_delay_sec: float = 0.2) -> tuple:
    aa, bb = _pair(a, b)
    max_lag = max(1, min(int(float(max_delay_sec) * int(sample_rate)), max(1, aa.size - 1)))
    corr = signal.correlate(aa, bb, mode="full")
    lags = signal.correlation_lags(aa.size, bb.size, mode="full")
    mask = (lags >= -max_lag) & (lags <= max_lag)
    if not np.any(mask):
        return ("ok", 0, 0.0, 0.0)
    view = np.abs(corr[mask])
    lag = int(lags[mask][int(np.argmax(view))])
    peak = float(np.max(view))
    return ("ok", lag, float(lag / sample_rate), peak)


def adaptive_spectral_denoise(x: Any, sample_rate: int, n_fft: int = 2048, hop: int = 512,
                              noise_percentile: float = 20.0, floor_scale: float = 1.2,
                              minimum_gain: float = 0.08) -> np.ndarray:
    y = _f32_1d(x)
    if y.size == 0:
        return y
    S = _stft(y, int(n_fft), int(hop))
    mag, phase = np.abs(S), np.exp(1j * np.angle(S))
    frame_rms = np.sqrt(np.mean(mag * mag, axis=0))
    threshold = np.percentile(frame_rms, float(noise_percentile))
    idx = np.where(frame_rms <= threshold)[0]
    floor = mag[:, idx].mean(axis=1, keepdims=True) if idx.size else np.median(mag, axis=1, keepdims=True) * 0.25
    clean = np.maximum(mag - floor * float(floor_scale), mag * float(minimum_gain))
    return _istft(clean * phase, int(hop), y.size)


def phase_coherence_wiener(a: Any, b: Any, sample_rate: int, n_fft: int = 2048, hop: int = 512,
                           smoothing_frames: int = 5, floor_gain: float = 0.06,
                           noise_ratio: float = 8.0) -> tuple:
    aa, bb = _pair(a, b)
    Sa, Sb = _stft(aa, int(n_fft), int(hop)), _stft(bb, int(n_fft), int(hop))
    size = max(1, int(smoothing_frames))
    cross = ndimage.uniform_filter1d((Sa * np.conj(Sb)).real, size=size, axis=1) + 1j * ndimage.uniform_filter1d((Sa * np.conj(Sb)).imag, size=size, axis=1)
    pa = ndimage.uniform_filter1d(np.abs(Sa) ** 2, size=size, axis=1)
    pb = ndimage.uniform_filter1d(np.abs(Sb) ** 2, size=size, axis=1)
    coh = np.abs(cross) / (np.sqrt(np.abs(pa * pb)) + 1e-10)
    c2 = np.clip(coh, 0.0, 1.0) ** 2
    G = c2 / (c2 + (1.0 - c2) / float(noise_ratio) + 1e-12)
    G = np.clip(np.nan_to_num(G), float(floor_gain), 1.0).astype(np.float32)
    ao = _istft(Sa * G, int(hop), aa.size)
    bo = _istft(Sb * G, int(hop), bb.size)
    return _SequenceBox((ao, bo, G))


def mvdr_dual(a: Any, b: Any, sample_rate: int, n_fft: int = 2048, hop: int = 512,
              diagonal_loading: float = 1e-4) -> np.ndarray:
    aa, bb = _pair(a, b)
    Sa, Sb = _stft(aa, int(n_fft), int(hop)), _stft(bb, int(n_fft), int(hop))
    X = np.stack([Sa, Sb], axis=0)
    n_frames = max(1, X.shape[2])
    R = np.einsum("ift,jft->fij", X, X.conj()) / n_frames
    d = np.array([1.0, 1.0], dtype=np.complex128) / np.sqrt(2.0)
    eye = np.eye(2, dtype=np.complex128)
    out = np.zeros_like(Sa)
    for k in range(R.shape[0]):
        diag = float(diagonal_loading) * float((abs(R[k, 0, 0]) + abs(R[k, 1, 1])) / 2.0)
        Rk = R[k] + eye * max(diag, 1e-12)
        try:
            ri = np.linalg.inv(Rk)
            rid = ri @ d
            w = rid / (d.conj() @ rid + 1e-10)
            out[k] = w.conj() @ X[:, k, :]
        except np.linalg.LinAlgError:
            out[k] = Sa[k]
    return _istft(out, int(hop), aa.size)


def clean_spectral_lines(x: Any, sample_rate: int, n_fft: int = 2048, hop: int = 512,
                         iterations: int = 8, gain: float = 0.5, beam_width_bins: float = 2.5,
                         minimum_gain: float = 0.05) -> tuple:
    y = _f32_1d(x)
    S = _stft(y, int(n_fft), int(hop))
    mag, phase = np.abs(S), np.exp(1j * np.angle(S))
    dirty = mag.mean(axis=1)
    residual = dirty.copy()
    removed = np.zeros_like(dirty)
    bins = np.arange(dirty.size)
    for _ in range(max(0, int(iterations))):
        idx = int(np.argmax(residual))
        peak = float(residual[idx])
        if peak < 1e-8:
            break
        beam = peak * np.exp(-0.5 * ((bins - idx) / float(beam_width_bins)) ** 2)
        residual = np.maximum(residual - float(gain) * beam, 0.0)
        removed += float(gain) * beam
    suppression = np.clip(1.0 - removed / (dirty + 1e-10), float(minimum_gain), 1.0).astype(np.float32)
    out = _istft(mag * suppression[:, None] * phase, int(hop), y.size)
    return _SequenceBox((out, suppression))


def echo_persistence(x: Any, sample_rate: int, n_fft: int = 2048, hop: int = 512,
                     delay_min_ms: float = 10.0, delay_max_ms: float = 120.0,
                     delay_step_ms: float = 10.0, normalization_sec: float = 2.0,
                     threshold: float = 0.4, slope: float = 8.0) -> tuple:
    y = _f32_1d(x)
    if y.size < int(n_fft):
        return (y.copy(), np.ones((int(n_fft) // 2 + 1, 1), dtype=np.float32))
    S = _stft(y, int(n_fft), int(hop))
    mag, phase = np.abs(S), np.exp(1j * np.angle(S))
    delays_ms = np.arange(float(delay_min_ms), float(delay_max_ms) + 1e-9, float(delay_step_ms))
    delays = (delays_ms / 1000.0 * int(sample_rate) / int(hop)).astype(int)
    delays = delays[delays > 0]
    score = np.zeros_like(mag)
    for d in delays:
        if d >= mag.shape[1]:
            continue
        shifted = np.pad(mag[:, :-d], ((0, 0), (d, 0)), mode="constant")
        score += np.sqrt(mag * shifted)
    score /= max(1, len(delays))
    win = max(1, int((sample_rate / hop) * float(normalization_sec)))
    local = ndimage.uniform_filter1d(score, size=win, axis=1) + 1e-9
    norm = score / local
    mask = 1.0 / (1.0 + np.exp(-float(slope) * (norm - float(threshold))))
    mask = ndimage.uniform_filter1d(mask, size=3, axis=1).astype(np.float32)
    return _SequenceBox((_istft(mag * mask * phase, int(hop), y.size), mask))


def eigen_noise_projection(a: Any, b: Any, sample_rate: int, n_fft: int = 2048, hop: int = 512,
                           regularization: float = 1e-7) -> tuple:
    aa, bb = _pair(a, b)
    Sa, Sb = _stft(aa, int(n_fft), int(hop)), _stft(bb, int(n_fft), int(hop))
    ca, cb = np.zeros_like(Sa), np.zeros_like(Sb)
    n_frames = max(1, Sa.shape[1])
    for f in range(Sa.shape[0]):
        X = np.vstack([Sa[f], Sb[f]])
        R = (X @ np.conj(X.T)) / n_frames + np.eye(2) * float(regularization)
        try:
            vals, vecs = np.linalg.eigh(R)
            noise_vec = vecs[:, -1:]
            P = np.eye(2) - noise_vec @ np.conj(noise_vec.T)
            clean = P @ X
            ca[f], cb[f] = clean[0], clean[1]
        except np.linalg.LinAlgError:
            ca[f], cb[f] = Sa[f], Sb[f]
    return _SequenceBox((_istft(ca, int(hop), aa.size), _istft(cb, int(hop), bb.size)))


def syllabic_modulation_score(x: Any, sample_rate: int, n_fft: int = 2048, hop: int = 512,
                              low_hz: float = 2.0, high_hz: float = 8.0) -> tuple:
    y = _f32_1d(x)
    S = _stft(y, int(n_fft), int(hop))
    mag = np.abs(S)
    env = np.mean(mag, axis=0)
    frame_rate = float(sample_rate) / float(hop)
    nyq = 0.5 * frame_rate
    if nyq <= float(high_hz) or env.size < 16:
        return (0.0, np.ones(env.shape, dtype=np.float32))
    sos = signal.butter(2, [float(low_hz) / nyq, float(high_hz) / nyq], btype="band", output="sos")
    mod = signal.sosfiltfilt(sos, env)
    denom = float(np.max(np.abs(mod)) + 1e-9)
    weights = np.clip(np.abs(mod) / denom, 0.0, 1.0).astype(np.float32)
    return _SequenceBox((float(np.mean(weights)), weights))



def room_profile(x: Any, sample_rate: int, hop: int = 512, min_delay_ms: float = 10.0,
                 max_delay_ms: float = 150.0, max_reflections: int = 6,
                 prominence_ratio: float = 0.05) -> _SequenceBox:
    """Blind transient/reflection profile distilled from dual_feed_enhance_v5.

    Returns (delays_ms ndarray, peak_strengths ndarray, confidence).  It is an
    acoustic measurement, not a claim about literal room dimensions.
    """
    y = _f32_1d(x)
    _need_librosa()
    if y.size < max(32, int(hop) * 2):
        return _SequenceBox((np.asarray([], dtype=np.float32), np.asarray([], dtype=np.float32), 0.0))
    onset = librosa.onset.onset_strength(y=y, sr=int(sample_rate), hop_length=int(hop))
    if onset.size < 3 or not np.any(np.isfinite(onset)) or float(np.max(np.abs(onset))) <= 1e-12:
        return _SequenceBox((np.asarray([], dtype=np.float32), np.asarray([], dtype=np.float32), 0.0))
    min_frames = max(1, int(round(float(min_delay_ms) / 1000.0 * sample_rate / hop)))
    max_frames = max(min_frames + 1, int(round(float(max_delay_ms) / 1000.0 * sample_rate / hop)))
    ac = librosa.autocorrelate(onset, max_size=max_frames + 1)
    ac = np.asarray(ac, dtype=np.float64)
    ac[:min(min_frames, ac.size)] = 0.0
    mx = float(np.max(ac)) if ac.size else 0.0
    if mx <= 1e-12:
        return _SequenceBox((np.asarray([], dtype=np.float32), np.asarray([], dtype=np.float32), 0.0))
    peaks, props = signal.find_peaks(ac, distance=2, prominence=mx * float(prominence_ratio))
    peaks = peaks[(peaks >= min_frames) & (peaks <= max_frames)]
    if peaks.size == 0:
        return _SequenceBox((np.asarray([], dtype=np.float32), np.asarray([], dtype=np.float32), 0.0))
    vals = ac[peaks]
    order = np.argsort(vals)[::-1][:int(max_reflections)]
    chosen = peaks[order]
    strengths = vals[order]
    delays = chosen.astype(np.float64) * float(hop) / float(sample_rate) * 1000.0
    by_delay = np.argsort(delays)
    delays = delays[by_delay].astype(np.float32)
    strengths = (strengths[by_delay] / (mx + 1e-12)).astype(np.float32)
    confidence = float(np.clip(np.mean(strengths), 0.0, 1.0))
    return _SequenceBox((delays, strengths, confidence))


def harmonic_product_measurement(x: Any, sample_rate: int, n_fft: int = 2048, hop: int = 512,
                                 harmonics: int = 3) -> _SequenceBox:
    """Harmonic-product evidence derived from the v7 research implementation."""
    y = _f32_1d(x)
    if y.size < int(n_fft):
        return _SequenceBox((0.0, np.zeros((int(n_fft)//2 + 1, 1), dtype=np.float32)))
    mag = np.abs(_stft(y, int(n_fft), int(hop))).astype(np.float64) + 1e-12
    # Work in log space to avoid the huge dynamic range of the literal product.
    log_hps = np.log(mag)
    for h in range(2, max(2, int(harmonics)) + 1):
        dec = np.log(mag[::h, :] + 1e-12)
        padded = np.full_like(log_hps, np.log(1e-12))
        padded[:dec.shape[0], :] = dec
        log_hps += padded
    hps = np.exp(np.clip(log_hps - np.max(log_hps, axis=0, keepdims=True), -40.0, 0.0)).astype(np.float32)
    # Concentration of the strongest harmonic-product bins: useful evidence, not probability.
    top = np.max(hps, axis=0)
    baseline = np.mean(hps, axis=0) + 1e-9
    score = float(np.median(top / baseline))
    return _SequenceBox((score, hps))


def spectral_tilt_measurement(x: Any, sample_rate: int, n_fft: int = 2048, hop: int = 512,
                              low_hz: float = 100.0, high_hz: float = 6000.0) -> _SequenceBox:
    """Estimate log-spectral slope in dB/octave with simple least-squares fit."""
    y = _f32_1d(x)
    if y.size < int(n_fft):
        return _SequenceBox((0.0, 0.0))
    mag = np.abs(_stft(y, int(n_fft), int(hop)))
    mean_mag = np.mean(mag, axis=1) + 1e-12
    freqs = np.fft.rfftfreq(int(n_fft), d=1.0/float(sample_rate))
    hi = min(float(high_hz), float(sample_rate) * 0.49)
    sel = (freqs >= max(1.0, float(low_hz))) & (freqs <= hi)
    if np.count_nonzero(sel) < 8:
        return _SequenceBox((0.0, 0.0))
    xx = np.log2(freqs[sel])
    yy = 20.0 * np.log10(mean_mag[sel])
    coeff = np.polyfit(xx, yy, 1)
    pred = coeff[0] * xx + coeff[1]
    ss_res = float(np.sum((yy-pred)**2))
    ss_tot = float(np.sum((yy-np.mean(yy))**2)) + 1e-12
    r2 = float(np.clip(1.0 - ss_res/ss_tot, 0.0, 1.0))
    return _SequenceBox((float(coeff[0]), r2))


def multi_domain_coherence(a: Any, b: Any, sample_rate: int, n_fft: int = 2048, hop: int = 512,
                           delay_min_ms: float = 10.0, delay_max_ms: float = 120.0,
                           delay_step_ms: float = 10.0, spatial_weight: float = 0.45,
                           wavefront_weight: float = 0.25, echo_weight: float = 0.30,
                           threshold: float = 0.35, slope: float = 12.0) -> _SequenceBox:
    """Regularised version of the v5 spatial/wavefront/echo fusion."""
    aa, bb = _pair(a, b)
    if aa.size < int(n_fft):
        return _SequenceBox((aa.copy(), np.ones((int(n_fft)//2+1, 1), dtype=np.float32)))
    Sa, Sb = _stft(aa, int(n_fft), int(hop)), _stft(bb, int(n_fft), int(hop))
    ma, mb = np.abs(Sa), np.abs(Sb)
    phase_a = np.angle(Sa)
    cps = Sa * np.conj(Sb)
    spatial = np.abs(cps) / (ma * mb + 1e-8)
    dphase = np.angle(np.exp(1j * np.diff(phase_a, axis=1)))
    dphase = np.pad(dphase, ((0,0),(1,0)), mode='edge')
    mean_dp = ndimage.uniform_filter1d(dphase, size=3, axis=1)
    var_dp = ndimage.uniform_filter1d((dphase-mean_dp)**2, size=3, axis=1)
    wave = np.exp(-3.0 * var_dp)
    delays_ms = np.arange(float(delay_min_ms), float(delay_max_ms)+1e-9, float(delay_step_ms))
    delays = (delays_ms/1000.0*int(sample_rate)/int(hop)).astype(int)
    delays = np.unique(delays[delays>0])
    echo_raw = np.zeros_like(ma)
    count = 0
    for d in delays:
        if d >= ma.shape[1]:
            continue
        shifted = np.pad(ma[:, :-d], ((0,0),(d,0)), mode='constant')
        echo_raw += np.sqrt(ma * shifted)
        count += 1
    if count:
        echo_raw /= count
    win = max(1, int((sample_rate/hop)*2.0))
    local = ndimage.uniform_filter1d(echo_raw, size=win, axis=1) + 1e-8
    echo = np.clip(echo_raw/local, 0.0, 2.0) / 2.0
    weights = np.asarray([spatial_weight, wavefront_weight, echo_weight], dtype=np.float64)
    weights = weights / max(1e-12, float(np.sum(weights)))
    fused = weights[0]*spatial + weights[1]*wave + weights[2]*echo
    mask = (1.0/(1.0+np.exp(-float(slope)*(fused-float(threshold)))))
    mask = ndimage.uniform_filter1d(mask, size=3, axis=1).astype(np.float32)
    out = _istft(Sa*mask, int(hop), aa.size)
    return _SequenceBox((out, mask))


def log_likelihood_fusion(a: Any, b: Any, sample_rate: int, n_fft: int = 2048, hop: int = 512,
                          harmonics: int = 3) -> _SequenceBox:
    """Regularised v7 harmonic/modulation/tilt two-feed fusion."""
    aa, bb = _pair(a, b)
    if aa.size < int(n_fft):
        return _SequenceBox(((aa+bb)*0.5, np.full((1,1),0.5,dtype=np.float32)))
    Sa, Sb = _stft(aa, int(n_fft), int(hop)), _stft(bb, int(n_fft), int(hop))
    def evidence(S):
        mag=np.abs(S)+1e-9
        log_hps=np.log(mag)
        for h in range(2,max(2,int(harmonics))+1):
            dec=np.log(mag[::h,:]+1e-9)
            pad=np.full_like(log_hps,np.log(1e-9)); pad[:dec.shape[0],:]=dec
            log_hps+=pad
        hps=np.exp(np.clip(log_hps-np.max(log_hps,axis=0,keepdims=True),-30,0))
        env=np.mean(mag,axis=0)
        frame_rate=float(sample_rate)/float(hop)
        nyq=0.5*frame_rate
        if nyq>8 and env.size>16:
            sos=signal.butter(2,[2.0/nyq,8.0/nyq],btype='band',output='sos')
            mod=np.abs(signal.sosfiltfilt(sos,env)); mod=mod/(np.max(mod)+1e-9)
        else:
            mod=np.ones_like(env)
        freqs=np.fft.rfftfreq(int(n_fft),d=1.0/float(sample_rate))
        tilt=1.0/np.log1p(freqs+1e-6)
        tilt=tilt/(np.max(tilt)+1e-9)
        return np.log1p(hps)+np.log1p(mod[None,:])+np.log1p(tilt[:,None])
    wa, wb = evidence(Sa), evidence(Sb)
    denom = wa+wb+1e-9
    mask_a=(wa/denom).astype(np.float32)
    fused_mag=np.abs(Sa)*mask_a + np.abs(Sb)*(1.0-mask_a)
    phase=np.where(mask_a>0.5,np.angle(Sa),np.angle(Sb))
    out=_istft(fused_mag*np.exp(1j*phase),int(hop),aa.size)
    return _SequenceBox((out, mask_a))

def processor_ids() -> tuple[str, ...]:
    return (
        "alignment.gcc_phat",
        "alignment.envelope_lag",
        "alignment.cross_ambiguity",
        "transform.adaptive_spectral_denoise",
        "mask.phase_coherence_wiener",
        "transform.mvdr.dual",
        "transform.clean_spectral_lines",
        "mask.echo_persistence",
        "transform.eigen_noise_projection",
        "mask.syllabic_modulation",
        "measurement.room_profile",
        "measurement.harmonic_product",
        "measurement.spectral_tilt",
        "mask.coherence.multi_domain",
        "transform.log_likelihood_fusion",
    )

# ---------------------------------------------------------------------------
# Stateful streaming reference processors (v0.21)
# ---------------------------------------------------------------------------

class AdaptiveSpectralDenoiseStream:
    """Incremental spectral denoiser with persistent floor/history state.

    This is deliberately a reference implementation.  The persistent state is
    the learned per-bin noise floor plus a short input history used to reduce
    block-boundary discontinuities.  The session emits exactly one output sample
    for every newly supplied input sample.
    """
    def __init__(self, sample_rate: int, n_fft: int = 2048, hop: int = 512,
                 noise_percentile: float = 20.0, floor_scale: float = 1.2,
                 minimum_gain: float = 0.08, state_alpha: float = 0.85):
        self.sample_rate = int(sample_rate)
        self.n_fft = int(n_fft)
        self.hop = int(hop)
        self.noise_percentile = float(noise_percentile)
        self.floor_scale = float(floor_scale)
        self.minimum_gain = float(minimum_gain)
        self.state_alpha = float(np.clip(state_alpha, 0.0, 0.999999))
        self.history_len = max(0, self.n_fft - self.hop)
        self.history = np.zeros(0, dtype=np.float32)
        self.noise_floor = None
        self.blocks = 0
        self.samples = 0

    def process(self, x: Any) -> np.ndarray:
        block = _f32_1d(x)
        if block.size == 0:
            return block.copy()
        prefix = self.history
        joined = np.concatenate([prefix, block]) if prefix.size else block.copy()
        S = _stft(joined, self.n_fft, self.hop)
        mag, phase = np.abs(S), np.exp(1j * np.angle(S))
        frame_rms = np.sqrt(np.mean(mag * mag, axis=0))
        threshold = np.percentile(frame_rms, self.noise_percentile)
        idx = np.where(frame_rms <= threshold)[0]
        observed = (mag[:, idx].mean(axis=1, keepdims=True) if idx.size
                    else np.median(mag, axis=1, keepdims=True) * 0.25)
        if self.noise_floor is None:
            self.noise_floor = observed.astype(np.float64, copy=True)
        else:
            self.noise_floor = self.state_alpha * self.noise_floor + (1.0 - self.state_alpha) * observed
        clean = np.maximum(mag - self.noise_floor * self.floor_scale,
                           mag * self.minimum_gain)
        rendered = _istft(clean * phase, self.hop, joined.size)
        out = rendered[-block.size:].astype(np.float32, copy=False)
        if self.history_len:
            self.history = joined[-self.history_len:].astype(np.float32, copy=True)
        self.blocks += 1
        self.samples += int(block.size)
        return out

    def state_summary(self) -> _SequenceBox:
        floor_mean = float(np.mean(self.noise_floor)) if self.noise_floor is not None else 0.0
        floor_peak = float(np.max(self.noise_floor)) if self.noise_floor is not None else 0.0
        return _SequenceBox((self.blocks, self.samples, int(self.history.size), floor_mean, floor_peak))

    def flush(self) -> np.ndarray:
        # This reference path has no deferred output samples.  Flush remains an
        # explicit lifecycle operation because other processors may need it.
        return np.zeros(0, dtype=np.float32)


class EchoPersistenceStream:
    """Incremental echo-persistence processor with bounded delay history."""
    def __init__(self, sample_rate: int, n_fft: int = 2048, hop: int = 512,
                 delay_min_ms: float = 10.0, delay_max_ms: float = 120.0,
                 delay_step_ms: float = 10.0, normalization_sec: float = 2.0,
                 threshold: float = 0.4, slope: float = 8.0):
        self.sample_rate = int(sample_rate)
        self.n_fft = int(n_fft)
        self.hop = int(hop)
        self.delay_min_ms = float(delay_min_ms)
        self.delay_max_ms = float(delay_max_ms)
        self.delay_step_ms = float(delay_step_ms)
        self.normalization_sec = float(normalization_sec)
        self.threshold = float(threshold)
        self.slope = float(slope)
        max_delay_samples = int(math.ceil(self.delay_max_ms / 1000.0 * self.sample_rate))
        self.history_len = max(self.n_fft, max_delay_samples + self.n_fft)
        self.history = np.zeros(0, dtype=np.float32)
        self.blocks = 0
        self.samples = 0

    def process(self, x: Any) -> _SequenceBox:
        block = _f32_1d(x)
        if block.size == 0:
            return _SequenceBox((block.copy(), np.ones((self.n_fft // 2 + 1, 1), dtype=np.float32)))
        prefix = self.history
        joined = np.concatenate([prefix, block]) if prefix.size else block.copy()
        audio, mask = echo_persistence(joined, self.sample_rate, self.n_fft, self.hop,
                                       self.delay_min_ms, self.delay_max_ms,
                                       self.delay_step_ms, self.normalization_sec,
                                       self.threshold, self.slope)
        out = np.asarray(audio[-block.size:], dtype=np.float32)
        self.history = joined[-self.history_len:].astype(np.float32, copy=True)
        self.blocks += 1
        self.samples += int(block.size)
        # Mask is evidence for this processing invocation; retaining the complete
        # context mask is intentional and its geometry is reported by the output.
        return _SequenceBox((out, np.asarray(mask, dtype=np.float32)))

    def state_summary(self) -> _SequenceBox:
        return _SequenceBox((self.blocks, self.samples, int(self.history.size), self.delay_max_ms))

    def flush(self) -> np.ndarray:
        return np.zeros(0, dtype=np.float32)


def make_adaptive_spectral_denoise_stream(sample_rate: int, n_fft: int = 2048, hop: int = 512,
                                           noise_percentile: float = 20.0, floor_scale: float = 1.2,
                                           minimum_gain: float = 0.08, state_alpha: float = 0.85):
    return AdaptiveSpectralDenoiseStream(sample_rate, n_fft, hop, noise_percentile,
                                         floor_scale, minimum_gain, state_alpha)


def make_echo_persistence_stream(sample_rate: int, n_fft: int = 2048, hop: int = 512,
                                 delay_min_ms: float = 10.0, delay_max_ms: float = 120.0,
                                 delay_step_ms: float = 10.0, normalization_sec: float = 2.0,
                                 threshold: float = 0.4, slope: float = 8.0):
    return EchoPersistenceStream(sample_rate, n_fft, hop, delay_min_ms, delay_max_ms,
                                 delay_step_ms, normalization_sec, threshold, slope)

class DynamicFilterStream:
    """Stateful time-scoped IIR filtering distilled from the v8 research code.

    The ooRexx layer decides which rules are active for each source-time block.
    This object owns only numerical filter state (zi) for the currently active
    rule set, so rules remain semantic Audio objects rather than Python policy.
    """
    def __init__(self, sample_rate: int, max_filters_per_block: int = 4):
        self.sample_rate = int(sample_rate)
        self.max_filters_per_block = max(1, int(max_filters_per_block))
        self.states = {}
        self.blocks = 0
        self.samples = 0
        self.last_active = 0

    def _design(self, rule):
        action = str(rule.get("action", "")).strip().upper()
        freq = float(rule.get("frequency_hz", 0.0))
        q = float(rule.get("q", 30.0))
        order = max(1, int(rule.get("order", 4)))
        nyq = self.sample_rate / 2.0
        if action == "NOTCH":
            if not (0.0 < freq < nyq):
                return None
            q = float(np.clip(q, 1.0, 200.0))
            b, a = signal.iirnotch(freq, q, self.sample_rate)
        elif action == "HIGHPASS":
            if not (0.0 < freq < nyq):
                return None
            b, a = signal.butter(order, freq / nyq, btype="high")
        elif action == "LOWPASS":
            if not (0.0 < freq < nyq):
                return None
            b, a = signal.butter(order, freq / nyq, btype="low")
        else:
            return None
        key = (action, round(freq, 9), round(q, 9), order)
        return key, np.asarray(b, dtype=np.float64), np.asarray(a, dtype=np.float64)

    def process(self, x: Any, rules: Any) -> np.ndarray:
        y = _f32_1d(x).astype(np.float64, copy=True)
        active_keys = set()
        applied = 0
        for raw in list(rules)[:self.max_filters_per_block]:
            designed = self._design(raw)
            if designed is None:
                continue
            key, b, a = designed
            active_keys.add(key)
            zi = self.states.get(key)
            if zi is None or len(zi) != max(len(a), len(b)) - 1:
                zi = np.zeros(max(len(a), len(b)) - 1, dtype=np.float64)
            y, zf = signal.lfilter(b, a, y, zi=zi)
            self.states[key] = np.asarray(zf, dtype=np.float64)
            applied += 1
        # A rule that is not active in this block loses its transient filter
        # state.  If it becomes active again later it starts a new interval.
        self.states = {k: v for k, v in self.states.items() if k in active_keys}
        self.blocks += 1
        self.samples += int(y.size)
        self.last_active = applied
        return np.asarray(y, dtype=np.float32)

    def state_summary(self) -> _SequenceBox:
        return _SequenceBox((self.blocks, self.samples, len(self.states), self.last_active))

    def flush(self) -> np.ndarray:
        return np.zeros(0, dtype=np.float32)


def make_dynamic_filter_stream(sample_rate: int, max_filters_per_block: int = 4):
    return DynamicFilterStream(sample_rate, max_filters_per_block)
