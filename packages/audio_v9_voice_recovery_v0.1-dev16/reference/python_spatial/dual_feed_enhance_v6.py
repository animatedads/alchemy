#!/usr/bin/env python3
"""
dual_feed_enhance_v6.py
=======================
Forensic Audio Enhancement — Dual-Feed Pipeline (v6 ULTIMATE)

NEW IN V6:
  - 5-Domain Coherence Fusion (Spatial, Phase, Echo, Modulation, Harmonic)
  - Evaluates the "Syllabic Rate" (2-8Hz jaw movement envelope)
  - Evaluates Harmonic Product Spectrum (Vocal cord pitch stacking)
"""

import os
import sys
import argparse
import yaml
import numpy as np
import soundfile as sf
import librosa
from datetime import datetime, timedelta
from scipy.fftpack import fft, ifft
from scipy.ndimage import uniform_filter1d
import scipy.signal

# ---------------------------------------------------------------------------
# CORE TIMELINE ENGINE (YAML Driven)
# ---------------------------------------------------------------------------

def parse_dt(s):
    formats = ['%Y-%m-%d %H:%M:%S', '%Y-%m-%d %H:%M', '%Y-%m-%d']
    for fmt in formats:
        try:
            return datetime.strptime(s.strip(), fmt)
        except ValueError:
            continue
    raise ValueError(f"Time data '{s}' does not match recognized formats")

def determine_camera(yaml_type):
    if "fd feed" in yaml_type.lower(): return "cam_b"
    return "cam_a"

def matches_tier(yaml_type, target_tier):
    yt = yaml_type.lower()
    tt = target_tier.lower()
    if tt == "amp32": return "+32db" in yt or "amp32" in yt
    if tt == "plus20": return "+20db" in yt or "plus20" in yt
    if tt == "enhanced": return "enhanced" in yt and "+20" not in yt
    if tt == "original": return "original" in yt
    return False

def find_file_for_time(files, target_cam, current_t, target_tier="amp32"):
    valid_files = []
    for f in files:
        yaml_type = f.get('type', '')
        cam = determine_camera(yaml_type)
        if cam == target_cam and matches_tier(yaml_type, target_tier):
            start = parse_dt(f['start'])
            if start <= current_t:
                valid_files.append((start, f))

    if not valid_files: return None
    valid_files.sort(key=lambda x: x[0], reverse=True)
    most_recent_start, best_file = valid_files[0]

    if current_t - most_recent_start > timedelta(hours=4): return None
    return best_file

def load_audio_segment(path, start_dt, target_t, duration_sec, sr=22050):
    offset = (target_t - start_dt).total_seconds()
    if offset < 0: return None
    try:
        file_dur = librosa.get_duration(path=path)
        if offset >= file_dur: return None
        y, _ = librosa.load(path, sr=sr, offset=offset, duration=duration_sec)
        target_len = int(duration_sec * sr)
        if len(y) < target_len:
            y = np.pad(y, (0, target_len - len(y)))
        return y
    except Exception:
        return None

# ---------------------------------------------------------------------------
# V6 ADVANCED DSP: 5-DOMAIN PROBABILITY FUSION
# ---------------------------------------------------------------------------

def profile_room_acoustics(y, sr=22050):
    onset_env = librosa.onset.onset_strength(y=y, sr=sr)
    min_frames = int(0.010 * sr / 512)
    max_frames = int(0.150 * sr / 512)
    ac = librosa.autocorrelate(onset_env, max_size=max_frames)
    ac[:min_frames] = 0
    peaks, _ = scipy.signal.find_peaks(ac, distance=2, prominence=np.max(ac)*0.05)

    if len(peaks) < 2: return np.array([15, 30, 45, 60, 80])
    delays_ms = (peaks * 512 / sr) * 1000.0
    return np.sort(delays_ms)[:6]

def gcc_phat_align(sig, refsig, fs=22050, max_tau=0.15):
    n = sig.shape[0] + refsig.shape[0]
    SIG = fft(sig, n=n)
    REFSIG = fft(refsig, n=n)
    R = SIG * np.conj(REFSIG)
    denom = np.maximum(np.abs(R), 1e-6)
    cc = np.real(ifft(R / denom))

    max_shift = int(max_tau * fs)
    cc = np.concatenate((cc[-max_shift:], cc[:max_shift+1]))
    shift = np.argmax(cc) - max_shift
    return np.roll(sig, shift)

