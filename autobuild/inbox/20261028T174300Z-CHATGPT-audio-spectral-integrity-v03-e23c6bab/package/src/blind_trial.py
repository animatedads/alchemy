"""Local, deterministic four-condition blind audition generator.

Never uploads audio. The operator keeps the key privately until observations
are locked. Not an ASR or forensic source-separation detector.
"""
from __future__ import annotations
import argparse
import csv
import hashlib
import json
import os
from pathlib import Path
import numpy as np
from spectral_integrity import control_examples, blind_control_codes, safe_peak_scale


def create_trial(a, b, rate, destination, *, seed=7301, slot_hz=100,
                 ceiling_hz=8000, offset_hz=0, reference_rms=0.10):
    """Four known-source conditions, RMS-matched and bounded below -3 dBFS.

    The only use of fixed RMS is removing a coarse level cue. It does not
    equate perceived loudness, and a different spectrum may remain audible.
    Files contain no spoken-word labels; locked key is separate.
    """
    import soundfile as sf
    if reference_rms <= 0 or reference_rms > 0.25 or not np.isfinite(reference_rms):
        raise ValueError("reference_rms should be finite and within (0,0.25]")
    if not (0 < ceiling_hz <= rate/2):
        raise ValueError("ceiling invalid for sample rate")
    if min(float(np.sqrt(np.mean(np.asarray(z,dtype=np.float64)**2))) for z in (a,b)) < 1e-10:
        raise ValueError("silent source reference")
    conditions = control_examples(a,b,rate,slot_hz,ceiling_hz,offset_hz)
    codes = blind_control_codes(conditions.keys(),seed=seed)
    out = Path(destination)
    out.mkdir(parents=True,exist_ok=True)
    if (out/"PRIVATE_KEY.json").exists() or any(out.glob("T*.flac")):
        raise FileExistsError("trial already exists; choose a fresh directory")
    rows=[]
    for code, condition in sorted(codes.items()):
        x=conditions[condition]
        rms=float(np.sqrt(np.mean(x*x)))
        if rms<1e-10:
            raise ValueError("silent control condition")
        y,scale=safe_peak_scale(x*(reference_rms/rms))
        dest=out / (code+'.flac')
        sf.write(dest,y,rate,subtype='PCM_24')
        rows.append({'code':code,'condition':condition,'input_rms':rms,
                     'output_rms':float(np.sqrt(np.mean(y*y))),
                     'limiter_peak_scale':float(scale),'sha256':hashlib.sha256(dest.read_bytes()).hexdigest()})
    private=out/'PRIVATE_KEY.json'
    fd=os.open(private,os.O_WRONLY|os.O_CREAT|os.O_EXCL,0o600)
    with os.fdopen(fd,'w') as f:
        json.dump({'schema':'audio.spectral-integrity.blind-key/0.3','seed':seed,'rows':rows},f,indent=2)
        f.write('\n')
    public={'schema':'audio.spectral-integrity.blind-presentation/0.3',
            'rate_hz':rate,'channels':np.asarray(a).shape[1],
            'samples':np.asarray(a).shape[0], 'codes':sorted(codes),
            'band_hz':slot_hz,'ceiling_hz':ceiling_hz,
            'offset_hz':offset_hz,'repeated_listening_allowed':True,
            'instruction':'Record free transcription, uncertainty and perceived source count BEFORE unblinding.'}
    (out/'PRESENTATION.json').write_text(json.dumps(public,indent=2)+'\n')
    with (out/'RESPONSES_TEMPLATE.csv').open('w',newline='') as f:
        w=csv.writer(f);w.writerow(['listener_code','clip_code','free_transcription','confidence_0_to_5','perceived_sources','notes_before_unblind'])
    return public


def main(argv=None):
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('source_a');p.add_argument('source_b');p.add_argument('output_dir')
    p.add_argument('--seed',type=int,default=7301)
    p.add_argument('--slot-hz',type=int,default=100)
    p.add_argument('--ceiling-hz',type=int,default=8000)
    p.add_argument('--offset-hz',type=float,default=0)
    args=p.parse_args(argv)
    import soundfile as sf
    a,fs=sf.read(args.source_a,dtype='float64',always_2d=True)
    b,fb=sf.read(args.source_b,dtype='float64',always_2d=True)
    if fs != fb or a.shape != b.shape:
        p.error('sources must be aligned to identical sample-rate, samples and channels')
    result=create_trial(a,b,fs,args.output_dir,seed=args.seed,slot_hz=args.slot_hz,
                        ceiling_hz=args.ceiling_hz,offset_hz=args.offset_hz)
    print(json.dumps(result,indent=2))

if __name__=='__main__': main()
