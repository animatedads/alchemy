#!/usr/bin/env python3
"""
dual_feed_enhance_v10_geo_scene.py
==================================
V10 map-grounded acoustic scene mapper.

Stages:
  --scan       detect loud/structured events
  --classify   classify events deterministically or with OpenAI/DeepThought
  --locate     estimate event source zone/distance/angle using a site model
  --render     suppress nuisance event windows and protect useful/unknown events
  --all        scan + classify + locate + render

Requires:
  forensic_helper.py beside this script or on PYTHONPATH.

Example:
  python dual_feed_enhance_v10_geo_scene.py \
    --yaml rehab_project.yaml --tier amp32 \
    --start "2023-10-10 00:00:01" --end "2023-10-11 00:00:01" \
    --site-json rehab_group20_site_model.json \
    --locate-cam "Cam A" --ai-provider none --all \
    --out rehab/v10_geo_scene.ogg
"""

from __future__ import annotations

import argparse, base64, csv, json, math, os, re, sys, concurrent.futures
from dataclasses import dataclass, asdict
from datetime import datetime, timedelta
from typing import Any, Dict, Iterable, List, Optional, Tuple

import numpy as np
import soundfile as sf
import librosa
from scipy import signal
from scipy.ndimage import uniform_filter1d
import yaml

from forensic_helper import ForensicHelper as fh

SR = 22050
N_FFT = 2048
HOP_LENGTH = N_FFT // 4
SPEED_OF_SOUND = 343.0

SUPPRESS_CLASSES = {
    "aircon": 18, "fan": 15, "electrical_hum": 24, "car": 12,
    "motorbike": 12, "cat": 10, "dog": 8, "alarm": 18, "siren": 18,
    "rain": 10, "wind": 10, "music": 10, "radio": 10
}
PROTECT_CLASSES = {
    "speech": 10, "voice": 10, "conversation": 10,
    "footstep": 4, "door": 3, "impact": 3, "unknown_structured": 5
}
CLASS_BANDS = {
    "cat": [(650, 5200)], "dog": [(250, 3000)], "car": [(20, 450)],
    "motorbike": [(30, 900)], "aircon": [(40, 500), (900, 2400)],
    "fan": [(40, 600)], "electrical_hum": [(45, 65), (95, 125), (145, 185), (195, 245)],
    "alarm": [(700, 4500)], "siren": [(450, 5200)], "rain": [(1200, 9000)],
    "wind": [(20, 700)], "music": [(60, 8000)], "radio": [(250, 5000)],
    "speech": [(120, 6500)], "voice": [(120, 6500)], "conversation": [(120, 6500)],
    "unknown_structured": [(100, 6500)]
}

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
class GeoEstimate:
    event_id: str
    site: str
    source_x: float
    source_y: float
    source_z: float
    direct_distance_m: float
    azimuth_deg: float
    zone: str
    confidence: float
    observed_echo_ms: List[float]
    predicted_echo_ms: Dict[str, float]
    top_candidates: List[Dict[str, Any]]
    locate_cam: str

def safe(y):
    return np.nan_to_num(y, nan=0.0, posinf=0.0, neginf=0.0).astype(np.float32, copy=False)

def pad_or_trim(y, n):
    y = safe(y)
    return y[:n] if len(y) >= n else np.pad(y, (0, n-len(y))).astype(np.float32)

def rms_db(y):
    y = safe(y)
    return 20.0 * math.log10(max(float(np.sqrt(np.mean(y*y) + 1e-12)), 1e-12))

def dt_to_str(dt):
    return dt.strftime("%Y-%m-%d %H:%M:%S.%f")[:-3]

def str_to_dt(s):
    for fmt in ("%Y-%m-%d %H:%M:%S.%f", "%Y-%m-%d %H:%M:%S"):
        try: return datetime.strptime(s, fmt)
        except ValueError: pass
    if "." in s:
        a,b=s.split(".",1); return datetime.strptime(a+"."+((b+"000000")[:6]), "%Y-%m-%d %H:%M:%S.%f")
    raise ValueError(s)

def ensure_parent(path):
    p = os.path.dirname(os.path.abspath(path))
    if p: os.makedirs(p, exist_ok=True)

def jsonl_write(path, rows):
    ensure_parent(path)
    with open(path, "w", encoding="utf-8") as f:
        for r in rows: f.write(json.dumps(r, ensure_ascii=False, sort_keys=True)+"\n")

def jsonl_read(path):
    if not os.path.exists(path): return []
    with open(path, "r", encoding="utf-8") as f:
        return [json.loads(x) for x in f if x.strip()]

def project_id_from_yaml(yaml_path):
    return os.path.splitext(os.path.basename(yaml_path))[0]

def parse_time_arg(s, default_dt, project_date=None):
    if not s: return default_dt
    p = fh.parse_dt(s)
    if p: return p
    base = project_date or default_dt
    p = fh.parse_dt(f"{base:%Y-%m-%d} {s}:00")
    if p: return p
    raise ValueError(f"Could not parse time: {s!r}")

def active_streams_at(streams, t):
    return [s for s in streams if s["start_dt"] <= t < s["end_dt"]]

def choose_channels(active):
    out = {}
    for s in sorted(active, key=lambda x: x["start_dt"]):
        out[s.get("cam_id", "Unknown")] = s
    return out

def load_project_streams(yaml_path, tier, t0, t1):
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
            if ok: keep.append(s)
        raw = keep
    raw.sort(key=lambda x: (x["start_dt"], x.get("cam_id",""), x.get("path","")))
    return raw

