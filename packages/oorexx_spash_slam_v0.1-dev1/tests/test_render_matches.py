#!/usr/bin/env python3
"""SPASH exact sample interval replay and source-integrity adverse fixtures."""
import hashlib
import tempfile
import sys
import wave
from pathlib import Path
import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
from spash_render_matches import render
from spash_find_similar import search


def wav(path, samples):
    with wave.open(str(path), 'wb') as out:
        out.setnchannels(1)
        out.setsampwidth(2)
        out.setframerate(8000)
        out.writeframes((np.clip(samples, -1, 1) * 32767).astype('<i2').tobytes())


with tempfile.TemporaryDirectory() as td:
    root = Path(td)
    rng = np.random.default_rng(47)
    sr = 8000
    sig = np.zeros(sr * 3)
    for start, freq in ((.4, 430), (1.4, 770), (2.1, 1160)):
        i = int(start * sr)
        n = int(.35 * sr)
        t = np.arange(n) / sr
        sig[i:i+n] = .08 * np.sin(2*np.pi*freq*t) * np.sin(np.pi*np.arange(n)/n)**2
    shifted = rng.normal(0, .00001, 6*sr)
    shifted[2*sr:5*sr] += .7 * sig
    query = root/'q.wav'
    candidate = root/'c.wav'
    wav(query, sig)
    wav(candidate, shifted)
    report = search(query, [candidate], min_score=.8, max_results=3)
    assert report['matches'], 'no synthetic match'
    result = render(report, root/'renders', max_matches=1)
    assert result['schema'] == 'spash.replay.receipt/0.1'
    receipt = result['clips'][0]
    q, c = receipt['query'], receipt['candidate']
    assert q['end_sample_exclusive'] > q['start_sample']
    assert c['end_sample_exclusive'] > c['start_sample']
    assert q['clip_sha256'] == hashlib.sha256((root/'renders'/q['clip']).read_bytes()).hexdigest()
    assert c['clip_sha256'] == hashlib.sha256((root/'renders'/c['clip']).read_bytes()).hexdigest()
    with wave.open(str(root/'renders'/c['clip']),'rb') as clipped:
        with wave.open(str(candidate),'rb') as original:
            original.setpos(c['start_sample'])
            source_bytes = original.readframes(c['end_sample_exclusive'] - c['start_sample'])
        assert clipped.readframes(clipped.getnframes()) == source_bytes
    try:
        render(report, root/'renders', max_matches=1)
        raise AssertionError('existing output should be refused')
    except ValueError as exc:
        assert 'OUTPUT_ALREADY_EXISTS' in str(exc)
    wav(candidate, np.zeros(6*sr))
    try:
        render(report, root/'tamper', max_matches=1)
        raise AssertionError('source hash change should be refused')
    except ValueError as exc:
        assert 'SOURCE_HASH_MISMATCH' in str(exc)
    assert not list((root/'tamper').glob('*.wav'))
    print('SPASH exact partial-replay: 8/8 PASS')
