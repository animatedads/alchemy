#!/usr/bin/env python3
"""
dual_feed_enhance_v11_zonal_scene.py
====================================

V11 zonal forensic scene renderer.

Based on the V10/V10.2 idea, but instead of producing one enhanced master only,
V11 creates:
  - a master mix
  - one audio stem per zone
  - event likelihood CSV/JSONL
  - an MP4 map showing likely source zone(s) over time

The model is intentionally probability-based. A sound can be:
  65% Target Room A
  20% Stairs/Landing
  10% Hall/Office
   5% Unknown/Diffuse

The audio is then written into zone stems with likelihood weighting.

Requires:
  forensic_helper.py
  numpy, scipy, librosa, soundfile, yaml, matplotlib
  ffmpeg on PATH for MP4 creation

Example:
  python dual_feed_enhance_v11_zonal_scene.py \
    --yaml fcpaphos_project.yaml \
    --tier amp32 \
    --start "2023-10-10 15:00:00" \
    --end "2023-10-10 18:00:00" \
    --site-json fcpaphos_12_12_layout_site_model.json \
    --dual-cam-a "Cam A" \
    --dual-cam-b "Cam B" \
    --workers 7 \
    --all \
    --out-dir fcpaphos/v11_zonal_20231010_1500_1800
"""

from __future__ import annotations

import argparse
import csv
import json
import math
import os
import re
import shutil
import subprocess
import sys
import concurrent.futures
from dataclasses import dataclass, asdict
from datetime import datetime, timedelta
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

import numpy as np
import yaml
import soundfile as sf
import librosa
from scipy import signal
from scipy.ndimage import uniform_filter1d

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import Polygon

from forensic_helper import ForensicHelper as fh

SR = 22050
N_FFT = 2048
HOP_LENGTH = N_FFT // 4
SPEED_OF_SOUND = 343.0


@dataclass
class Event:
    event_id: str
    start: str
    end: str
    center: str
    channels: List[str]
    rms_db: float
    z_rms: float
    peak_hz: float
    tonality: float
    flux: float
    modulation: float
    label: str
    source_files: List[str]


def safe(y):
    return np.nan_to_num(y, nan=0.0, posinf=0.0, neginf=0.0).astype(np.float32, copy=False)


def pad_or_trim(y, n):
    y = safe(y)
    if len(y) >= n:
        return y[:n]
    return np.pad(y, (0, n - len(y))).astype(np.float32, copy=False)


def rms_db(y):
    y = safe(y)
    return 20.0 * math.log10(max(float(np.sqrt(np.mean(y*y) + 1e-12)), 1e-12))


def str_to_dt(s):
    for fmt in ("%Y-%m-%d %H:%M:%S.%f", "%Y-%m-%d %H:%M:%S"):
        try:
            return datetime.strptime(s, fmt)
        except ValueError:
            pass
    if "." in s:
        a,b=s.split(".",1)
        return datetime.strptime(a+"."+((b+"000000")[:6]), "%Y-%m-%d %H:%M:%S.%f")
    raise ValueError(s)


def dt_to_str(dt):
    return dt.strftime("%Y-%m-%d %H:%M:%S.%f")[:-3]


def parse_time_arg(s, default_dt, project_date=None):
    if not s:
        return default_dt
    p = fh.parse_dt(s)
    if p:
        return p
    base = project_date or default_dt
    p = fh.parse_dt(f"{base:%Y-%m-%d} {s}:00")
    if p:
        return p
    raise ValueError(f"Could not parse time: {s!r}")


def project_id(yaml_path):
    return os.path.splitext(os.path.basename(yaml_path))[0]


def ensure_dir(p):
    os.makedirs(p, exist_ok=True)


def slug(s):
    return re.sub(r"[^A-Za-z0-9._-]+", "_", str(s)).strip("_").lower() or "zone"


def jsonl_write(path, rows):
    with open(path, "w", encoding="utf-8") as f:
        for row in rows:
            f.write(json.dumps(row, ensure_ascii=False, sort_keys=True) + "\n")


def jsonl_read(path):
    if not os.path.exists(path):
        return []
    with open(path, "r", encoding="utf-8") as f:
        return [json.loads(x) for x in f if x.strip()]