def spectral_features(y):
    y = safe(y)
    if not np.any(y):
        return dict(peak_hz=0.0, spectral_flux=0.0, tonality=0.0, harmonicity=0.0, modulation_2_8hz=0.0, low_rumble=0.0)
    S = librosa.stft(y, n_fft=N_FFT, hop_length=HOP_LENGTH)
    mag = np.abs(S) + 1e-12
    freqs = librosa.fft_frequencies(sr=SR, n_fft=N_FFT)
    mean_spec = np.mean(mag, axis=1)
    peak_hz = float(freqs[int(np.argmax(mean_spec))])
    flux = float(np.mean(np.maximum(np.diff(mag, axis=1), 0.0)) / (np.mean(mag)+1e-12))
    tonality = float(np.clip((np.max(mean_spec)/(np.median(mean_spec)+1e-12))/60.0, 0, 1))
    spec = mean_spec / (np.max(mean_spec)+1e-12)
    ac = np.correlate(spec, spec, mode="full")[len(spec)-1:]
    harmonicity = float(np.clip((np.max(ac[3:min(len(ac),120)])/(ac[0]+1e-12))*5.0,0,1)) if len(ac)>5 else 0.0
    env = librosa.feature.rms(S=mag)[0]
    frame_rate = SR / HOP_LENGTH
    if len(env) > 24 and np.max(env) > 1e-10:
        try:
            b,a = signal.butter(2, [2/(frame_rate/2), 8/(frame_rate/2)], btype="band")
            mod = signal.filtfilt(b,a,env)
            modulation = float(np.clip(np.sqrt(np.mean(mod*mod))/(np.mean(env)+1e-12)/1.5,0,1))
        except Exception:
            modulation = 0.0
    else:
        modulation = 0.0
    low = mean_spec[(freqs>=20)&(freqs<=250)].sum()
    total = mean_spec[(freqs>=20)&(freqs<=9000)].sum() + 1e-12
    return dict(peak_hz=peak_hz, spectral_flux=flux, tonality=tonality,
                harmonicity=harmonicity, modulation_2_8hz=modulation, low_rumble=float(np.clip(low/total,0,1)))

def deterministic_label_from_features(f):
    peak=f.get("peak_hz",0); ton=f.get("tonality",0); harm=f.get("harmonicity",0); mod=f.get("modulation_2_8hz",0); rum=f.get("low_rumble",0); flux=f.get("spectral_flux",0)
    if mod > 0.35 and 120 <= peak <= 4500: return "speech",0.45,"speech-like syllabic modulation"
    if rum > 0.55 and peak < 350: return "car",0.42,"low-frequency rumble dominance"
    if ton > 0.5 and 700 <= peak <= 4500: return "alarm",0.42,"narrow tonal peak in alarm band"
    if harm > 0.45 and 600 <= peak <= 5200: return "cat",0.35,"harmonic high-frequency event"
    if flux > 0.8: return "impact",0.35,"high spectral flux transient"
    return "unknown_structured",0.25,"deterministic fallback"

def default_site_profile():
    return {
        "name":"rehab_group20_default",
        "bounds":{"xmin":0.0,"xmax":52.0,"ymin":0.0,"ymax":46.0},
        "building_wall_height_m":15.0,
        "candidate_source_heights_m":[1.2,1.7,2.5],
        "grid_step_m":2.0,
        "mic":{"x":5.0,"y":8.0,"z":8.5,"label":"Balcony mono microphone"},
        "walls":[
            {"name":"west_building_face","axis":"x","value":0.0},
            {"name":"east_building_face","axis":"x","value":52.0},
            {"name":"south_building_face","axis":"y","value":0.0},
            {"name":"north_building_face","axis":"y","value":46.0}
        ],
        "zones":{"interior_margin_m":7.0,"north_label":"north_building_edge","south_label":"south_building_edge","west_label":"west_building_edge","east_label":"east_building_edge","interior_label":"group20_park_interior"}
    }

def load_site_model(args):
    if args.site_json:
        with open(args.site_json,"r",encoding="utf-8") as f: site=json.load(f)
    else:
        site=default_site_profile()
    if args.mic_x is not None: site.setdefault("mic",{})["x"]=float(args.mic_x)
    if args.mic_y is not None: site.setdefault("mic",{})["y"]=float(args.mic_y)
    if args.mic_z is not None: site.setdefault("mic",{})["z"]=float(args.mic_z)
    if args.grid_step is not None: site["grid_step_m"]=float(args.grid_step)
    if args.source_height is not None: site["candidate_source_heights_m"]=[float(args.source_height)]
    return site

def site_candidate_grid(site):
    b=site["bounds"]; step=float(site.get("grid_step_m",2.0))
    xs=np.arange(b["xmin"]+step/2,b["xmax"],step); ys=np.arange(b["ymin"]+step/2,b["ymax"],step)
    zs=[float(z) for z in site.get("candidate_source_heights_m",[1.5])]
    return [(float(x),float(y),float(z)) for z in zs for y in ys for x in xs]

def classify_zone(site,x,y):
    b=site["bounds"]; m=float(site.get("zones",{}).get("interior_margin_m",7.0)); z=site.get("zones",{})
    if x <= b["xmin"]+m: return z.get("west_label","west_edge")
    if x >= b["xmax"]-m: return z.get("east_label","east_edge")
    if y <= b["ymin"]+m: return z.get("south_label","south_edge")
    if y >= b["ymax"]-m: return z.get("north_label","north_edge")
    return z.get("interior_label","interior")

def direct_distance(site,x,y,z):
    m=site["mic"]; return float(np.sqrt((x-m["x"])**2+(y-m["y"])**2+(z-m["z"])**2))

def azimuth_deg(site,x,y):
    m=site["mic"]; return float(math.degrees(math.atan2(y-m["y"], x-m["x"])))

def reflection_delays_ms(site,x,y,z):
    m=site["mic"]; d0=direct_distance(site,x,y,z); out={}
    for w in site.get("walls",[]):
        if w["axis"]=="x": xi,yi,zi=2*float(w["value"])-x,y,z
        else: xi,yi,zi=x,2*float(w["value"])-y,z
        dr=float(np.sqrt((xi-m["x"])**2+(yi-m["y"])**2+(zi-m["z"])**2))
        out[str(w["name"])]=max(0.0,(dr-d0)/SPEED_OF_SOUND*1000.0)
    zi=-z
    dr=float(np.sqrt((x-m["x"])**2+(y-m["y"])**2+(zi-m["z"])**2))
    out["ground"]=max(0.0,(dr-d0)/SPEED_OF_SOUND*1000.0)
    return out

