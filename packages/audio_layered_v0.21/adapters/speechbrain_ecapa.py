#!/usr/bin/env python3
"""Optional SpeechBrain ECAPA-TDNN adapter for Layered Audio v0.5.

Emits JSON evidence records.  The ooRexx model remains independent of
SpeechBrain/PyTorch and does not treat a thresholded comparison as identity.
Pin the model revision in production and record the exact preprocessing.
"""
import argparse, hashlib, json
from pathlib import Path

DEFAULT_SOURCE = "speechbrain/spkrec-ecapa-voxceleb"

def sha256_file(path):
    h=hashlib.sha256()
    with open(path,"rb") as f:
        for b in iter(lambda:f.read(1024*1024),b""):
            h.update(b)
    return h.hexdigest()

def dependencies():
    import torch
    import torchaudio
    from speechbrain.inference.speaker import SpeakerRecognition, EncoderClassifier
    return torch, torchaudio, SpeakerRecognition, EncoderClassifier

def mono_16k(path, torchaudio):
    signal, fs = torchaudio.load(path)
    if signal.shape[0] > 1:
        signal = signal.mean(dim=0, keepdim=True)
    if fs != 16000:
        signal = torchaudio.functional.resample(signal, fs, 16000)
    return signal

def extract(path, source, savedir):
    torch, torchaudio, _, EncoderClassifier = dependencies()
    model = EncoderClassifier.from_hparams(source=source, savedir=savedir)
    signal = mono_16k(path, torchaudio)
    with torch.inference_mode():
        emb = model.encode_batch(signal).squeeze().detach().cpu().tolist()
    return {
      "schema":"layered_audio.speaker_embedding.v1",
      "model_source":source,
      "input_sha256":sha256_file(path),
      "sample_rate_hz":16000,
      "channel_policy":"MONO_MEAN",
      "embedding_dimension":len(emb),
      "embedding":emb,
    }

def verify(a,b,source,savedir):
    torch, torchaudio, SpeakerRecognition, _ = dependencies()
    # We deliberately normalize inputs ourselves so preprocessing is explicit.
    va=mono_16k(a,torchaudio); vb=mono_16k(b,torchaudio)
    verifier=SpeakerRecognition.from_hparams(source=source,savedir=savedir)
    with torch.inference_mode():
        score,pred=verifier.verify_batch(va,vb)
    return {
      "schema":"layered_audio.speaker_comparison.v1",
      "model_source":source,
      "input_a_sha256":sha256_file(a),
      "input_b_sha256":sha256_file(b),
      "score":float(score.squeeze().cpu()),
      "provider_decision":bool(pred.squeeze().cpu()),
      "metric":"MODEL_PROVIDER_SCORE",
      "note":"Provider decision is model-specific evidence, not an identity assertion.",
    }

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("mode", choices=["extract","verify"])
    ap.add_argument("inputs", nargs="+")
    ap.add_argument("--source", default=DEFAULT_SOURCE)
    ap.add_argument("--savedir", default="pretrained_models/spkrec-ecapa-voxceleb")
    ns=ap.parse_args()
    if ns.mode=="extract" and len(ns.inputs)==1:
        result=extract(ns.inputs[0],ns.source,ns.savedir)
    elif ns.mode=="verify" and len(ns.inputs)==2:
        result=verify(ns.inputs[0],ns.inputs[1],ns.source,ns.savedir)
    else:
        ap.error("extract takes one input; verify takes two")
    print(json.dumps(result,separators=(",",":")))
if __name__=="__main__": main()