def five_domain_coherence_fusion(y_a, y_b, room_delays_ms, sr=22050, n_fft=2048, hop=512):
    """
    The 5-Domain Reality Detector.
    """
    if len(y_a) < n_fft or len(y_b) < n_fft: return y_a

    S_a = librosa.stft(y_a, n_fft=n_fft, hop_length=hop)
    S_b = librosa.stft(y_b, n_fft=n_fft, hop_length=hop)
    mag_a, mag_b = np.abs(S_a), np.abs(S_b)
    phase_a = np.angle(S_a)

    # 1. SPATIAL COHERENCE (Beamformer)
    cps = S_a * np.conj(S_b)
    spatial_score = np.abs(cps) / (mag_a * mag_b + 1e-8)

    # 2. WAVEFRONT PERSISTENCE (Phase Continuity)
    dphase = np.angle(np.exp(1j * np.diff(phase_a, axis=1)))
    dphase = np.pad(dphase, ((0, 0), (1, 0)), mode='edge')
    local_mean_dp = uniform_filter1d(dphase, size=3, axis=1)
    local_var_dp = uniform_filter1d((dphase - local_mean_dp)**2, size=3, axis=1)
    wavefront_score = np.exp(-3.0 * local_var_dp)

    # 3. TUNED ECHO CONSTELLATION (Using Profiled Room Dimensions)
    delays_frames = (np.array(room_delays_ms) / 1000.0 * sr / hop).astype(int)
    delays_frames = delays_frames[delays_frames > 0]

    echo_raw = np.zeros_like(mag_a)
    for d in delays_frames:
        shifted_mag = np.pad(mag_a[:, :-d], ((0, 0), (d, 0)), mode='constant')
        echo_raw += np.sqrt(mag_a * shifted_mag)
    echo_raw /= max(1, len(delays_frames))

    local_max = uniform_filter1d(echo_raw, size=int((sr/hop)*2.0), axis=1) + 1e-8
    echo_score = echo_raw / local_max

    # 4. SYLLABIC MODULATION (2-8 Hz Human Jaw Speed)
    # Calculates a fast envelope and a slow envelope. The difference reveals
    # the pulsing amplitude characteristic of human speech.
    env_fast = uniform_filter1d(mag_a, size=int(0.05 * sr / hop), axis=1)
    env_slow = uniform_filter1d(mag_a, size=int(0.30 * sr / hop), axis=1)
    modulation_raw = np.maximum(0, env_fast - env_slow)
    modulation_score = modulation_raw / (np.max(modulation_raw, axis=1, keepdims=True) + 1e-8)

    # 5. HARMONIC STRUCTURE (Simplified Harmonic Product Spectrum)
    # Drops the spectrum by a factor of 2 to see if frequencies stack nicely.
    half_f = mag_a.shape[0] // 2
    harm_score = np.zeros_like(mag_a)
    # Multiply f by 2f to verify vocal cord multiples
    harm_score[:half_f, :] = np.sqrt(mag_a[:half_f, :] * mag_a[0:half_f*2:2, :])
    harm_score = harm_score / (np.max(harm_score, axis=0) + 1e-8)

    # --- FUSION WEIGHTS ---
    # We carefully balance spatial physics with biological mechanics.
    fused_probability = (
        (spatial_score * 0.35) +
        (echo_score * 0.25) +
        (wavefront_score * 0.15) +
        (modulation_score * 0.15) +
        (harm_score * 0.10)
    )

    # Soft thresholding sigmoid mask
    final_mask = 1.0 / (1.0 + np.exp(-12 * (fused_probability - 0.35)))
    final_mask = uniform_filter1d(final_mask, size=3, axis=1)

    S_clean = S_a * final_mask
    return librosa.istft(S_clean, length=len(y_a))

# ---------------------------------------------------------------------------
# MAIN PROCESSOR
# ---------------------------------------------------------------------------