def site_mics(site):
    """
    Return a dict of microphone positions.

    Supported site model forms:
      "mics": {"Cam A": {"x":..,"y":..,"z":..}, "Cam B": {...}}
      "mic_a" / "mic_b"
      fallback: single "mic"
    """
    if isinstance(site.get("mics"), dict) and site["mics"]:
        return site["mics"]

    mics = {}
    if isinstance(site.get("mic_a"), dict):
        mics["Cam A"] = site["mic_a"]
    if isinstance(site.get("mic_b"), dict):
        mics["Cam B"] = site["mic_b"]

    if mics:
        return mics

    if isinstance(site.get("mic"), dict):
        return {"Cam A": site["mic"]}

    return {}


def distance_from_point_to_mic(x, y, z, mic):
    return float(np.sqrt((x - float(mic["x"]))**2 + (y - float(mic["y"]))**2 + (z - float(mic.get("z", 1.5)))**2))


def predicted_tdoa_samples(site, cam_a, cam_b, x, y, z):
    mics = site_mics(site)
    if cam_a not in mics or cam_b not in mics:
        return None
    da = distance_from_point_to_mic(x, y, z, mics[cam_a])
    db = distance_from_point_to_mic(x, y, z, mics[cam_b])
    # Positive means source reaches B later than A in this script's convention.
    return (db - da) / SPEED_OF_SOUND * SR


def gcc_phat_lag_conf(y_a, y_b, max_delay_sec=0.25):
    y_a = safe(y_a)
    y_b = safe(y_b)
    if not np.any(y_a) or not np.any(y_b):
        return 0, 0.0

    n = len(y_a) + len(y_b) - 1
    nfft = 1 << int(np.ceil(np.log2(max(n, 2))))
    A = np.fft.rfft(y_a, n=nfft)
    B = np.fft.rfft(y_b, n=nfft)
    R = A * np.conj(B)
    cc = np.fft.irfft(R / (np.abs(R) + 1e-10), n=nfft)

    max_lag = int(max_delay_sec * SR)
    search = np.concatenate([cc[-max_lag:], cc[:max_lag + 1]])
    abs_search = np.abs(search)
    idx = int(np.argmax(abs_search))
    lag = idx - max_lag
    peak = float(abs_search[idx])
    med = float(np.median(abs_search) + 1e-12)
    conf = peak / med
    return int(lag), float(conf)

def envelope_lag_conf(y_a, y_b, max_delay_sec=0.25):
    """
    Envelope/onset lag for tonal or repeating alarms.

    Positive lag means Cam B envelope appears later than Cam A, matching the
    convention used by gcc_phat_lag_conf().
    """
    y_a = safe(y_a)
    y_b = safe(y_b)
    if not np.any(y_a) or not np.any(y_b):
        return 0, 0.0

    n = min(len(y_a), len(y_b))
    y_a = y_a[:n]
    y_b = y_b[:n]

    try:
        ea = np.abs(signal.hilbert(y_a))
        eb = np.abs(signal.hilbert(y_b))

        # Smooth enough to follow claxon/siren amplitude pulses rather than carrier phase.
        kernel = max(5, int(0.015 * SR) | 1)
        ea = signal.medfilt(ea, kernel_size=kernel)
        eb = signal.medfilt(eb, kernel_size=kernel)

        ea = (ea - np.mean(ea)) / (np.std(ea) + 1e-9)
        eb = (eb - np.mean(eb)) / (np.std(eb) + 1e-9)

        corr = signal.correlate(ea, eb, mode="full")
        lags = np.arange(-len(eb) + 1, len(ea))
        max_lag = int(max_delay_sec * SR)
        mask = np.abs(lags) <= max_lag
        sub = corr[mask]
        sub_lags = lags[mask]

        idx = int(np.argmax(sub))
        lag = int(sub_lags[idx])
        peak = float(sub[idx])
        med = float(np.median(np.abs(sub)) + 1e-12)
        conf = abs(peak) / med
        return lag, conf
    except Exception:
        return 0, 0.0


def estimate_tonality_for_tdoa(y):
    """
    Cheap carrier-tonality score for deciding whether GCC-PHAT is trustworthy.
    Values near 1 mean narrowband/tonal, where GCC can lock to a carrier cycle.
    """
    y = safe(y)
    if not np.any(y):
        return 0.0
    try:
        S = librosa.stft(y, n_fft=N_FFT, hop_length=HOP_LENGTH)
        mag = np.abs(S) + 1e-12
        mean_spec = np.mean(mag, axis=1)
        peakiness = np.max(mean_spec) / (np.median(mean_spec) + 1e-12)
        return float(np.clip(peakiness / 60.0, 0.0, 1.0))
    except Exception:
        return 0.0


def choose_tdoa_measurement(y_a, y_b, max_delay_sec=0.25, event_label=""):
    """
    Class-aware TDOA selection.

    - Broadband/transient/speech-like events: prefer GCC-PHAT.
    - Tonal/repeating alarms/sirens/claxons: prefer envelope lag.
    - If GCC says near-zero with absurdly high confidence on a tonal event,
      treat that as suspicious carrier lock and use envelope lag.
    """
    gcc_lag, gcc_conf = gcc_phat_lag_conf(y_a, y_b, max_delay_sec=max_delay_sec)
    env_lag, env_conf = envelope_lag_conf(y_a, y_b, max_delay_sec=max_delay_sec)

    tone_a = estimate_tonality_for_tdoa(y_a)
    tone_b = estimate_tonality_for_tdoa(y_b)
    tonality = max(tone_a, tone_b)

    label = str(event_label or "").lower()
    tonal_class = any(k in label for k in ["alarm", "siren", "claxon", "klaxon", "horn", "tone"])

    suspicious_zero_carrier_lock = (
        tonality >= 0.35
        and abs(gcc_lag) <= 2
        and gcc_conf >= 30.0
        and abs(env_lag) > int(0.010 * SR)
        and env_conf >= 3.0
    )

    if tonal_class or suspicious_zero_carrier_lock:
        chosen = {
            "method": "envelope_lag",
            "lag_samples": int(env_lag),
            "confidence": float(env_conf),
            "reason": "tonal/repeating event: envelope lag preferred over carrier GCC-PHAT",
        }
    else:
        chosen = {
            "method": "gcc_phat",
            "lag_samples": int(gcc_lag),
            "confidence": float(gcc_conf),
            "reason": "broadband/transient event: GCC-PHAT preferred",
        }

    return {
        "chosen": chosen,
        "gcc_phat": {"lag_samples": int(gcc_lag), "confidence": float(gcc_conf)},
        "envelope": {"lag_samples": int(env_lag), "confidence": float(env_conf)},
        "tonality": float(tonality),
        "tonal_class_hint": bool(tonal_class),
        "suspicious_zero_carrier_lock": bool(suspicious_zero_carrier_lock),
    }