def load_streams(yaml_path, tier, t0, t1):
    raw = fh.get_active_streams(yaml_path, t0, t1, max_assumed_hours=96, tier=tier)
    tl = (tier or "").lower()
    if tl:
        keep = []
        for s in raw:
            hay = " ".join(str(s.get(k,"")) for k in ("filter","type","path")).lower()
            if tl == "amp32":
                ok = "amp32" in hay or "+32db" in hay or "raw amp" in hay
            elif tl == "plus20":
                ok = "plus20" in hay or "+20db" in hay or "+20" in hay
            elif tl == "enhanced":
                ok = "enhanced" in hay and "plus20" not in hay and "+20" not in hay
            elif tl == "original":
                ok = "original" in hay
            else:
                ok = tl in hay
            if ok:
                keep.append(s)
        raw = keep
    raw.sort(key=lambda s: (s["start_dt"], s.get("cam_id",""), s.get("path","")))
    return raw


def active_streams_at(streams, t):
    return [s for s in streams if s["start_dt"] <= t < s["end_dt"]]


def choose_channels(active):
    out = {}
    for s in sorted(active, key=lambda x: x["start_dt"]):
        out[s.get("cam_id","Unknown")] = s
    return out


def spectral_features(y):
    y = safe(y)
    if not np.any(y):
        return dict(peak_hz=0.0, tonality=0.0, flux=0.0, modulation=0.0)
    S = librosa.stft(y, n_fft=N_FFT, hop_length=HOP_LENGTH)
    mag = np.abs(S) + 1e-12
    freqs = librosa.fft_frequencies(sr=SR, n_fft=N_FFT)
    mean_spec = np.mean(mag, axis=1)
    peak_hz = float(freqs[int(np.argmax(mean_spec))])
    tonality = float(np.clip((np.max(mean_spec)/(np.median(mean_spec)+1e-12))/60.0, 0, 1))
    flux = float(np.mean(np.maximum(np.diff(mag, axis=1), 0.0)) / (np.mean(mag)+1e-12))
    env = librosa.feature.rms(S=mag)[0]
    frame_rate = SR / HOP_LENGTH
    if len(env) > 24 and np.max(env) > 1e-10:
        try:
            b,a = signal.butter(2, [2/(frame_rate/2), 8/(frame_rate/2)], btype="band")
            mod = signal.filtfilt(b,a,env)
            modulation = float(np.clip(np.sqrt(np.mean(mod*mod))/(np.mean(env)+1e-12)/1.5, 0, 1))
        except Exception:
            modulation = 0.0
    else:
        modulation = 0.0
    return dict(peak_hz=peak_hz, tonality=tonality, flux=flux, modulation=modulation)


def deterministic_label(f):
    if f["modulation"] > 0.35 and 120 <= f["peak_hz"] <= 4500:
        return "speech"
    if f["tonality"] > 0.5 and 700 <= f["peak_hz"] <= 4500:
        return "alarm_or_tone"
    if f["flux"] > 0.8:
        return "impact"
    return "unknown_structured"