def run_v6_pipeline(yaml_path, tier, start_time, end_time, out_path):
    with open(yaml_path, 'r') as f:
        config = yaml.safe_load(f)

    sr = 22050
    block_sec = 8.0

    print(f"[*] MDCF Pipeline v6 (5-Domain Reality Detector)")
    print(f"[*] Target Tier: '{tier}' | Window: {start_time} -> {end_time}")

    print("[*] Extracting acoustic fingerprint of the room...")
    file_a_init = find_file_for_time(config['files'], "cam_a", start_time, target_tier=tier)
    if file_a_init:
        y_profile = load_audio_segment(file_a_init['path'], parse_dt(file_a_init['start']), start_time, 10.0, sr)
        if y_profile is not None:
            room_delays = profile_room_acoustics(y_profile, sr=sr)
            formatted_delays = ", ".join([f"{d:.1f}ms" for d in room_delays])
            print(f"    [+] Room fingerprint locked. Dominant reflections: {formatted_delays}")
        else:
            room_delays = [15, 30, 45, 60]
    else:
        room_delays = [15, 30, 45, 60]

    print("-" * 60)

    fmt = 'OGG' if out_path.lower().endswith('.ogg') else None
    subtype = 'VORBIS' if fmt == 'OGG' else None

    with sf.SoundFile(out_path, mode='w', samplerate=sr, channels=3, format=fmt, subtype=subtype) as out:
        current_t = start_time
        blocks_dual = 0
        blocks_mono = 0
        blocks_silent = 0

        while current_t < end_time:
            file_a = find_file_for_time(config['files'], "cam_a", current_t, target_tier=tier)
            file_b = find_file_for_time(config['files'], "cam_b", current_t, target_tier=tier)

            y_a = load_audio_segment(file_a['path'], parse_dt(file_a['start']), current_t, block_sec, sr) if file_a else None
            y_b = load_audio_segment(file_b['path'], parse_dt(file_b['start']), current_t, block_sec, sr) if file_b else None

            if y_a is not None and y_b is not None:
                blocks_dual += 1
                y_a_aligned = gcc_phat_align(y_a, y_b, fs=sr)

                # V6 5-Domain Fusion
                center_beam = five_domain_coherence_fusion(y_a_aligned, y_b, room_delays, sr=sr)

                chunk = np.vstack((y_a_aligned, y_b, center_beam)).T

            elif y_a is not None:
                blocks_mono += 1
                chunk = np.vstack((y_a, y_a, y_a)).T

            elif y_b is not None:
                blocks_mono += 1
                chunk = np.vstack((y_b, y_b, y_b)).T

            else:
                blocks_silent += 1
                chunk = np.zeros((int(block_sec * sr), 3))

            out.write(chunk)
            current_t += timedelta(seconds=block_sec)

            print(f"  Progress: {current_t:%Y-%m-%d %H:%M:%S} | Dual: {blocks_dual} Mono: {blocks_mono} Silent: {blocks_silent}", end="\r")

    print(f"\n\n{'='*60}")
    print(f"  Audio Generation Complete: {out_path}")
    print(f"  Registering file in {yaml_path}...")

    new_entry = {
        'path': out_path,
        'start': start_time.strftime('%Y-%m-%d %H:%M:%S'),
        'type': f"Coverage - MDCF Master v6 ({tier})"
    }

    if 'files' not in config: config['files'] = []
    updated = False
    for entry in config['files']:
        if entry.get('path') == out_path:
            entry['start'] = new_entry['start']
            entry['type'] = new_entry['type']
            updated = True; break

    if not updated: config['files'].append(new_entry)
    config['files'].sort(key=lambda x: x.get('start', ''))

    with open(yaml_path, 'w') as f:
        yaml.dump(config, f, default_flow_style=False, sort_keys=False)

    print(f"  SUCCESS: YAML Updated.")
    print(f"{'='*60}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--yaml", required=True)
    parser.add_argument("--tier", default="amp32", help="Tier: original, amp32, plus20")
    parser.add_argument("--start", help="YYYY-MM-DD HH:MM:SS or HH:MM")
    parser.add_argument("--end", help="YYYY-MM-DD HH:MM:SS or HH:MM")
    parser.add_argument("--out", default="fcpaphos/master_v6_mdcf.ogg", help="Output path (should end in .ogg)")
    args = parser.parse_args()

    with open(args.yaml, 'r') as f:
        cfg = yaml.safe_load(f)

    all_starts = sorted([parse_dt(f['start']) for f in cfg['files']])

    def handle_time(time_str, default_dt):
        if not time_str: return default_dt
        if "-" not in time_str: return parse_dt(f"2023-10-10 {time_str}")
        return parse_dt(time_str)

    t0 = handle_time(args.start, all_starts[0])
    t1 = handle_time(args.end, all_starts[-1] + timedelta(minutes=32))

    run_v6_pipeline(args.yaml, args.tier, t0, t1, args.out)