def load_calibration_hints(path):
    """
    Load optional known-event calibration JSONs produced by calibrate_tdoa_event.py.

    The current use is conservative: store hints in the output manifest and use
    known labels to make the TDOA method class-aware. It does not automatically
    move microphone coordinates yet.
    """
    if not path:
        return []
    hints = []
    for item in str(path).split(","):
        item = item.strip()
        if not item:
            continue
        try:
            with open(item, "r", encoding="utf-8") as f:
                hints.append(json.load(f))
        except Exception as e:
            print(f"[calibration] could not read {item}: {e}")
    return hints


def dual_event_audio(event, streams, cam_a="Cam A", cam_b="Cam B", extra=1.0, max_sec=8.0):
    cen = str_to_dt(event.center)
    dur = max(1.0, min(max_sec, (str_to_dt(event.end)-str_to_dt(event.start)).total_seconds()+extra))
    start = cen - timedelta(seconds=dur/2)
    n = int(dur * SR)
    active = choose_channels(active_streams_at(streams, cen))
    if cam_a not in active or cam_b not in active:
        return None
    ya = pad_or_trim(fh.read_stream_block(active[cam_a], start, dur, SR), n)
    yb = pad_or_trim(fh.read_stream_block(active[cam_b], start, dur, SR), n)
    return cam_a, cam_b, ya, yb, active[cam_a].get("path"), active[cam_b].get("path")


def dual_geo_score_candidate(observed_lag, lag_conf, observed_echo_ms, predicted_echo_ms, predicted_lag, direct_m):
    """
    Combined dual-mic + echo score.

    TDOA dominates if confidence is usable. Echo model remains as a weak prior.
    """
    sc = 0.0

    if predicted_lag is not None and lag_conf > 4.0:
        sigma_samples = 18.0 if lag_conf >= 10.0 else 35.0
        err = float(observed_lag - predicted_lag)
        sc += min(3.0, lag_conf / 8.0) * math.exp(-(err*err)/(2*sigma_samples*sigma_samples))

    # Echo weak prior.
    sc += 0.35 * geo_score(observed_echo_ms, predicted_echo_ms, direct_m)

    # Gentle distance prior.
    sc *= 1.0 / (1.0 + 0.012 * direct_m)
    return float(sc)

def scan_events(args, streams, t0, t1):
    block_sec=float(args.scan_block_sec); hop_sec=float(args.scan_hop_sec); n=int(block_sec*SR)
    metrics=[]; t=t0; idx=0
    print("[scan] measuring acoustic activity")
    while t < t1:
        active=choose_channels(active_streams_at(streams,t)); blocks=[]; sources=[]
        for cam,s in sorted(active.items()):
            y=pad_or_trim(fh.read_stream_block(s,t,block_sec,SR),n)
            if np.any(y):
                blocks.append(y); sources.append(os.path.basename(s.get("path","")))
        if blocks:
            mix=np.mean(np.vstack(blocks),axis=0); rd=rms_db(mix); feats=spectral_features(mix)
        else:
            rd=-120.0; feats=spectral_features(np.zeros(n,dtype=np.float32))
        metrics.append(dict(idx=idx,t=t,rms_db=rd,features=feats,channels=sorted(active.keys()),source_files=sorted(set(sources))))
        idx+=1; t+=timedelta(seconds=hop_sec)
        if idx % 500 == 0: print(f"  [scan] {idx} hops at {t:%Y-%m-%d %H:%M:%S}", end="\r")
    if not metrics: return []
    vals=np.array([m["rms_db"] for m in metrics],float); med=float(np.median(vals)); mad=float(np.median(np.abs(vals-med)))
    sigma=max(1.4826*mad,2.5); raw=med+float(args.scan_z)*sigma
    threshold=max(float(args.min_rms_db), min(raw, float(args.max_scan_threshold_db)))
    print(f"\n[scan] median={med:.1f} dB, sigma={sigma:.1f}, raw={raw:.1f}, threshold={threshold:.1f}")
    flags=[]
    for m in metrics:
        f=m["features"]
        structured=f["spectral_flux"]>args.min_flux or f["tonality"]>args.min_tonality or f["harmonicity"]>args.min_harmonicity or f["modulation_2_8hz"]>args.min_modulation
        flags.append(bool(m["rms_db"]>=threshold and structured and m["channels"]))
    events=[]; i=0; num=0
    while i < len(metrics):
        if not flags[i]: i+=1; continue
        j=i
        while j+1 < len(metrics) and flags[j+1]: j+=1
        group=metrics[max(0,i-1):min(len(metrics),j+2)]
        st=group[0]["t"]; en=group[-1]["t"]+timedelta(seconds=block_sec); cen=st+(en-st)/2
        best=max(group,key=lambda x:x["rms_db"]); f=best["features"]
        events.append(Event(f"evt_{num:06d}",dt_to_str(st),dt_to_str(en),dt_to_str(cen),
                            sorted(set(c for g in group for c in g["channels"])),float(f["peak_hz"]),
                            float(best["rms_db"]),float((best["rms_db"]-med)/sigma),float(f["spectral_flux"]),
                            float(f["tonality"]),float(f["harmonicity"]),float(f["modulation_2_8hz"]),
                            float(f["low_rumble"]),sorted(set(x for g in group for x in g["source_files"]))))
        num+=1; i=j+1
    if args.max_events and len(events)>args.max_events:
        events.sort(key=lambda e:(e.z_rms,e.tonality+e.harmonicity+e.modulation_2_8hz), reverse=True)
        events=events[:args.max_events]; events.sort(key=lambda e:e.start)
    out=args.events_file or f"{args.pid}_v10_events.jsonl"
    jsonl_write(out,[asdict(e) for e in events])
    print(f"[scan] wrote {len(events)} events to {out}")
    return events

