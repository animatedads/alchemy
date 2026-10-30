#!/usr/bin/env python3
"""SPASH SLAM WAV query-by-example reference provider.

Experimental spectral likeness only. No transcript, source-ID, room-geometry
or independent microphone authority. Resampling requires explicit preprocessing.
"""
import argparse
import hashlib
import json
import sys
import wave
from pathlib import Path
import numpy as np

PROVIDER = "SPASH_PY_WAV_LOGSPECTRUM_V0.1"
FRAME = 256
HOP = 128
BLOCK_FRAMES = 10
NUM_BANDS = 22


def read_wav(path):
    path = Path(path)
    with wave.open(str(path), "rb") as handle:
        sr = handle.getframerate()
        channels = handle.getnchannels()
        size = handle.getsampwidth()
        n = handle.getnframes()
        if handle.getcomptype() != 'NONE' or size != 2 or channels != 1:
            raise ValueError("SPASH reference requires uncompressed mono 16-bit PCM WAV")
        if sr != 8000:
            raise ValueError("SPASH reference requires 8000 Hz: resampling must be separate, explicit and recorded")
        raw = handle.readframes(n)
    audio = np.frombuffer(raw, dtype='<i2').astype(np.float64) / 32768.0
    if len(audio) < FRAME:
        raise ValueError("SPASH specimen requires at least 256 samples")
    return audio, sr, hashlib.sha256(path.read_bytes()).hexdigest()


def fingerprint(audio):
    """Spectral shape and activity, not named events or physical identities."""
    count = 1 + (len(audio) - FRAME) // HOP
    windows = np.lib.stride_tricks.sliding_window_view(audio, FRAME)[::HOP][:count]
    spectra = np.abs(np.fft.rfft(windows * np.hanning(FRAME)[None, :], axis=1)) ** 2
    freqs = np.fft.rfftfreq(FRAME, d=1. / 8000)
    edges = np.geomspace(80., 3800., NUM_BANDS + 1)
    bands = np.empty((count, NUM_BANDS), dtype=np.float64)
    for i in range(NUM_BANDS):
        mask = (freqs >= edges[i]) & (freqs < edges[i + 1])
        if not mask.any():
            ix = np.argmin(np.abs(freqs - np.sqrt(edges[i]*edges[i+1])))
            mask[ix] = True
        bands[:, i] = np.mean(spectra[:, mask], axis=1)
    blocks = count // BLOCK_FRAMES
    bands = bands[:blocks * BLOCK_FRAMES].reshape(blocks, BLOCK_FRAMES, NUM_BANDS).mean(axis=1)
    rms = np.sqrt(np.mean(windows[:blocks * BLOCK_FRAMES] ** 2, axis=1)).reshape(blocks, BLOCK_FRAMES).mean(axis=1)
    shapes = np.sqrt(np.maximum(bands, 0))
    shapes /= np.maximum(shapes.sum(axis=1, keepdims=True), 1.e-15)
    return shapes, rms


def active_templates(shape, rms, template_blocks=6, stride=2, max_templates=20):
    if len(shape) < template_blocks:
        raise ValueError("query shorter than requested template length")
    noise = float(np.percentile(rms, 30))
    threshold = max(noise * 2.0, float(np.max(rms))*0.08, 1.e-7)
    scored = []
    for i in range(0, len(shape) - template_blocks + 1, stride):
        activity = rms[i:i+template_blocks]
        active = int(np.sum(activity >= threshold))
        if active < 1:
            continue
        scored.append((i, active, float(activity.max())))
    scored.sort(key=lambda item: (-item[1], -item[2], item[0]))
    return sorted(x[0] for x in scored[:max_templates]), {"rms_activity_threshold": threshold, "noise_floor_rms": noise}


def variants(query):
    # Time scaling and one coarse log-band shift are hypotheses, not
    # calibrated pitch/tempo invariance.
    n = len(query)
    for rate in (0.85, 1.0, 1.15):
        m = max(2, int(round(n * rate)))
        old = np.arange(n, dtype=float)
        new = np.linspace(0, n-1, m)
        warped = np.stack([np.interp(new, old, query[:, j]) for j in range(query.shape[1])], axis=1)
        for shift in (-1, 0, 1):
            if shift == -1:
                shifted = np.hstack([warped[:, 1:], np.zeros((m, 1))])
            elif shift == 1:
                shifted = np.hstack([np.zeros((m, 1)), warped[:, :-1]])
            else:
                shifted = warped
            shifted /= np.maximum(shifted.sum(axis=1, keepdims=True), 1.e-15)
            yield rate, shift, shifted