def scan_events(args, streams, t0, t1, out_dir):
    block_sec = args.scan_block_sec
    hop_sec = args.scan_hop_sec
    n = int(block_sec * SR)
    metrics = []
    t = t0
    idx = 0
    print("[scan] measuring event candidates")
    while t < t1:
        active = choose_channels(active_streams_at(streams, t))
        ys = []
        sources = []
        for cam,s in sorted(active.items()):
            y = pad_or_trim(fh.read_stream_block(s, t, block_sec, SR), n)
            if np.any(y):
                ys.append(y)
                sources.append(os.path.basename(s.get("path","")))
        if ys:
            mix = np.mean(np.vstack(ys), axis=0)
            rd = rms_db(mix)
            feat = spectral_features(mix)
        else:
            rd = -120.0
            feat = spectral_features(np.zeros(n, dtype=np.float32))
        metrics.append(dict(idx=idx, t=t, rms_db=rd, features=feat, channels=sorted(active.keys()), source_files=sorted(set(sources))))
        t += timedelta(seconds=hop_sec)
        idx += 1
        if idx % 500 == 0:
            print(f"  [scan] {idx} hops at {t:%Y-%m-%d %H:%M:%S}", end="\r")
    if not metrics:
        return []
    vals = np.array([m["rms_db"] for m in metrics], float)
    med = float(np.median(vals))
    mad = float(np.median(np.abs(vals - med)))
    sigma = max(1.4826 * mad, 2.5)
    threshold = max(args.min_rms_db, min(med + args.scan_z * sigma, args.max_scan_threshold_db))
    print(f"\n[scan] median={med:.1f} sigma={sigma:.1f} threshold={threshold:.1f}")

    flags = []
    for m in metrics:
        f = m["features"]
        structured = f["flux"] > args.min_flux or f["tonality"] > args.min_tonality or f["modulation"] > args.min_modulation
        flags.append(bool(m["rms_db"] >= threshold and structured and m["channels"]))

    events = []
    i = 0
    num = 0
    while i < len(metrics):
        if not flags[i]:
            i += 1
            continue
        j = i
        while j + 1 < len(metrics) and flags[j+1]:
            j += 1
        group = metrics[max(0,i-1):min(len(metrics),j+2)]
        st = group[0]["t"]
        en = group[-1]["t"] + timedelta(seconds=block_sec)
        cen = st + (en-st)/2
        best = max(group, key=lambda x: x["rms_db"])
        f = best["features"]
        label = deterministic_label(f)
        events.append(Event(
            f"evt_{num:06d}", dt_to_str(st), dt_to_str(en), dt_to_str(cen),
            sorted(set(c for g in group for c in g["channels"])),
            float(best["rms_db"]), float((best["rms_db"]-med)/sigma),
            float(f["peak_hz"]), float(f["tonality"]), float(f["flux"]), float(f["modulation"]),
            label, sorted(set(x for g in group for x in g["source_files"]))
        ))
        num += 1
        i = j + 1

    if args.max_events and len(events) > args.max_events:
        events.sort(key=lambda e: (e.z_rms, e.flux + e.modulation + e.tonality), reverse=True)
        events = events[:args.max_events]
        events.sort(key=lambda e: e.start)

    path = os.path.join(out_dir, "data", "events.jsonl")
    jsonl_write(path, [asdict(e) for e in events])
    print(f"[scan] wrote {len(events)} events to {path}")
    return events


def site_mics(site):
    if isinstance(site.get("mics"), dict) and site["mics"]:
        return site["mics"]
    if isinstance(site.get("mic"), dict):
        return {"Cam A": site["mic"]}
    return {}


def dist_to_mic(x,y,z,m):
    return float(np.sqrt((x-float(m["x"]))**2 + (y-float(m["y"]))**2 + (z-float(m.get("z",1.5)))**2))


def predicted_tdoa_samples(site, cam_a, cam_b, x, y, z):
    mics = site_mics(site)
    if cam_a not in mics or cam_b not in mics:
        return None
    da = dist_to_mic(x,y,z,mics[cam_a])
    db = dist_to_mic(x,y,z,mics[cam_b])
    return (db - da) / SPEED_OF_SOUND * SR


def gcc_phat_lag_conf(y_a, y_b, max_delay_sec=0.25):
    y_a = safe(y_a)
    y_b = safe(y_b)
    if not np.any(y_a) or not np.any(y_b):
        return 0, 0.0
    n = min(len(y_a), len(y_b))
    y_a = y_a[:n] - np.mean(y_a[:n])
    y_b = y_b[:n] - np.mean(y_b[:n])
    nfft = 1 << int(np.ceil(np.log2(max(2, len(y_a)+len(y_b)-1))))
    A = np.fft.rfft(y_a, nfft)
    B = np.fft.rfft(y_b, nfft)
    R = A * np.conj(B)
    cc = np.fft.irfft(R / (np.abs(R) + 1e-10), nfft)
    max_lag = int(max_delay_sec * SR)
    search = np.concatenate([cc[-max_lag:], cc[:max_lag+1]])
    idx = int(np.argmax(np.abs(search)))
    lag = idx - max_lag
    conf = float(np.abs(search[idx]) / (np.median(np.abs(search)) + 1e-12))
    return int(lag), conf