def choose_loc_stream(active, locate_cam):
    if not active: return None,None
    if locate_cam:
        for c,s in active.items():
            if c.lower()==locate_cam.lower(): return c,s
    c=sorted(active.keys())[0]; return c,active[c]

def event_audio(event, streams, locate_cam, extra=1.0, max_sec=8.0):
    cen=str_to_dt(event.center); dur=max(1.0,min(max_sec,(str_to_dt(event.end)-str_to_dt(event.start)).total_seconds()+extra))
    start=cen-timedelta(seconds=dur/2); n=int(dur*SR)
    active=choose_channels(active_streams_at(streams,cen)); cam,s=choose_loc_stream(active, locate_cam)
    if s is None: return "unknown", np.zeros(n,dtype=np.float32), None
    return cam, pad_or_trim(fh.read_stream_block(s,start,dur,SR), n), s.get("path")

def write_event_snippet(event, streams, snippet_dir, margin, max_sec, locate_cam):
    os.makedirs(snippet_dir, exist_ok=True)
    cam,y,src=event_audio(event,streams,locate_cam,extra=2*margin,max_sec=max_sec)
    out=os.path.join(snippet_dir,f"{event.event_id}.wav")
    sf.write(out,y,SR,subtype="PCM_16")
    return out

def load_policy(args):
    path=args.policy_file or f"{args.pid}_v10_policy.json"
    if os.path.exists(path):
        with open(path,"r",encoding="utf-8") as f: return json.load(f)
    pol=dict(suppress_classes=SUPPRESS_CLASSES,protect_classes=PROTECT_CLASSES,class_bands=CLASS_BANDS,
             ignore_zones=[z.strip() for z in (args.ignore_zones or "").split(",") if z.strip()],
             protect_zones=[z.strip() for z in (args.protect_zones or "group20_park_interior").split(",") if z.strip()],
             never_hard_delete=True,max_suppression_db=24,preserve_unknown=True)
    with open(path,"w",encoding="utf-8") as f: json.dump(pol,f,indent=2,sort_keys=True)
    return pol

def read_key(provider):
    fn="openai_key.txt" if provider=="openai" else f"{provider}_key.txt"
    try: return open(fn,"r",encoding="utf-8").read().strip()
    except Exception: return ""

def extract_json(text):
    text=(text or "").strip().replace("```json","").replace("```","").strip()
    try: return json.loads(text)
    except Exception: pass
    m=re.search(r"\{.*\}",text,flags=re.S)
    if m: return json.loads(m.group(0))
    raise ValueError(text[:200])

def classify_events(args, streams):
    rows=jsonl_read(args.events_file or f"{args.pid}_v10_events.jsonl"); events=[Event(**r) for r in rows]
    if not events: print("[classify] no events"); return []
    pol=load_policy(args); existing=jsonl_read(args.classes_file or f"{args.pid}_v10_ai_classes.jsonl")
    done={r["event_id"] for r in existing if "event_id" in r}; out=args.classes_file or f"{args.pid}_v10_ai_classes.jsonl"
    pending=[e for e in events if e.event_id not in done]; pending.sort(key=lambda e:e.z_rms, reverse=True)
    if args.max_ai_events: pending=pending[:args.max_ai_events]
    print(f"[classify] existing={len(done)} pending={len(pending)} provider={args.ai_provider}")
    for i,e in enumerate(pending,1):
        raw=None
        try:
            if args.ai_provider=="openai":
                import requests
                key=read_key("openai")
                if not key: raise RuntimeError("Missing openai_key.txt")
                snip=write_event_snippet(e,streams,args.snippet_dir or f"{args.pid}_v10_snippets",args.snippet_margin_sec,args.snippet_max_sec,args.locate_cam)
                content=[{"type":"text","text":f"Classify this forensic audio event. Return JSON only with class, confidence, suppress, protect, reason. Features: {asdict(e)}"}]
                with open(snip,"rb") as f: content.append({"type":"input_audio","input_audio":{"data":base64.b64encode(f.read()).decode(),"format":"wav"}})
                resp=requests.post("https://api.openai.com/v1/chat/completions",
                    headers={"Authorization":f"Bearer {key}","Content-Type":"application/json"},
                    json={"model":args.openai_model,"messages":[{"role":"user","content":content}],"temperature":0.1,"response_format":{"type":"json_object"}},timeout=60)
                resp.raise_for_status(); raw=extract_json(resp.json()["choices"][0]["message"]["content"])
            else:
                lab,conf,reason=deterministic_label_from_features(asdict(e))
                raw={"class":lab,"confidence":conf,"suppress":lab in SUPPRESS_CLASSES,"protect":lab in PROTECT_CLASSES or lab.startswith("unknown"),"reason":reason}
        except Exception as exc:
            lab,conf,reason=deterministic_label_from_features(asdict(e))
            raw={"class":lab,"confidence":conf,"suppress":lab in SUPPRESS_CLASSES,"protect":lab in PROTECT_CLASSES or lab.startswith("unknown"),"reason":f"AI failed: {exc}; {reason}"}
        label=str(raw.get("class","unknown_structured")).lower().replace(" ","_")
        suppress=bool(raw.get("suppress", label in SUPPRESS_CLASSES)); protect=bool(raw.get("protect", label in PROTECT_CLASSES or label.startswith("unknown")))
        if label in {"speech","voice","conversation","unknown_structured"}: suppress=False; protect=True
        cls=Classification(e.event_id,label,float(np.clip(float(raw.get("confidence",0.25) or 0.25),0,1)),suppress,protect,str(raw.get("reason","")),args.ai_provider,raw)
        with open(out,"a",encoding="utf-8") as f: f.write(json.dumps(asdict(cls),ensure_ascii=False,sort_keys=True)+"\n")
        print(f"  [classify] {i}/{len(pending)} {e.event_id}: {cls.label} conf={cls.confidence:.2f}")
    return jsonl_read(out)

