#!/usr/bin/env python3
"""Reference adapter for Audio V9 multipath methodologies.

This program delegates acoustic calculations to the qualified Audio V9 binaries.
It does not reimplement their DSP.  It only prepares jobs, records exact output
references and converts provider outcomes to the Media Methodologies result shape.
"""
from __future__ import annotations
import argparse, csv, json, os, pathlib, subprocess, sys

SCHEMA = "media-methodology.provider-result/0.1"
PROVIDER = "reference.audio-v9/0.1"
METHODS = {
    "AUDIO.MULTIPATH.PATH_ESTIMATE": "audio-v9.candidate18r1.multipath-features/0.1",
    "AUDIO.MULTIPATH.SPECTRAL_TRACK": "audio-v9.candidate18r1.multipath-spectral-track/0.1",
    "AUDIO.MULTIPATH.MOTION_COHERENCE": "audio-v9.candidate18r1.motion-coherence-state/0.1",
    "AUDIO.RECON.MULTIPATH_VIRTUAL_MIC": "audio-v9.candidate18r1.echo-reconstruct-nonamp/0.1",
}

def dump(path, obj):
    pathlib.Path(path).write_text(json.dumps(obj, indent=2, sort_keys=True) + "\n")

def run(cmd, stdout_path=None):
    if stdout_path:
        with open(stdout_path, "w", encoding="utf-8", newline="") as f:
            subprocess.run(cmd, check=True, text=True, stdout=f)
    else:
        subprocess.run(cmd, check=True)

def rows(path):
    with open(path, newline="", encoding="utf-8") as f:
        return list(csv.DictReader(f, delimiter="\t"))

def binary(root, name):
    p = pathlib.Path(root) / "build" / name
    if not p.exists():
        raise FileNotFoundError(f"Audio V9 binary missing: {p}")
    return str(p)

def common(job, methodology_id, status):
    return {
        "schema": SCHEMA,
        "provider_id": PROVIDER,
        "implementation_id": METHODS[methodology_id],
        "methodology_id": methodology_id,
        "status": status,
        "source_evidence_ref": str(job.get("source_evidence_ref", "")),
        "authority": {
            "effect": "RECONSTRUCT_CANDIDATE" if methodology_id.startswith("AUDIO.RECON.") else "DERIVED_MEASUREMENT",
            "observation_promotion": False,
            "source_authority_unchanged": True,
        },
    }

def path_estimate(job, root, outdir):
    method = "AUDIO.MULTIPATH.PATH_ESTIMATE"
    source = job["source_f32"]
    onset = int(job["onset_sample"])
    sr = int(job["sample_rate"])
    feed = str(job.get("feed", "FD")).upper()
    out = outdir / "multipath_paths.tsv"
    run([binary(root, "av9_multipath_features"), source, str(onset), str(sr), feed], out)
    rr = rows(out)
    useful = [r for r in rr if r.get("path_class") == "USEFUL_COHERENT_REFLECTION"]
    uncertainty = outdir / "multipath_uncertainty.json"
    dump(uncertainty, {
        "schema": "media-methodologies.audio-v9-uncertainty/0.1",
        "methodology_id": method,
        "useful_path_count": len(useful),
        "candidate_row_count": len(rr),
        "limits": ["excess-path timing only", "not source range", "periodic-source ambiguity possible"],
    })
    result = common(job, method, "MEASUREMENT" if useful else "NOT_APPLICABLE")
    result.update({
        "output_ref": str(out),
        "uncertainty_ref": str(uncertainty),
        "metrics": {
            "useful_path_count": len(useful),
            "candidate_row_count": len(rr),
            "useful_delays_ms": [float(r["delay_ms"]) for r in useful],
        },
    })
    if not useful:
        result["reason_code"] = "NO_USEFUL_COHERENT_PATH"
    return result

def virtual_mic(job, root, outdir):
    method = "AUDIO.RECON.MULTIPATH_VIRTUAL_MIC"
    # Re-run the path estimator from the same source/onset so selection and
    # reconstruction share one explicitly recorded foundation.
    paths_result = path_estimate(job, root, outdir)
    if paths_result["status"] == "NOT_APPLICABLE":
        result = common(job, method, "NOT_APPLICABLE")
        result["reason_code"] = "NO_USEFUL_COHERENT_PATH"
        result["shared_foundation_ref"] = paths_result["output_ref"]
        return result
    source = job["source_f32"]
    paths = paths_result["output_ref"]
    out = outdir / "virtual_mic_nonamp.f32"
    report = outdir / "virtual_mic_report.tsv"
    run([binary(root, "av9_echo_reconstruct"), source, paths, "nonamp", str(out)], report)
    support = outdir / "virtual_mic_support.tsv"
    pathlib.Path(support).write_text(pathlib.Path(paths).read_text())
    uncertainty = outdir / "virtual_mic_uncertainty.json"
    useful_count = int(paths_result["metrics"]["useful_path_count"])
    dump(uncertainty, {
        "schema": "media-methodologies.audio-v9-uncertainty/0.1",
        "methodology_id": method,
        "shared_foundation": "AUDIO.MULTIPATH.PATH_ESTIMATE",
        "useful_path_count": useful_count,
        "limits": [
            "derived candidate, not original waveform",
            "path-estimator and reconstruction are not independent evidence",
            "non-amplifying branch only",
        ],
    })
    result = common(job, method, "CANDIDATE")
    result.update({
        "output_ref": str(out),
        "support_map_ref": str(support),
        "uncertainty_ref": str(uncertainty),
        "shared_foundation_ref": paths_result["output_ref"],
        "metrics": {"useful_path_count": useful_count},
    })
    return result