def search(query_wav, candidate_wavs, *, segment_seconds=.96, min_score=.70, max_results=12):
    query_audio, sr, query_sha = read_wav(query_wav)
    qshape, qrms = fingerprint(query_audio)
    length = max(3, int(round(segment_seconds * sr / (HOP * BLOCK_FRAMES))))
    starts, policy = active_templates(qshape, qrms, template_blocks=length)
    if not starts:
        return {"schema": "spash.example.search/0.1", "status": "NO_ACTIVE_TEMPLATE", "matches": [], "query_sha256": query_sha}
    out = []
    for candidate_path in candidate_wavs:
        candidate_audio, candidate_sr, candidate_sha = read_wav(candidate_path)
        cshape, crms = fingerprint(candidate_audio)
        for qi in starts:
            q = qshape[qi:qi+length]
            for rate, shift, variant in variants(q):
                width = len(variant)
                if width > len(cshape):
                    continue
                for chunk in range(0, len(cshape)-width+1, 256):
                    stop = min(len(cshape)-width+1, chunk+256)
                    sub = cshape[chunk:stop+width-1]
                    windows = np.lib.stride_tricks.sliding_window_view(sub, width, axis=0).transpose(0,2,1)
                    scores = np.clip(1.0 - np.abs(windows-variant[None,:,:]).sum(axis=2).mean(axis=1)/2.0,0.,1.)
                    for ix in np.flatnonzero(scores >= min_score):
                        ci = chunk + int(ix)
                        if candidate_sha == query_sha:
                            if max(ci,qi) < min(ci+width,qi+length):
                                continue  # trivial same-recording self overlap
                        score = float(scores[ix])
                        out.append({
                            "candidate": str(candidate_path), "candidate_sha256": candidate_sha,
                            "query_start_s": round(qi*BLOCK_FRAMES*HOP/sr,3),
                            "query_end_s": round((qi+length)*BLOCK_FRAMES*HOP/sr,3),
                            "candidate_start_s": round(ci*BLOCK_FRAMES*HOP/sr,3),
                            "candidate_end_s": round((ci+width)*BLOCK_FRAMES*HOP/sr,3),
                            "likeness": round(score,6),
                            "time_scale_tested": rate,
                            "coarse_spectral_shift_bins": shift,
                            "authority": "ALGORITHM_CANDIDATE_ONLY",
                        })
    out.sort(key=lambda r: (-r['likeness'], r['candidate'], r['candidate_start_s'], r['query_start_s']))
    accepted=[]
    for row in out:
        if any(row['candidate_sha256']==r['candidate_sha256'] and
               max(row['candidate_start_s'],r['candidate_start_s']) <
               min(row['candidate_end_s'],r['candidate_end_s']) for r in accepted):
            continue
        accepted.append(row)
        if len(accepted)>=max_results:
            break
    return {
        "schema": "spash.example.search/0.1", "status": "CANDIDATES" if accepted else "NO_MATCH_AT_THRESHOLD",
        "query": str(query_wav), "query_sha256": query_sha, "query_duration_s": round(len(query_audio)/sr,3),
        "sample_rate_hz": sr, "provider": PROVIDER,
        "policy": {"segment_seconds": segment_seconds, "requested_min_likeness": min_score,
                   "pitch_shift_not_calibrated": True, "no_semantic_labels": True,
                   "location_not_inferred": True, "algorithm_score_not_probability": True,
                   "trivial_self_overlaps_excluded": True, **policy},
        "matches": accepted,
    }


def main():
    parser = argparse.ArgumentParser(description="SPASH experimental WAV query-by-example, no ASR")
    parser.add_argument('query', help='example 8kHz mono PCM16 WAV')
    parser.add_argument('candidates', nargs='+', help='candidate WAV files')
    parser.add_argument('--segment-seconds', type=float, default=.96)
    parser.add_argument('--min-score', type=float, default=.70)
    parser.add_argument('--max-results', type=int, default=12)
    args = parser.parse_args()
    if args.segment_seconds < .48 or args.segment_seconds > 5:
        parser.error('segment seconds must be between 0.48 and 5')
    if not 0 <= args.min_score <= 1 or args.max_results < 1:
        parser.error('invalid score or result count')
    try:
        result=search(args.query,args.candidates,segment_seconds=args.segment_seconds,
                      min_score=args.min_score,max_results=args.max_results)
    except (ValueError, wave.Error, OSError) as e:
        print(json.dumps({"status":"INVALID_INPUT","error":str(e)}),file=sys.stderr)
        return 2
    print(json.dumps(result,indent=2))
    return 0

if __name__=='__main__':
    sys.exit(main())
