#!/usr/bin/env python3
"""Runtime Reference provider for optional Python audio workers.

Wire protocol: runtime.reference/0.1, matching Runtime Reference v0.2 and the
Crypto provider pattern. Heavy libraries are imported lazily, so one resident
service can provide only the operations available in its deployment.

The AcoustID API key is provider-owned (ACOUSTID_API_KEY) and is deliberately
not accepted in operation arguments.
"""
from __future__ import annotations

import argparse
import json
import os
import socketserver
from pathlib import Path

PROTOCOL = "runtime.reference/0.1"
PROVIDER = "python.audio.reference"


def completed(op: str, impl: str, value):
    return {
        "protocol": PROTOCOL,
        "operation": op,
        "status": "completed",
        "provider": PROVIDER,
        "implementation": impl,
        "value": value,
    }


def unsupported(op: str, detail: str):
    return {
        "protocol": PROTOCOL,
        "operation": op,
        "status": "unsupported",
        "provider": PROVIDER,
        "detail": detail,
    }


def media_path(args) -> str:
    path = str(args.get("media_path") or "")
    if not path:
        raise ValueError("media_path is required for this co-resident provider")
    return path


def stub_mode() -> bool:
    return os.environ.get("AUDIO_REFERENCE_TEST_STUB", "") == "1"


def speaker_embedding(op, args):
    if stub_mode():
        return completed(op, "python.audio.stub.embedding/1", {
            "schema": "layered-audio.speaker-embedding.worker.v1",
            "model_provider": "stub",
            "model_family": "TEST",
            "model_source": "test",
            "model_revision": "1",
            "dimension": 3,
            "embedding": [0.25, -0.5, 0.75],
            "sample_rate_hz": 16000,
            "channel_policy": "MONO",
        })
    try:
        import torch
        import torchaudio
        from speechbrain.inference.speaker import EncoderClassifier
    except Exception as exc:
        return unsupported(op, f"SpeechBrain worker unavailable: {type(exc).__name__}")
    path = media_path(args)
    source = str(args.get("model_source") or "speechbrain/spkrec-ecapa-voxceleb")
    savedir = str(args.get("model_dir") or "pretrained_models/spkrec-ecapa-voxceleb")
    classifier = EncoderClassifier.from_hparams(source=source, savedir=savedir)
    signal, fs = torchaudio.load(path)
    if signal.shape[0] > 1:
        signal = signal.mean(dim=0, keepdim=True)
    if fs != 16000:
        signal = torchaudio.functional.resample(signal, fs, 16000)
    emb = classifier.encode_batch(signal).squeeze().detach().cpu().tolist()
    return completed(op, "speechbrain.ecapa.embedding/1", {
        "schema": "layered-audio.speaker-embedding.worker.v1",
        "model_provider": "SpeechBrain",
        "model_family": "ECAPA-TDNN",
        "model_source": source,
        "model_revision": str(args.get("model_revision") or "UNPINNED"),
        "dimension": len(emb),
        "embedding": emb,
        "sample_rate_hz": 16000,
        "channel_policy": "MONO",
    })


def speaker_verify(op, args):
    if stub_mode():
        return completed(op, "python.audio.stub.verify/1", {
            "schema": "layered-audio.speaker-verify.worker.v1",
            "score": 0.73,
            "decision": True,
            "metric": "MODEL_PROVIDER_SCORE",
            "threshold": 0.5,
        })
    try:
        from speechbrain.inference.speaker import SpeakerRecognition
    except Exception as exc:
        return unsupported(op, f"SpeechBrain worker unavailable: {type(exc).__name__}")
    path_a = str(args.get("media_path_a") or "")
    path_b = str(args.get("media_path_b") or "")
    if not path_a or not path_b:
        raise ValueError("media_path_a and media_path_b are required")
    source = str(args.get("model_source") or "speechbrain/spkrec-ecapa-voxceleb")
    savedir = str(args.get("model_dir") or "pretrained_models/spkrec-ecapa-voxceleb")
    verification = SpeakerRecognition.from_hparams(source=source, savedir=savedir)
    score, pred = verification.verify_files(path_a, path_b)
    return completed(op, "speechbrain.ecapa.verify/1", {
        "schema": "layered-audio.speaker-verify.worker.v1",
        "score": float(score.squeeze().cpu()),
        "decision": bool(pred.squeeze().cpu()),
        "metric": "MODEL_PROVIDER_SCORE",
        "threshold": args.get("threshold", "PROVIDER_DEFAULT"),
    })


def music_fingerprint(op, args):
    if stub_mode():
        if str(args.get("media_path") or "") == "invalid-result":
            return completed(op, "python.audio.stub.invalid-fingerprint/1", {"fingerprint": ""})
        return completed(op, "python.audio.stub.chromaprint/1", {
            "schema": "layered-audio.music-fingerprint.worker.v1",
            "algorithm": "CHROMAPRINT",
            "implementation": "stub",
            "duration_seconds": 11.6,
            "fingerprint": "AQABTESTFINGERPRINT",
            "fingerprint_encoding": "CHROMAPRINT_BASE64",
        })
    try:
        import acoustid
    except Exception as exc:
        return unsupported(op, f"pyacoustid worker unavailable: {type(exc).__name__}")
    path = media_path(args)
    duration, fp = acoustid.fingerprint_file(path)
    if isinstance(fp, bytes):
        fp = fp.decode("ascii")
    return completed(op, "chromaprint.pyacoustid.fingerprint/1", {
        "schema": "layered-audio.music-fingerprint.worker.v1",
        "algorithm": "CHROMAPRINT",
        "implementation": "pyacoustid",
        "duration_seconds": float(duration),
        "fingerprint": str(fp),
        "fingerprint_encoding": "CHROMAPRINT_BASE64",
    })


