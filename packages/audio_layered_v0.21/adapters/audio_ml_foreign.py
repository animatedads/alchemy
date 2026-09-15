"""In-process Python implementation helpers for Layered Audio ML.

This module is imported through ooRexx Foreign Runtime v0.22.2 ForeignPython.
It is deliberately *not* a transport/server. Functions may return ordinary Python
collections or resident sequence objects. Layered Audio consumes either through the
v0.22.2 Rexx-native sequence contract (`items`, one-based `[]`/`at`).

Heavy model objects are process-resident and cached by model source/savedir.
"""
from __future__ import annotations

from functools import lru_cache

DEFAULT_ECAPA = "speechbrain/spkrec-ecapa-voxceleb"
DEFAULT_ECAPA_DIR = "pretrained_models/spkrec-ecapa-voxceleb"


def _versions():
    import speechbrain
    import torch
    import torchaudio
    return [
        getattr(speechbrain, "__version__", "unknown"),
        getattr(torch, "__version__", "unknown"),
        getattr(torchaudio, "__version__", "unknown"),
    ]


def runtime_info():
    try:
        sb, torch_v, ta = _versions()
        return ["ok", sb, torch_v, ta]
    except Exception as exc:
        return ["unsupported", f"{type(exc).__name__}: {exc}"]


@lru_cache(maxsize=8)
def _classifier(source: str, savedir: str):
    from speechbrain.inference.speaker import EncoderClassifier
    return EncoderClassifier.from_hparams(source=source, savedir=savedir)


@lru_cache(maxsize=8)
def _verifier(source: str, savedir: str):
    from speechbrain.inference.speaker import SpeakerRecognition
    return SpeakerRecognition.from_hparams(source=source, savedir=savedir)


def _mono16(path: str):
    import torchaudio
    signal, fs = torchaudio.load(path)
    if signal.shape[0] > 1:
        signal = signal.mean(dim=0, keepdim=True)
    if fs != 16000:
        signal = torchaudio.functional.resample(signal, fs, 16000)
    return signal


def speaker_embedding(media_path: str, model_source: str = "", model_dir: str = "", model_revision: str = ""):
    source = model_source or DEFAULT_ECAPA
    savedir = model_dir or DEFAULT_ECAPA_DIR
    revision = model_revision or "UNPINNED"
    try:
        sb_v, torch_v, ta_v = _versions()
        classifier = _classifier(source, savedir)
        signal = _mono16(media_path)
        embedding = classifier.encode_batch(signal).squeeze().detach().cpu().tolist()
        if not isinstance(embedding, list):
            embedding = [float(embedding)]
        embedding = [float(x) for x in embedding]
        return [
            "ok", "SpeechBrain", "ECAPA-TDNN", source, revision,
            16000, "MONO", embedding, sb_v, torch_v, ta_v,
        ]
    except (ModuleNotFoundError, ImportError) as exc:
        return ["unsupported", f"{type(exc).__name__}: {exc}"]
    except Exception as exc:
        # Model acquisition/configuration failure is an unavailable implementation,
        # not a fabricated embedding.
        return ["unavailable", f"{type(exc).__name__}: {exc}"]


def speaker_verify(media_path_a: str, media_path_b: str, model_source: str = "", model_dir: str = "", model_revision: str = "", threshold="PROVIDER_DEFAULT"):
    source = model_source or DEFAULT_ECAPA
    savedir = model_dir or DEFAULT_ECAPA_DIR
    revision = model_revision or "UNPINNED"
    try:
        sb_v, torch_v, ta_v = _versions()
        verifier = _verifier(source, savedir)
        score, prediction = verifier.verify_files(media_path_a, media_path_b)
        score_value = float(score.squeeze().detach().cpu())
        decision = bool(prediction.squeeze().detach().cpu())
        return [
            "ok", source, revision, score_value, decision,
            "MODEL_PROVIDER_SCORE", threshold, sb_v, torch_v, ta_v,
        ]
    except (ModuleNotFoundError, ImportError) as exc:
        return ["unsupported", f"{type(exc).__name__}: {exc}"]
    except Exception as exc:
        return ["unavailable", f"{type(exc).__name__}: {exc}"]