def envelope_lag_conf(y_a, y_b, max_delay_sec=0.25):
    y_a = safe(y_a)
    y_b = safe(y_b)
    n = min(len(y_a), len(y_b))
    if n <= 10 or not np.any(y_a) or not np.any(y_b):
        return 0, 0.0
    ea = np.abs(signal.hilbert(y_a[:n]))
    eb = np.abs(signal.hilbert(y_b[:n]))
    kernel = max(5, int(0.015*SR) | 1)
    ea = signal.medfilt(ea, kernel_size=kernel)
    eb = signal.medfilt(eb, kernel_size=kernel)
    ea = (ea - np.mean(ea)) / (np.std(ea) + 1e-9)
    eb = (eb - np.mean(eb)) / (np.std(eb) + 1e-9)
    corr = signal.correlate(ea, eb, mode="full")
    lags = np.arange(-len(eb)+1, len(ea))
    mask = np.abs(lags) <= int(max_delay_sec*SR)
    sub = corr[mask]
    sub_lags = lags[mask]
    idx = int(np.argmax(sub))
    lag = int(sub_lags[idx])
    conf = float(abs(sub[idx]) / (np.median(np.abs(sub)) + 1e-12))
    return lag, conf


def event_audio_pair(event, streams, args):
    cen = str_to_dt(event.center)
    dur = max(1.0, min(8.0, (str_to_dt(event.end)-str_to_dt(event.start)).total_seconds()+2.0))
    start = cen - timedelta(seconds=dur/2)
    n = int(dur * SR)
    active = choose_channels(active_streams_at(streams, cen))
    if args.dual_cam_a not in active or args.dual_cam_b not in active:
        return None
    ya = pad_or_trim(fh.read_stream_block(active[args.dual_cam_a], start, dur, SR), n)
    yb = pad_or_trim(fh.read_stream_block(active[args.dual_cam_b], start, dur, SR), n)
    return ya, yb


def choose_lag_for_event(event, ya, yb, args):
    gcc_lag, gcc_conf = gcc_phat_lag_conf(ya, yb, args.max_tdoa_ms/1000)
    env_lag, env_conf = envelope_lag_conf(ya, yb, args.max_tdoa_ms/1000)
    tonal = event.label in {"alarm_or_tone"} or event.tonality >= 0.35
    suspicious = tonal and abs(gcc_lag) <= 2 and gcc_conf >= 30 and abs(env_lag) > int(0.010*SR) and env_conf >= 3
    if tonal or suspicious:
        return env_lag, env_conf, "envelope_lag", gcc_lag, gcc_conf, env_lag, env_conf, suspicious
    return gcc_lag, gcc_conf, "gcc_phat", gcc_lag, gcc_conf, env_lag, env_conf, suspicious


def softmax(scores, temperature=1.0):
    arr = np.array(scores, dtype=float)
    arr = arr / max(temperature, 1e-6)
    arr -= np.max(arr)
    exp = np.exp(arr)
    return exp / (np.sum(exp) + 1e-12)


def zone_centres(site):
    out = []
    for z in site["zones"]:
        c = z.get("centre_xy_m")
        if c:
            height = 1.7
            zr = z.get("z_range_m")
            if zr and len(zr) == 2:
                height = min(max(1.7, zr[0]), zr[1])
            out.append((z, float(c[0]), float(c[1]), float(height)))
    return out