def music_identify(op, args):
    if stub_mode():
        return completed(op, "python.audio.stub.acoustid/1", {
            "schema": "layered-audio.music-identification.worker.v1",
            "provider": "AcoustID",
            "matches": [{"score": 0.91, "track_id": "stub-track"}],
        })
    try:
        import acoustid
    except Exception as exc:
        return unsupported(op, f"pyacoustid worker unavailable: {type(exc).__name__}")
    api_key = os.environ.get("ACOUSTID_API_KEY", "")
    if not api_key:
        return unsupported(op, "ACOUSTID_API_KEY is not configured in provider environment")
    fp = str(args.get("fingerprint") or "")
    duration = args.get("duration_seconds")
    if not fp or duration is None:
        raise ValueError("fingerprint and duration_seconds are required")
    results = []
    for score, recording_id, title, artist in acoustid.lookup(api_key, fp, float(duration), meta="recordings"):
        results.append({
            "score": float(score),
            "recording_id": str(recording_id or ""),
            "title": str(title or ""),
            "artist": str(artist or ""),
        })
    return completed(op, "acoustid.lookup/1", {
        "schema": "layered-audio.music-identification.worker.v1",
        "provider": "AcoustID",
        "matches": results,
    })


def pitch_extract(op, args):
    if stub_mode():
        return completed(op, "python.audio.stub.pitch/1", {
            "schema": "layered-audio.pitch.worker.v1",
            "method": "TEST",
            "observations": [
                {"time_ms": 0, "hz": 220.0, "voiced_probability": 0.95, "confidence": 0.95},
                {"time_ms": 10, "hz": 222.0, "voiced_probability": 0.94, "confidence": 0.94},
            ],
        })
    try:
        import librosa
        import numpy as np
    except Exception as exc:
        return unsupported(op, f"librosa pitch worker unavailable: {type(exc).__name__}")
    path = media_path(args)
    sr = int(args.get("sample_rate_hz") or 16000)
    hop = int(args.get("hop_length") or 160)
    fmin = float(args.get("fmin_hz") or 65.406)
    fmax = float(args.get("fmax_hz") or 2093.0)
    y, sr = librosa.load(path, sr=sr, mono=True)
    f0, voiced, prob = librosa.pyin(y, fmin=fmin, fmax=fmax, sr=sr, hop_length=hop)
    times = librosa.times_like(f0, sr=sr, hop_length=hop)
    observations = []
    for t, hz, vp in zip(times, f0, prob):
        hz_value = None if np.isnan(hz) else float(hz)
        vp_value = 0.0 if np.isnan(vp) else float(vp)
        observations.append({
            "time_ms": int(round(float(t) * 1000.0)),
            "hz": hz_value,
            "voiced_probability": vp_value,
            "confidence": vp_value,
        })
    return completed(op, "librosa.pyin/1", {
        "schema": "layered-audio.pitch.worker.v1",
        "method": "PYIN",
        "sample_rate_hz": sr,
        "hop_length": hop,
        "observations": observations,
    })


DISPATCH = {
    "audio.speaker.embedding.extract/1": speaker_embedding,
    "audio.speaker.verify/1": speaker_verify,
    "audio.music.fingerprint/1": music_fingerprint,
    "audio.music.identify/1": music_identify,
    "audio.pitch.extract/1": pitch_extract,
}


class Handler(socketserver.StreamRequestHandler):
    def handle(self):
        raw = self.rfile.readline(33_554_433)
        if not raw:
            return
        op = ""
        try:
            req = json.loads(raw)
            op = str(req.get("operation") or "")
            if req.get("protocol") != PROTOCOL:
                out = {
                    "protocol": PROTOCOL,
                    "operation": op,
                    "status": "rejected_before_execution",
                    "provider": PROVIDER,
                    "detail": "protocol mismatch",
                }
            else:
                fn = DISPATCH.get(op)
                out = unsupported(op, "operation not implemented") if fn is None else fn(op, req.get("arguments") or {})
        except Exception as exc:
            out = {
                "protocol": PROTOCOL,
                "operation": op,
                "status": "fault",
                "provider": PROVIDER,
                "detail": type(exc).__name__,
            }
        self.wfile.write((json.dumps(out, separators=(",", ":")) + "\n").encode("utf-8"))


class Server(socketserver.ThreadingTCPServer):
    allow_reuse_address = True
    daemon_threads = True


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--host", default="127.0.0.1")
    ap.add_argument("--port", type=int, default=0)
    ap.add_argument("--port-file", required=True)
    ns = ap.parse_args()
    with Server((ns.host, ns.port), Handler) as server:
        Path(ns.port_file).write_text(str(server.server_address[1]), encoding="ascii")
        server.serve_forever()