def spectral_track(job, root, outdir):
    method = "AUDIO.MULTIPATH.SPECTRAL_TRACK"
    source = job["source_f32"]
    sr = int(job["sample_rate"])
    feed = str(job.get("feed", "FD")).upper()
    start = int(job["start_sample"]); end = int(job["end_sample"])
    frame_ms = str(job.get("frame_ms", 24)); step_ms = str(job.get("step_ms", 20))
    out = outdir / "multipath_spectral_track.tsv"
    run([binary(root, "av9_multipath_spectral_track"), source, str(start), str(end), str(sr), feed, frame_ms, step_ms], out)
    rr = rows(out)
    useful = [r for r in rr if r.get("path_class") == "USEFUL_COHERENT_REFLECTION"]
    tids = sorted({r.get("trajectory_id", "") for r in rr})
    stable = sum(r.get("spectral_stability_class") == "STABLE_TRANSFER" for r in rr)
    uncertainty = outdir / "spectral_track_uncertainty.json"
    dump(uncertainty, {
        "schema": "media-methodologies.audio-v9-uncertainty/0.1",
        "methodology_id": method,
        "row_count": len(rr), "trajectory_count": len(tids), "useful_row_count": len(useful),
        "limits": ["trajectory identity may fail at path crossings", "spectral transfer is not source identity"],
    })
    result = common(job, method, "MEASUREMENT" if rr else "NOT_APPLICABLE")
    result.update({"output_ref": str(out), "uncertainty_ref": str(uncertainty),
                   "metrics": {"row_count": len(rr), "trajectory_count": len(tids), "useful_row_count": len(useful), "stable_transfer_rows": stable}})
    if not rr: result["reason_code"] = "INSUFFICIENT_TRAJECTORY_SUPPORT"
    return result

def motion_coherence(job, root, outdir):
    method = "AUDIO.MULTIPATH.MOTION_COHERENCE"
    obs = job["observations_tsv"]
    prior = str(job.get("prior_state_tsv", "-"))
    state = outdir / "motion_coherence_state.tsv"
    report = outdir / "motion_coherence_report.tsv"
    run([binary(root, "av9_motion_coherence_state"), prior, obs, str(state), str(report)])
    rr = rows(report)
    result = common(job, method, "MEASUREMENT" if rr else "NOT_APPLICABLE")
    result.update({"output_ref": str(report), "continuation_state_ref": str(state),
                   "metrics": rr[0] if rr else {}})
    if not rr: result["reason_code"] = "INSUFFICIENT_TRAJECTORY_SUPPORT"
    return result

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--job", required=True); ap.add_argument("--result", required=True); ap.add_argument("--audio-v9-root", required=True)
    args=ap.parse_args()
    job=json.load(open(args.job)); method=str(job.get("methodology_id", "")).upper()
    outdir=pathlib.Path(job.get("output_dir") or pathlib.Path(args.result).with_suffix("")); outdir.mkdir(parents=True,exist_ok=True)
    try:
        if method == "AUDIO.MULTIPATH.PATH_ESTIMATE": result=path_estimate(job,args.audio_v9_root,outdir)
        elif method == "AUDIO.RECON.MULTIPATH_VIRTUAL_MIC": result=virtual_mic(job,args.audio_v9_root,outdir)
        elif method == "AUDIO.MULTIPATH.SPECTRAL_TRACK": result=spectral_track(job,args.audio_v9_root,outdir)
        elif method == "AUDIO.MULTIPATH.MOTION_COHERENCE": result=motion_coherence(job,args.audio_v9_root,outdir)
        else:
            result={"schema":SCHEMA,"provider_id":PROVIDER,"implementation_id":"","methodology_id":method,"status":"FAILED","reason_code":"UNSUPPORTED_METHODOLOGY"}
    except (KeyError, ValueError, FileNotFoundError, subprocess.CalledProcessError) as exc:
        result={"schema":SCHEMA,"provider_id":PROVIDER,"implementation_id":METHODS.get(method,""),"methodology_id":method,"status":"FAILED","reason_code":"PROVIDER_EXECUTION_FAILED","detail":str(exc)}
    dump(args.result,result)
    return 0 if result["status"] != "FAILED" else 2

if __name__ == "__main__": raise SystemExit(main())