def detect_echo_delays_ms(y, max_ms=180.0, top_n=5):
    y=safe(y); delays=[]
    if not np.any(y): return []
    try:
        onset=librosa.onset.onset_strength(y=y,sr=SR)
        if len(onset)>8 and np.max(onset)>1e-12:
            max_size=int(max_ms/1000*SR/HOP_LENGTH)
            ac=librosa.autocorrelate(onset,max_size=max_size); ac[:max(1,int(0.010*SR/HOP_LENGTH))]=0
            peaks,_=signal.find_peaks(ac,distance=2,prominence=np.max(ac)*0.06)
            delays += [float(p*HOP_LENGTH/SR*1000) for p in sorted(peaks,key=lambda p:ac[p],reverse=True)[:top_n]]
    except Exception: pass
    delays=[d for d in delays if 10 <= d <= max_ms]; delays.sort()
    merged=[]
    for d in delays:
        if not merged or abs(d-merged[-1])>4: merged.append(d)
    return merged[:top_n]

def geo_score(obs, pred, dist):
    vals=[v for v in pred.values() if v>0]
    if not obs or not vals: return 0.1/(1+0.03*dist)
    sigma=8.0; sc=0.0
    for o in obs[:4]:
        err=abs(min(vals,key=lambda p:abs(p-o))-o)
        sc += math.exp(-(err*err)/(2*sigma*sigma))
    return float(sc/(1+0.025*dist))

def locate_one_event_geo(event, args, streams, site, classes, cands):
    """
    Locate one event.

    If the project has two active streams and the site model has matching mic
    positions, use dual-mic TDOA + echo. Otherwise use mono echo-map fallback.
    """
    cls_hint = classes.get(event.event_id, {})
    label_hint = str(cls_hint.get("label", ""))

    # Try dual first.
    dual = dual_event_audio(event, streams, args.dual_cam_a, args.dual_cam_b, extra=2.0, max_sec=8.0)
    use_dual = False
    observed_lag = 0
    lag_conf = 0.0
    tdoa_debug = {}
    cam_label = args.locate_cam or args.dual_cam_a
    source_files = ""

    if dual is not None:
        cam_a, cam_b, ya, yb, path_a, path_b = dual
        mics = site_mics(site)
        if cam_a in mics and cam_b in mics:
            tdoa_debug = choose_tdoa_measurement(
                ya, yb,
                max_delay_sec=args.max_tdoa_ms / 1000.0,
                event_label=label_hint
            )
            observed_lag = int(tdoa_debug["chosen"]["lag_samples"])
            lag_conf = float(tdoa_debug["chosen"]["confidence"])
            use_dual = lag_conf >= args.min_tdoa_conf
            cam_label = f"{cam_a}+{cam_b}"
            source_files = f"{os.path.basename(path_a or '')};{os.path.basename(path_b or '')}"
            # Use stronger channel as echo source for reflection matching.
            y_for_echo = ya if rms_db(ya) >= rms_db(yb) else yb
        else:
            y_for_echo = ya
    else:
        cam, y_for_echo, path = event_audio(event, streams, args.locate_cam, extra=2.0, max_sec=8.0)
        cam_label = cam
        source_files = os.path.basename(path) if path else ""

    observed = detect_echo_delays_ms(y_for_echo, args.max_echo_ms, 5)

    ranked = []
    for x, y0, z in cands:
        pred = reflection_delays_ms(site, x, y0, z)
        d = direct_distance(site, x, y0, z)

        if use_dual:
            pred_lag = predicted_tdoa_samples(site, args.dual_cam_a, args.dual_cam_b, x, y0, z)
            sc = dual_geo_score_candidate(observed_lag, lag_conf, observed, pred, pred_lag, d)
        else:
            pred_lag = None
            sc = geo_score(observed, pred, d)

        ranked.append((sc, (x, y0, z), pred, d, pred_lag))

    ranked.sort(key=lambda r: r[0], reverse=True)
    sc, (x, y0, z), pred, d, pred_lag = ranked[0]
    second = ranked[1][0] if len(ranked) > 1 else 0.0
    conf = float(sc / (sc + second + 1e-9))

    top = []
    for a, b, pp, dd, pl in ranked[:args.geo_top_k]:
        top.append(dict(
            score=float(a),
            x=float(b[0]), y=float(b[1]), z=float(b[2]),
            distance_m=float(dd),
            zone=classify_zone(site, b[0], b[1]),
            azimuth_deg=azimuth_deg(site, b[0], b[1]),
            predicted_tdoa_samples=None if pl is None else float(pl),
            predicted_echo_ms=pp
        ))

    est = GeoEstimate(
        event.event_id,
        site.get("name", "site"),
        float(x), float(y0), float(z),
        float(d),
        azimuth_deg(site, x, y0),
        classify_zone(site, x, y0),
        conf,
        [float(v) for v in observed],
        {k: float(v) for k, v in pred.items()},
        top,
        cam_label
    )

    cls = classes.get(event.event_id, {})
    csvrow = dict(
        event_id=event.event_id,
        time=event.center,
        label=cls.get("label", ""),
        class_conf=cls.get("confidence", ""),
        locate_cam=cam_label,
        method=("dual_" + tdoa_debug.get("chosen", {}).get("method", "tdoa") + "_echo") if use_dual else "mono_echo_map",
        observed_tdoa_samples=observed_lag if use_dual else "",
        tdoa_confidence=round(lag_conf, 3) if use_dual else "",
        gcc_lag_samples=tdoa_debug.get("gcc_phat", {}).get("lag_samples", "") if tdoa_debug else "",
        gcc_confidence=round(tdoa_debug.get("gcc_phat", {}).get("confidence", 0.0), 3) if tdoa_debug else "",
        envelope_lag_samples=tdoa_debug.get("envelope", {}).get("lag_samples", "") if tdoa_debug else "",
        envelope_confidence=round(tdoa_debug.get("envelope", {}).get("confidence", 0.0), 3) if tdoa_debug else "",
        tdoa_tonality=round(tdoa_debug.get("tonality", 0.0), 3) if tdoa_debug else "",
        suspicious_zero_carrier_lock=tdoa_debug.get("suspicious_zero_carrier_lock", "") if tdoa_debug else "",
        source_x_m=round(x, 2),
        source_y_m=round(y0, 2),
        source_z_m=round(z, 2),
        distance_m=round(d, 2),
        azimuth_deg=round(est.azimuth_deg, 1),
        zone=est.zone,
        geo_confidence=round(conf, 3),
        observed_echo_ms=";".join(f"{v:.1f}" for v in observed),
        source_file=source_files
    )
    return est, csvrow


