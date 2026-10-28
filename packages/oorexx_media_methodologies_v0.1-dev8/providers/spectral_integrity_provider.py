#!/usr/bin/env python3
"""Media Methodologies adapter for Audio Spectral Integrity v0.2.

This adapter preserves the upstream method semantics.  Odd/even buckets are
complementary views of ONE waveform, not separated sources.  The only two-input
case is the explicit positive-control method, whose inputs are known controls.
"""
from __future__ import annotations
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import sys
import numpy as np
import soundfile as sf

SCHEMA = "media-methodology.provider-result/0.1"
PROVIDER = "media.spectral-integrity-reference/0.1"
METHODS = {
    "AUDIO.SPECTRAL_INTEGRITY.COMPLEMENTARY_BUCKET_VIEWS": "audio-spectral-integrity.numpy-complementary/0.2",
    "AUDIO.SPECTRAL_INTEGRITY.PHASE_SWEEP": "audio-spectral-integrity.numpy-phase-sweep/0.2",
    "AUDIO.SPECTRAL_INTEGRITY.BOUNDED_PREFERENCE_VIEW": "audio-spectral-integrity.numpy-preference/0.2",
    "AUDIO.SPECTRAL_INTEGRITY.HARMONIC_OBSERVATION": "audio-spectral-integrity.numpy-harmonics/0.2",
    "QUAL.AUDIO.SPECTRAL_INTERLEAVE_POSITIVE_CONTROL": "audio-spectral-integrity.numpy-interleave-control/0.2",
}