def compute_zone_likelihood_for_event(event, streams, site, args):
    centres = zone_centres(site)
    pair = event_audio_pair(event, streams, args)
    use_dual = pair is not None and args.dual_cam_a in site_mics(site) and args.dual_cam_b in site_mics(site)

    observed_lag = 0
    lag_conf = 0.0
    method = "mono_prior"
    gcc_lag = gcc_conf = env_lag = env_conf = ""
    suspicious = ""

    scores = []
    if use_dual:
        ya, yb = pair
        observed_lag, lag_conf, method, gcc_lag, gcc_conf, env_lag, env_conf, suspicious = choose_lag_for_event(event, ya, yb, args)
        for z, x, y, h in centres:
            pred = predicted_tdoa_samples(site, args.dual_cam_a, args.dual_cam_b, x, y, h)
            if pred is None:
                sc = 0.0
            else:
                sigma = 20.0 if method == "gcc_phat" else 45.0
                err = observed_lag - pred
                sc = math.exp(-(err*err)/(2*sigma*sigma)) * min(3.0, max(0.5, lag_conf/8.0))
            # Prior tweaks: impacts near stairs/door are more plausible in stairs/hall/target zones
            if event.label == "impact" and z["id"] in {"stairs_landing","hall_office","target_room_a","target_room_b"}:
                sc *= 1.25
            if event.label == "speech" and z["id"] in {"living_room","hall_office","target_room_a","target_room_b","stairs_landing"}:
                sc *= 1.15
            scores.append(sc)
    else:
        # Mono fallback: broad priors. Do not overclaim.
        for z, x, y, h in centres:
            sc = 1.0
            if event.label == "impact" and z["id"] in {"stairs_landing","hall_office","target_room_a","target_room_b"}:
                sc = 1.8
            elif event.label == "speech" and z["id"] in {"living_room","hall_office","target_room_a","target_room_b"}:
                sc = 1.5
            elif event.label == "alarm_or_tone" and z["id"] in {"stairs_landing","balcony","road_field"}:
                sc = 1.4
            elif z["id"] == "unknown_diffuse":
                sc = 0.7
            scores.append(sc)

    probs = softmax(scores, temperature=args.zone_temperature)
    likelihoods = []
    for (z,x,y,h), p, sc in zip(centres, probs, scores):
        likelihoods.append({
            "zone_id": z["id"],
            "zone_label": z.get("label", z["id"]),
            "probability": float(p),
            "percent": float(p*100.0),
            "score": float(sc),
            "x": x, "y": y, "z": h
        })
    likelihoods.sort(key=lambda r: r["probability"], reverse=True)
    return {
        "event_id": event.event_id,
        "start": event.start,
        "end": event.end,
        "center": event.center,
        "label": event.label,
        "rms_db": event.rms_db,
        "z_rms": event.z_rms,
        "method": ("dual_" + method) if use_dual else "mono_prior",
        "observed_tdoa_samples": int(observed_lag) if use_dual else "",
        "tdoa_confidence": float(lag_conf) if use_dual else "",
        "gcc_lag_samples": gcc_lag,
        "gcc_confidence": gcc_conf,
        "envelope_lag_samples": env_lag,
        "envelope_confidence": env_conf,
        "suspicious_zero_carrier_lock": suspicious,
        "likelihoods": likelihoods,
        "top_zone": likelihoods[0]["zone_id"] if likelihoods else "unknown_diffuse",
        "top_zone_percent": likelihoods[0]["percent"] if likelihoods else 0.0,
    }


def compute_likelihoods(args, events, streams, site, out_dir):
    print(f"[zonal] computing zone likelihoods for {len(events)} events with workers={args.workers}")
    rows = []
    if args.workers <= 1:
        for e in events:
            rows.append(compute_zone_likelihood_for_event(e, streams, site, args))
    else:
        with concurrent.futures.ThreadPoolExecutor(max_workers=args.workers) as ex:
            futs = [ex.submit(compute_zone_likelihood_for_event, e, streams, site, args) for e in events]
            for i, fut in enumerate(concurrent.futures.as_completed(futs), 1):
                rows.append(fut.result())
                if i % 50 == 0:
                    print(f"  [zonal] {i}/{len(events)}", end="\r")
    rows.sort(key=lambda r: r["start"])

    json_path = os.path.join(out_dir, "data", "events_zonal_likelihood.jsonl")
    jsonl_write(json_path, rows)

    csv_path = os.path.join(out_dir, "data", "events_zonal_likelihood.csv")
    with open(csv_path, "w", newline="", encoding="utf-8") as f:
        fieldnames = [
            "event_id","center","label","method","top_zone","top_zone_percent",
            "observed_tdoa_samples","tdoa_confidence","gcc_lag_samples","gcc_confidence",
            "envelope_lag_samples","envelope_confidence","suspicious_zero_carrier_lock",
            "top_1","top_1_percent","top_2","top_2_percent","top_3","top_3_percent"
        ]
        w = csv.DictWriter(f, fieldnames=fieldnames)
        w.writeheader()
        for r in rows:
            tops = r["likelihoods"][:3] + [{}] * 3
            w.writerow({
                "event_id": r["event_id"],
                "center": r["center"],
                "label": r["label"],
                "method": r["method"],
                "top_zone": r["top_zone"],
                "top_zone_percent": round(r["top_zone_percent"], 2),
                "observed_tdoa_samples": r["observed_tdoa_samples"],
                "tdoa_confidence": round(float(r["tdoa_confidence"]),3) if r["tdoa_confidence"] != "" else "",
                "gcc_lag_samples": r["gcc_lag_samples"],
                "gcc_confidence": round(float(r["gcc_confidence"]),3) if r["gcc_confidence"] != "" else "",
                "envelope_lag_samples": r["envelope_lag_samples"],
                "envelope_confidence": round(float(r["envelope_confidence"]),3) if r["envelope_confidence"] != "" else "",
                "suspicious_zero_carrier_lock": r["suspicious_zero_carrier_lock"],
                "top_1": tops[0].get("zone_id",""),
                "top_1_percent": round(tops[0].get("percent",0),2),
                "top_2": tops[1].get("zone_id",""),
                "top_2_percent": round(tops[1].get("percent",0),2),
                "top_3": tops[2].get("zone_id",""),
                "top_3_percent": round(tops[2].get("percent",0),2),
            })
    print(f"\n[zonal] wrote {json_path}")
    print(f"[zonal] wrote {csv_path}")
    return rows