def locate_events(args, streams, site):
    events = [Event(**r) for r in jsonl_read(args.events_file or f"{args.pid}_v10_events.jsonl")]
    classes = {r["event_id"]: r for r in jsonl_read(args.classes_file or f"{args.pid}_v10_ai_classes.jsonl") if "event_id" in r}
    cands = site_candidate_grid(site)

    estimates = []
    csvrows = []

    workers = max(1, int(args.workers or 1))
    print(f"[locate] events={len(events)} candidates={len(cands)} workers={workers}")

    if workers == 1:
        for i, e in enumerate(events, 1):
            est, row = locate_one_event_geo(e, args, streams, site, classes, cands)
            estimates.append(est)
            csvrows.append(row)
            if i % 100 == 0:
                print(f"  [locate] {i}/{len(events)}", end="\r")
    else:
        # Threaded rather than process-based because helper reads are I/O-heavy
        # and because streams/site objects are easy to share.
        with concurrent.futures.ThreadPoolExecutor(max_workers=workers) as ex:
            futs = [ex.submit(locate_one_event_geo, e, args, streams, site, classes, cands) for e in events]
            for i, fut in enumerate(concurrent.futures.as_completed(futs), 1):
                est, row = fut.result()
                estimates.append(est)
                csvrows.append(row)
                if i % 50 == 0:
                    print(f"  [locate] {i}/{len(events)}", end="\r")

    estimates.sort(key=lambda e: e.event_id)
    csvrows.sort(key=lambda r: r["event_id"])

    out = args.geo_file or f"{args.pid}_v10_geo.json"
    with open(out, "w", encoding="utf-8") as f:
        json.dump(dict(
            project=args.pid,
            site=site,
            created_at=datetime.now().isoformat(timespec="seconds"),
            geo_estimates=[asdict(e) for e in estimates]
        ), f, indent=2, sort_keys=True)

    csvp = args.geo_csv or f"{args.pid}_v10_geo.csv"
    with open(csvp, "w", newline="", encoding="utf-8") as f:
        if csvrows:
            w = csv.DictWriter(f, fieldnames=list(csvrows[0].keys()))
            w.writeheader()
            w.writerows(csvrows)

    print(f"\n[locate] wrote {out}\n[locate] wrote {csvp}")

def attenuation_mask(block_start,block_end,events,classes,geo,policy,n_frames,freqs):
    mask=np.ones((len(freqs),n_frames),np.float32); dur=max(1e-6,(block_end-block_start).total_seconds())
    ignore=set(policy.get("ignore_zones",[]) or []); max_s=float(policy.get("max_suppression_db",24))
    for e in events:
        e0=str_to_dt(e.start); e1=str_to_dt(e.end)
        if e1<block_start or e0>block_end: continue
        cls=classes.get(e.event_id); g=geo.get(e.event_id,{})
        label=cls.label if cls else ""; suppress=(cls.suppress if cls else False) or str(g.get("zone","")) in ignore
        if not suppress: continue
        db=min(float(policy.get("suppress_classes",SUPPRESS_CLASSES).get(label,8)),max_s)
        gain=10**(-db/20)
        f0=max(0,min(n_frames-1,int(((max(block_start,e0)-block_start).total_seconds()/dur)*n_frames)))
        f1=max(f0+1,min(n_frames,int(math.ceil(((min(block_end,e1)-block_start).total_seconds()/dur)*n_frames))))
        for lo,hi in (policy.get("class_bands",CLASS_BANDS).get(label) or [(80,6500)]):
            band=(freqs>=float(lo))&(freqs<=float(hi))
            mask[band,f0:f1]=np.minimum(mask[band,f0:f1],gain)
    if mask.shape[1]>3: mask=uniform_filter1d(mask,size=3,axis=1)
    if mask.shape[0]>5: mask=uniform_filter1d(mask,size=5,axis=0)
    return np.clip(mask,10**(-max_s/20),1)

def render_scene(args, streams, t0, t1):
    events=[Event(**r) for r in jsonl_read(args.events_file or f"{args.pid}_v10_events.jsonl")]
    classes={r["event_id"]:Classification(**r) for r in jsonl_read(args.classes_file or f"{args.pid}_v10_ai_classes.jsonl") if "event_id" in r}
    geo={}
    gj=args.geo_file or f"{args.pid}_v10_geo.json"
    if os.path.exists(gj):
        data=json.load(open(gj,"r",encoding="utf-8"))
        geo={r["event_id"]:r for r in data.get("geo_estimates",[])}
    policy=load_policy(args)
    out=args.out or f"{args.pid}_v10_geo_scene.ogg"; ensure_parent(out)
    block_sec=float(args.render_block_sec); hop_sec=float(args.render_hop_sec)
    bs=int(block_sec*SR); hs=int(hop_sec*SR); win=signal.windows.hann(bs,sym=False).astype(np.float32)
    ola=np.zeros(bs*2,np.float32); ow=np.zeros(bs*2,np.float32); freqs=librosa.fft_frequencies(sr=SR,n_fft=N_FFT)
    fmt="OGG" if out.lower().endswith(".ogg") else None; subtype="VORBIS" if fmt=="OGG" else None
    t=t0; blocks=0
    with sf.SoundFile(out,mode="w",samplerate=SR,channels=1,format=fmt,subtype=subtype) as out_f:
        while t<t1:
            active=choose_channels(active_streams_at(streams,t)); ys=[]
            for cam,s in sorted(active.items())[:2]: ys.append(pad_or_trim(fh.read_stream_block(s,t,block_sec,SR),bs))
            mix=fh.generate_comfort_noise(bs,db=-60).astype(np.float32) if not ys else ys[0] if len(ys)==1 else 0.5*ys[0]+0.5*ys[1]
            be=t+timedelta(seconds=block_sec); loc=[e for e in events if str_to_dt(e.end)>=t and str_to_dt(e.start)<=be]
            S=librosa.stft(safe(mix),n_fft=N_FFT,hop_length=HOP_LENGTH)
            y=librosa.istft(S*attenuation_mask(t,be,loc,classes,geo,policy,S.shape[1],freqs),hop_length=HOP_LENGTH,length=bs)
            peak=np.max(np.abs(y))
            if peak>1: y=y/peak*0.98
            ola[:bs]+=safe(y)*win; ow[:bs]+=win
            chunk=ola[:hs]/np.maximum(ow[:hs],1e-8); out_f.write(safe(chunk))
            ola[:bs]=ola[hs:hs+bs]; ola[bs:]=0; ow[:bs]=ow[hs:hs+bs]; ow[bs:]=0
            t+=timedelta(seconds=hop_sec); blocks+=1
            if blocks%100==0: print(f"  [render] {100*(t-t0).total_seconds()/max(1,(t1-t0).total_seconds()):5.1f}% {t:%Y-%m-%d %H:%M:%S}",end="\r")
    man=f"{args.pid}_v10_geo_manifest.json"
    json.dump(dict(project=args.pid,yaml=args.yaml,tier=args.tier,start=dt_to_str(t0),end=dt_to_str(t1),out=out,site_json=args.site_json,created_at=datetime.now().isoformat(timespec="seconds")),open(man,"w",encoding="utf-8"),indent=2,sort_keys=True)
    print(f"\n[render] wrote {out}\n[render] wrote {man}")