def dump(path, obj):
    Path(path).write_text(json.dumps(obj, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as fh:
        for block in iter(lambda: fh.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()


def import_upstream(root):
    source = Path(root) / "src" / "spectral_integrity.py"
    if not source.is_file():
        raise FileNotFoundError(f"missing upstream spectral_integrity.py: {source}")
    spec = importlib.util.spec_from_file_location("audio_spectral_integrity_v02", source)
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module, source


def load_audio(path):
    pcm, rate = sf.read(path, always_2d=True, dtype="float64")
    return np.asarray(pcm, dtype=np.float64), int(rate)


def save_pcm24(path, pcm, rate):
    sf.write(path, np.asarray(pcm, dtype=np.float64), rate, subtype="PCM_24")


def source_refs(job, *keys):
    refs = []
    for key in keys:
        ref = str(job.get(key, "")).strip()
        if ref:
            refs.append(ref)
    return refs


def base(job, method, status, upstream_source, refs):
    answer = {
        "schema": SCHEMA,
        "provider_id": PROVIDER,
        "implementation_id": METHODS[method],
        "methodology_id": method,
        "status": status,
        "source_evidence_ref": refs[0] if refs else "",
        "source_evidence_refs": refs,
        "implementation_foundations": [
            "AUDIO_SPECTRAL_INTEGRITY_V0.2",
            "NUMPY_RFFT_FULL_CLIP_MASK_V1",
        ],
        "upstream_source_sha256": sha256(upstream_source),
        "authority": {
            "observation_promotion": False,
            "source_authority_unchanged": True,
            "source_separation_claim": False,
        },
    }
    return answer


def passband_residual(up, pcm, rate, odd, even, ceiling):
    spectrum = np.fft.rfft(pcm, axis=0)
    freqs = np.fft.rfftfreq(pcm.shape[0], d=1.0 / rate)
    passband = np.fft.irfft(spectrum * (freqs < ceiling)[:, None], n=pcm.shape[0], axis=0)
    return float(np.max(np.abs((odd + even) - passband)))


def complementary(job, up, upstream_source, outdir):
    method = "AUDIO.SPECTRAL_INTEGRITY.COMPLEMENTARY_BUCKET_VIEWS"
    source = Path(job["source_wav"])
    pcm, rate = load_audio(source)
    slot = float(job.get("slot_hz", 100))
    ceiling = float(job.get("ceiling_hz", min(8000, rate / 2)))
    offset = float(job.get("offset_hz", 0))
    odd, even = up.rfft_views(pcm, rate, slot, ceiling, offset)
    odd_path, even_path = outdir / "odd.wav", outdir / "even.wav"
    save_pcm24(odd_path, odd, rate); save_pcm24(even_path, even, rate)
    residual = passband_residual(up, pcm, rate, odd, even, ceiling)
    report = outdir / "complementary_views.json"
    metrics = {"slot_hz": slot, "ceiling_hz": ceiling, "offset_hz": offset,
               "reconstruction_max_abs_error": residual, "sample_rate": rate,
               "sample_count": int(pcm.shape[0]), "channels": int(pcm.shape[1])}
    dump(report, {"schema": "media.spectral-integrity.complementary/0.1",
                  "odd_ref": str(odd_path), "even_ref": str(even_path), "metrics": metrics})
    r = base(job, method, "MEASUREMENT", upstream_source, source_refs(job, "source_evidence_ref"))
    r.update({"output_ref": str(report), "uncertainty_ref": "", "metrics": metrics,
              "derived_refs": [str(odd_path), str(even_path)]})
    return r


def phase_sweep(job, up, upstream_source, outdir):
    method = "AUDIO.SPECTRAL_INTEGRITY.PHASE_SWEEP"
    source = Path(job["source_wav"]); pcm, rate = load_audio(source)
    slot = float(job.get("slot_hz", 100)); ceiling = float(job.get("ceiling_hz", min(8000, rate / 2)))
    offsets = tuple(float(x) for x in job.get("offsets_hz", [0, 25, 50, 75]))
    rows = up.bucket_phase_sweep(pcm, rate, slot, ceiling, offsets)
    report = outdir / "phase_sweep.json"
    dump(report, {"schema": "media.spectral-integrity.phase-sweep/0.1", "rows": rows,
                  "slot_hz": slot, "ceiling_hz": ceiling})
    metrics = {"offset_count": len(rows),
               "maximum_reconstruction_error": max((float(x["reconstruction_max_abs_error"]) for x in rows), default=0.0),
               "odd_fraction_range": (max((float(x["odd_power_fraction"]) for x in rows), default=0.0) - min((float(x["odd_power_fraction"]) for x in rows), default=0.0))}
    r = base(job, method, "MEASUREMENT", upstream_source, source_refs(job, "source_evidence_ref"))
    r.update({"output_ref": str(report), "uncertainty_ref": "", "metrics": metrics})
    return r


def preference_view(job, up, upstream_source, outdir):
    method = "AUDIO.SPECTRAL_INTEGRITY.BOUNDED_PREFERENCE_VIEW"
    source = Path(job["source_wav"]); pcm, rate = load_audio(source)
    slot = float(job.get("slot_hz", 100)); ceiling = float(job.get("ceiling_hz", min(8000, rate / 2)))
    offset = float(job.get("offset_hz", 0)); preferred = str(job.get("preferred", "odd")).lower(); relative_db = float(job.get("relative_db", 24))
    odd, even = up.rfft_views(pcm, rate, slot, ceiling, offset)
    candidate, scale = up.preference(odd, even, preferred, relative_db)
    out = outdir / "preference_view.wav"; support = outdir / "support.npy"; uncertainty = outdir / "uncertainty.json"
    save_pcm24(out, candidate, rate)
    np.save(support, np.ones(pcm.shape[0], dtype=np.uint8))
    unc = {"schema": "media.spectral-integrity.preference-uncertainty/0.1",
           "limits": ["derived listening view only", "changed intelligibility is not recovered truth", "FFT rectangular masks introduce ringing"],
           "preferred": preferred, "relative_db": relative_db, "peak_safe_scale": float(scale),
           "slot_hz": slot, "ceiling_hz": ceiling, "offset_hz": offset}
    dump(uncertainty, unc)
    r = base(job, method, "CANDIDATE", upstream_source, source_refs(job, "source_evidence_ref"))
    r.update({"output_ref": str(out), "support_map_ref": str(support), "uncertainty_ref": str(uncertainty),
              "candidate_kind": "DERIVED_LISTENING_VIEW",
              "metrics": {"peak_safe_scale": float(scale), "relative_db": relative_db, "preferred": preferred},
              "implementation_foundations": r["implementation_foundations"] + ["FIXED_RELATIVE_ATTENUATION_V1", "PEAK_SAFE_SCALE_V1"]})
    return r


def harmonic(job, up, upstream_source, outdir):
    method = "AUDIO.SPECTRAL_INTEGRITY.HARMONIC_OBSERVATION"
    if "f0_hz" not in job:
        r = base(job, method, "NOT_APPLICABLE", upstream_source, source_refs(job, "source_evidence_ref"))
        r["reason_code"] = "EXTERNAL_F0_REQUIRED"
        return r
    source = Path(job["source_wav"]); pcm, rate = load_audio(source); f0 = float(job["f0_hz"])
    rows = up.harmonic_observations(pcm, rate, f0,
                                    float(job.get("lo_hz", 200)), float(job.get("hi_hz", min(4000, rate / 2))),
                                    float(job.get("frame_ms", 80)), float(job.get("hop_ms", 20)), float(job.get("tolerance_hz", 20)))
    report = outdir / "harmonic_observations.json"
    dump(report, {"schema": "media.spectral-integrity.harmonics/0.1", "external_f0_hz": f0,
                  "external_f0_ref": str(job.get("external_f0_ref", "")), "rows": rows})
    r = base(job, method, "MEASUREMENT", upstream_source, source_refs(job, "source_evidence_ref", "external_f0_ref"))
    r.update({"output_ref": str(report), "uncertainty_ref": "",
              "metrics": {"observation_count": len(rows), "external_f0_hz": f0},
              "implementation_foundations": r["implementation_foundations"] + ["EXTERNALLY_SEEDED_HARMONIC_OBSERVATION_V1"]})
    return r


def positive_control(job, up, upstream_source, outdir):
    method = "QUAL.AUDIO.SPECTRAL_INTERLEAVE_POSITIVE_CONTROL"
    a_path, b_path = Path(job["source_a_wav"]), Path(job["source_b_wav"])
    a, rate_a = load_audio(a_path); b, rate_b = load_audio(b_path)
    if rate_a != rate_b or a.shape != b.shape:
        raise ValueError("CONTROL_SOURCE_GEOMETRY_MISMATCH")
    slot = float(job.get("slot_hz", 100)); ceiling = float(job.get("ceiling_hz", min(8000, rate_a / 2))); offset = float(job.get("offset_hz", 0))
    woven = up.synthesize_interleaved(a, b, rate_a, slot, ceiling, offset)
    recovered_odd, recovered_even = up.rfft_views(woven, rate_a, slot, ceiling, offset)
    b_odd, _ = up.rfft_views(b, rate_a, slot, ceiling, offset); _, a_even = up.rfft_views(a, rate_a, slot, ceiling, offset)
    odd_error = float(np.max(np.abs(recovered_odd - b_odd))); even_error = float(np.max(np.abs(recovered_even - a_even)))
    composite = outdir / "known_interleave.wav"; save_pcm24(composite, woven, rate_a)
    report = outdir / "positive_control.json"
    metrics = {"odd_assignment_max_abs_error": odd_error, "even_assignment_max_abs_error": even_error,
               "known_truth": True, "slot_hz": slot, "ceiling_hz": ceiling, "offset_hz": offset}
    dump(report, {"schema": "media.spectral-integrity.positive-control/0.1", "composite_ref": str(composite), "metrics": metrics})
    refs = source_refs(job, "source_a_evidence_ref", "source_b_evidence_ref")
    r = base(job, method, "MEASUREMENT", upstream_source, refs)
    r["authority"]["effect"] = "PRESERVE"
    r.update({"output_ref": str(report), "uncertainty_ref": "", "metrics": metrics,
              "derived_refs": [str(composite)], "control_kind": "KNOWN_TWO_INPUT_SPECTRAL_WEAVE"})
    return r


def main():
    ap = argparse.ArgumentParser(); ap.add_argument("--job", required=True); ap.add_argument("--result", required=True); ap.add_argument("--upstream-root", required=True)
    args = ap.parse_args(); job = json.loads(Path(args.job).read_text(encoding="utf-8")); method = str(job.get("methodology_id", "")).upper()
    outdir = Path(job.get("output_dir") or Path(args.result).with_suffix("")); outdir.mkdir(parents=True, exist_ok=True)
    try:
        if method not in METHODS:
            raise ValueError("UNSUPPORTED_METHODOLOGY")
        up, upstream_source = import_upstream(args.upstream_root)
        if method == "AUDIO.SPECTRAL_INTEGRITY.COMPLEMENTARY_BUCKET_VIEWS": result = complementary(job, up, upstream_source, outdir)
        elif method == "AUDIO.SPECTRAL_INTEGRITY.PHASE_SWEEP": result = phase_sweep(job, up, upstream_source, outdir)
        elif method == "AUDIO.SPECTRAL_INTEGRITY.BOUNDED_PREFERENCE_VIEW": result = preference_view(job, up, upstream_source, outdir)
        elif method == "AUDIO.SPECTRAL_INTEGRITY.HARMONIC_OBSERVATION": result = harmonic(job, up, upstream_source, outdir)
        elif method == "QUAL.AUDIO.SPECTRAL_INTERLEAVE_POSITIVE_CONTROL": result = positive_control(job, up, upstream_source, outdir)
        else: raise ValueError("UNSUPPORTED_METHODOLOGY")
    except Exception as exc:
        result = {"schema": SCHEMA, "provider_id": PROVIDER, "implementation_id": METHODS.get(method, ""),
                  "methodology_id": method, "status": "FAILED", "reason_code": "PROVIDER_EXECUTION_FAILED", "detail": str(exc)}
    dump(args.result, result)
    return 0 if result["status"] != "FAILED" else 2


if __name__ == "__main__":
    raise SystemExit(main())