def mix_block(streams, t, block_sec):
    active = choose_channels(active_streams_at(streams, t))
    n = int(block_sec * SR)
    ys = []
    for cam,s in sorted(active.items())[:2]:
        ys.append(pad_or_trim(fh.read_stream_block(s, t, block_sec, SR), n))
    if not ys:
        return fh.generate_comfort_noise(n, db=-62).astype(np.float32)
    if len(ys) == 1:
        return ys[0]
    return safe(0.5 * ys[0] + 0.5 * ys[1])


def event_weight_for_zone(t0, t1, likelihood_rows, zone_id):
    weight = 0.0
    active = []
    for r in likelihood_rows:
        e0 = str_to_dt(r["start"])
        e1 = str_to_dt(r["end"])
        if e1 < t0 or e0 > t1:
            continue
        p = 0.0
        for z in r["likelihoods"]:
            if z["zone_id"] == zone_id:
                p = z["probability"]
                break
        if p > 0:
            weight = max(weight, p)
            active.append((r["event_id"], p))
    return float(weight), active


def render_zone_stems(args, streams, site, likelihood_rows, t0, t1, out_dir):
    zones = [z["id"] for z in site["zones"]]
    zone_dir = os.path.join(out_dir, "zones")
    ensure_dir(zone_dir)
    master_path = os.path.join(out_dir, "master_mix.ogg")
    fmt = "OGG"
    subtype = "VORBIS"

    writers = {}
    try:
        master = sf.SoundFile(master_path, mode="w", samplerate=SR, channels=1, format=fmt, subtype=subtype)
        for zid in zones:
            writers[zid] = sf.SoundFile(os.path.join(zone_dir, f"{slug(zid)}.ogg"), mode="w", samplerate=SR, channels=1, format=fmt, subtype=subtype)

        block_sec = args.render_block_sec
        t = t0
        idx = 0
        while t < t1:
            y = mix_block(streams, t, block_sec)
            block_end = t + timedelta(seconds=block_sec)
            master.write(y)

            for zid, w in writers.items():
                weight, active = event_weight_for_zone(t, block_end, likelihood_rows, zid)
                if weight <= args.zone_silence_threshold:
                    out = np.zeros_like(y)
                else:
                    out = y * min(1.0, max(0.0, weight))
                w.write(safe(out))

            t += timedelta(seconds=block_sec)
            idx += 1
            if idx % 100 == 0:
                print(f"  [render] {100*(t-t0).total_seconds()/max(1,(t1-t0).total_seconds()):5.1f}% {t:%Y-%m-%d %H:%M:%S}", end="\r")
    finally:
        try:
            master.close()
        except Exception:
            pass
        for w in writers.values():
            try:
                w.close()
            except Exception:
                pass

    print(f"\n[render] wrote {master_path}")
    print(f"[render] wrote zone stems to {zone_dir}")