def build_parser():
    p=argparse.ArgumentParser(description="V10 geo-aware acoustic scene mapper")
    p.add_argument("--yaml",required=True); p.add_argument("--tier",default="amp32"); p.add_argument("--start"); p.add_argument("--end"); p.add_argument("--out")
    p.add_argument("--scan",action="store_true"); p.add_argument("--classify",action="store_true"); p.add_argument("--locate",action="store_true"); p.add_argument("--render",action="store_true"); p.add_argument("--all",action="store_true")
    p.add_argument("--events-file"); p.add_argument("--classes-file"); p.add_argument("--geo-file"); p.add_argument("--geo-csv"); p.add_argument("--policy-file"); p.add_argument("--snippet-dir")
    p.add_argument("--scan-block-sec",type=float,default=4.0); p.add_argument("--scan-hop-sec",type=float,default=2.0); p.add_argument("--scan-z",type=float,default=1.6)
    p.add_argument("--min-rms-db",type=float,default=-48.0); p.add_argument("--max-scan-threshold-db",type=float,default=-12.0)
    p.add_argument("--min-flux",type=float,default=0.12); p.add_argument("--min-tonality",type=float,default=0.10); p.add_argument("--min-harmonicity",type=float,default=0.10); p.add_argument("--min-modulation",type=float,default=0.08); p.add_argument("--max-events",type=int,default=0)
    p.add_argument("--ai-provider",default="none",choices=["openai","deepthought","none"]); p.add_argument("--openai-model",default=os.environ.get("OPENAI_AUDIO_MODEL","gpt-4o-audio-preview")); p.add_argument("--max-ai-events",type=int,default=250); p.add_argument("--snippet-margin-sec",type=float,default=2.0); p.add_argument("--snippet-max-sec",type=float,default=10.0)
    p.add_argument("--site-json"); p.add_argument("--locate-cam")
    p.add_argument("--workers", type=int, default=max(1, (os.cpu_count() or 2)-1), help="Worker threads for localisation")
    p.add_argument("--dual-cam-a", default="Cam A", help="First mic/camera name for dual TDOA localisation")
    p.add_argument("--dual-cam-b", default="Cam B", help="Second mic/camera name for dual TDOA localisation")
    p.add_argument("--max-tdoa-ms", type=float, default=250.0, help="Maximum dual-mic TDOA search window in ms")
    p.add_argument("--min-tdoa-conf", type=float, default=6.0, help="Minimum GCC-PHAT confidence before using dual TDOA")
    p.add_argument("--calibration-json", help="Optional calibration JSON(s) from calibrate_tdoa_event.py, comma-separated")
    p.add_argument("--mic-x",type=float); p.add_argument("--mic-y",type=float); p.add_argument("--mic-z",type=float); p.add_argument("--grid-step",type=float); p.add_argument("--source-height",type=float); p.add_argument("--max-echo-ms",type=float,default=180.0); p.add_argument("--geo-top-k",type=int,default=5)
    p.add_argument("--ignore-zones"); p.add_argument("--protect-zones",default="group20_park_interior")
    p.add_argument("--render-block-sec",type=float,default=8.0); p.add_argument("--render-hop-sec",type=float,default=4.0)
    return p

def main():
    args=build_parser().parse_args(); args.pid=project_id_from_yaml(args.yaml)
    cfg=yaml.safe_load(open(args.yaml,"r",encoding="utf-8")) or {}
    starts=[fh.parse_dt(e.get("start")) for e in cfg.get("files",[]) if isinstance(e,dict) and e.get("start")]
    starts=[x for x in starts if x]
    if not starts: raise SystemExit("No start times in YAML")
    t0=parse_time_arg(args.start,min(starts),min(starts)); t1=parse_time_arg(args.end,max(starts)+timedelta(hours=4),min(starts))
    if t1<=t0: raise SystemExit("End time must be after start")
    print("="*76); print("V10 Geo Acoustic Scene Mapper"); print(f"Project : {args.pid}\nTier    : {args.tier}\nWindow  : {t0:%Y-%m-%d %H:%M:%S} -> {t1:%Y-%m-%d %H:%M:%S}"); print("="*76)
    streams=load_project_streams(args.yaml,args.tier,t0,t1)
    if not streams: raise SystemExit(f"No streams found for tier={args.tier!r}")
    print(f"[init] active stream candidates: {len(streams)}")
    site=load_site_model(args); print(f"[site] {site.get('name')} mic=({site['mic']['x']:.1f}, {site['mic']['y']:.1f}, {site['mic']['z']:.1f})")
    args.calibration_hints = load_calibration_hints(args.calibration_json)
    if args.calibration_hints:
        print(f"[calibration] loaded {len(args.calibration_hints)} known-event calibration hint(s)")
    if not any([args.scan,args.classify,args.locate,args.render,args.all]): print("No action selected."); return
    if args.scan or args.all: scan_events(args,streams,t0,t1)
    if args.classify or args.all: classify_events(args,streams)
    if args.locate or args.all: locate_events(args,streams,site)
    if args.render or args.all: render_scene(args,streams,t0,t1)

if __name__ == "__main__":
    main()