def draw_map_frame(site, row, frame_path, title):
    fig, ax = plt.subplots(figsize=(9,7))
    b = site["bounds"]
    ax.set_xlim(b["xmin"], b["xmax"])
    ax.set_ylim(b["ymin"], b["ymax"])
    ax.set_aspect("equal", adjustable="box")
    ax.set_facecolor("#f5f5f5")

    # draw zones
    for z in site["zones"]:
        poly = np.array(z["polygon_xy_m"], dtype=float)
        colour = z.get("colour", "#cccccc")
        alpha = 0.25
        prob = 0.0
        if row:
            for lk in row["likelihoods"]:
                if lk["zone_id"] == z["id"]:
                    prob = lk["probability"]
                    break
            alpha = 0.15 + min(0.75, prob * 1.8)
        patch = Polygon(poly, closed=True, facecolor=colour, edgecolor="black", alpha=alpha, linewidth=1.2)
        ax.add_patch(patch)
        cx, cy = z.get("centre_xy_m", [poly[:,0].mean(), poly[:,1].mean()])
        ax.text(cx, cy, z["label"], ha="center", va="center", fontsize=8, wrap=True)

    # draw mics
    for name, m in site_mics(site).items():
        ax.scatter([m["x"]], [m["y"]], s=90, marker="^", c="red", edgecolors="black", zorder=5)
        ax.text(m["x"]+0.3, m["y"]+0.3, name, fontsize=9, color="red")

    if row:
        # top likelihood marker
        top = row["likelihoods"][0]
        ax.scatter([top["x"]], [top["y"]], s=260, c="yellow", edgecolors="red", linewidths=2, zorder=6)
        text = f"{row['center']}\\nEvent: {row['label']}\\nMethod: {row['method']}\\n"
        for lk in row["likelihoods"][:3]:
            text += f"{lk['zone_label']}: {lk['percent']:.1f}%\\n"
        ax.text(0.02, 0.98, text, transform=ax.transAxes, va="top", ha="left",
                bbox=dict(facecolor="white", alpha=0.88, edgecolor="black"), fontsize=9)

    ax.set_title(title)
    ax.set_xlabel("x / local metres")
    ax.set_ylabel("y / local metres")
    fig.tight_layout()
    fig.savefig(frame_path, dpi=130)
    plt.close(fig)


def make_map_video(args, site, likelihood_rows, t0, t1, out_dir):
    video_dir = os.path.join(out_dir, "video")
    frames_dir = os.path.join(video_dir, "frames")
    ensure_dir(frames_dir)
    fps = args.video_fps

    if not likelihood_rows:
        draw_map_frame(site, None, os.path.join(frames_dir, "frame_000000.png"), "V11 zonal map")
    else:
        max_frames = args.max_video_frames
        rows = likelihood_rows
        if len(rows) > max_frames:
            # sample evenly
            idxs = np.linspace(0, len(rows)-1, max_frames).astype(int)
            rows = [likelihood_rows[i] for i in idxs]
        for i, row in enumerate(rows):
            draw_map_frame(site, row, os.path.join(frames_dir, f"frame_{i:06d}.png"), "V11 zonal likelihood map")
            if i % 50 == 0:
                print(f"  [video] frame {i}/{len(rows)}", end="\r")

    mp4 = os.path.join(video_dir, "zonal_map_likelihood.mp4")
    cmd = [
        "ffmpeg", "-y", "-hide_banner", "-loglevel", "error",
        "-framerate", str(fps),
        "-i", os.path.join(frames_dir, "frame_%06d.png"),
        "-c:v", "libx264", "-pix_fmt", "yuv420p", mp4
    ]
    res = subprocess.run(cmd)
    if res.returncode != 0:
        print("[video] ffmpeg failed; PNG frames retained.")
    else:
        print(f"\n[video] wrote {mp4}")
        if not args.keep_frames:
            shutil.rmtree(frames_dir, ignore_errors=True)


def write_manifest(args, site, t0, t1, out_dir):
    manifest = {
        "script": "dual_feed_enhance_v11_zonal_scene.py",
        "yaml": args.yaml,
        "tier": args.tier,
        "start": dt_to_str(t0),
        "end": dt_to_str(t1),
        "site_model": args.site_json,
        "out_dir": out_dir,
        "outputs": {
            "master_mix": "master_mix.ogg",
            "zone_stems": "zones/*.ogg",
            "likelihood_csv": "data/events_zonal_likelihood.csv",
            "likelihood_jsonl": "data/events_zonal_likelihood.jsonl",
            "map_video": "video/zonal_map_likelihood.mp4"
        }
    }
    with open(os.path.join(out_dir, "manifest.json"), "w", encoding="utf-8") as f:
        json.dump(manifest, f, indent=2, sort_keys=True)
    with open(os.path.join(out_dir, "zone_model_used.json"), "w", encoding="utf-8") as f:
        json.dump(site, f, indent=2, sort_keys=True)


def build_parser():
    p = argparse.ArgumentParser(description="V11 zonal forensic scene renderer")
    p.add_argument("--yaml", required=True)
    p.add_argument("--tier", default="amp32")
    p.add_argument("--start")
    p.add_argument("--end")
    p.add_argument("--site-json", required=True)
    p.add_argument("--out-dir", required=True)

    p.add_argument("--scan", action="store_true")
    p.add_argument("--zonal", action="store_true")
    p.add_argument("--render", action="store_true")
    p.add_argument("--video", action="store_true")
    p.add_argument("--all", action="store_true")

    p.add_argument("--dual-cam-a", default="Cam A")
    p.add_argument("--dual-cam-b", default="Cam B")
    p.add_argument("--workers", type=int, default=max(1, (os.cpu_count() or 2)-1))

    p.add_argument("--scan-block-sec", type=float, default=4.0)
    p.add_argument("--scan-hop-sec", type=float, default=2.0)
    p.add_argument("--scan-z", type=float, default=1.6)
    p.add_argument("--min-rms-db", type=float, default=-48.0)
    p.add_argument("--max-scan-threshold-db", type=float, default=-12.0)
    p.add_argument("--min-flux", type=float, default=0.12)
    p.add_argument("--min-tonality", type=float, default=0.10)
    p.add_argument("--min-modulation", type=float, default=0.08)
    p.add_argument("--max-events", type=int, default=0)

    p.add_argument("--max-tdoa-ms", type=float, default=250.0)
    p.add_argument("--zone-temperature", type=float, default=0.65)
    p.add_argument("--zone-silence-threshold", type=float, default=0.04)
    p.add_argument("--render-block-sec", type=float, default=1.0)

    p.add_argument("--video-fps", type=float, default=2.0)
    p.add_argument("--max-video-frames", type=int, default=1200)
    p.add_argument("--keep-frames", action="store_true")
    return p


def main():
    args = build_parser().parse_args()
    ensure_dir(args.out_dir)
    ensure_dir(os.path.join(args.out_dir, "data"))
    ensure_dir(os.path.join(args.out_dir, "zones"))
    ensure_dir(os.path.join(args.out_dir, "video"))

    with open(args.site_json, "r", encoding="utf-8") as f:
        site = json.load(f)

    with open(args.yaml, "r", encoding="utf-8") as f:
        cfg = yaml.safe_load(f) or {}
    starts = [fh.parse_dt(e.get("start")) for e in cfg.get("files", []) if isinstance(e, dict) and e.get("start")]
    starts = [x for x in starts if x]
    if not starts:
        raise SystemExit("No project start times found.")

    t0 = parse_time_arg(args.start, min(starts), min(starts))
    t1 = parse_time_arg(args.end, max(starts)+timedelta(hours=4), min(starts))
    if t1 <= t0:
        raise SystemExit("End must be after start.")

    print("="*76)
    print("V11 Zonal Scene Renderer")
    print(f"YAML   : {args.yaml}")
    print(f"Tier   : {args.tier}")
    print(f"Window : {t0:%Y-%m-%d %H:%M:%S} -> {t1:%Y-%m-%d %H:%M:%S}")
    print(f"Out    : {args.out_dir}")
    print("="*76)

    streams = load_streams(args.yaml, args.tier, t0, t1)
    print(f"[init] stream candidates: {len(streams)}")
    if not streams:
        raise SystemExit("No streams found.")

    do_scan = args.scan or args.all
    do_zonal = args.zonal or args.all
    do_render = args.render or args.all
    do_video = args.video or args.all

    events_path = os.path.join(args.out_dir, "data", "events.jsonl")
    likelihood_path = os.path.join(args.out_dir, "data", "events_zonal_likelihood.jsonl")

    if do_scan:
        events = scan_events(args, streams, t0, t1, args.out_dir)
    else:
        events = [Event(**r) for r in jsonl_read(events_path)]
        print(f"[scan] loaded {len(events)} existing events")

    if do_zonal:
        likelihood_rows = compute_likelihoods(args, events, streams, site, args.out_dir)
    else:
        likelihood_rows = jsonl_read(likelihood_path)
        print(f"[zonal] loaded {len(likelihood_rows)} existing likelihood rows")

    if do_render:
        render_zone_stems(args, streams, site, likelihood_rows, t0, t1, args.out_dir)

    if do_video:
        make_map_video(args, site, likelihood_rows, t0, t1, args.out_dir)

    write_manifest(args, site, t0, t1, args.out_dir)
    print("[done]")


if __name__ == "__main__":
    main()
