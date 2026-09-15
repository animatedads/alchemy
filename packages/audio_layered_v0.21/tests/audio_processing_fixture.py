from __future__ import annotations
import numpy as np
import soundfile as sf

class SequenceBox:
    def __init__(self, items): self._items=tuple(items)
    def __len__(self): return len(self._items)
    def __getitem__(self, i): return self._items[i]

def shifted_pair(sample_rate=16000, seconds=1.0, shift_samples=80):
    n=int(sample_rate*seconds)
    t=np.arange(n,dtype=np.float32)/sample_rate
    a=(0.25*np.sin(2*np.pi*220*t)+0.13*np.sin(2*np.pi*731*t)+0.07*np.sin(2*np.pi*1267*t)).astype(np.float32)
    a*=np.hanning(n).astype(np.float32)
    b=np.zeros_like(a)
    if shift_samples>=0: b[shift_samples:]=a[:n-shift_samples]
    else:
        s=-shift_samples; b[:n-s]=a[s:]
    return a,b

def shifted_pair_box(sample_rate=16000, seconds=1.0, shift_samples=80):
    return SequenceBox(shifted_pair(sample_rate,seconds,shift_samples))

def noisy_signal(sample_rate=16000, seconds=1.0):
    n=int(sample_rate*seconds)
    t=np.arange(n,dtype=np.float32)/sample_rate
    voice=0.18*np.sin(2*np.pi*180*t)+0.08*np.sin(2*np.pi*360*t)
    hum=0.15*np.sin(2*np.pi*50*t)+0.08*np.sin(2*np.pi*1000*t)
    rng=np.random.default_rng(12345)
    noise=0.03*rng.standard_normal(n)
    return (voice+hum+noise).astype(np.float32)

def coherent_pair(sample_rate=16000, seconds=1.0):
    a=noisy_signal(sample_rate,seconds)
    rng=np.random.default_rng(7)
    b=(a*0.9 + 0.02*rng.standard_normal(a.size)).astype(np.float32)
    return a,b

def coherent_pair_box(sample_rate=16000, seconds=1.0):
    return SequenceBox(coherent_pair(sample_rate,seconds))

def load_stereo_wav(path):
    y,sr=sf.read(path,always_2d=True,dtype='float32')
    if y.shape[1] < 2: raise ValueError('fixture is not stereo')
    return y[:,0].copy(),y[:,1].copy(),int(sr)

def load_stereo_wav_box(path):
    return SequenceBox(load_stereo_wav(path))



def streaming_blocks_box(sample_rate=16000, block_samples=4096, count=4):
    """Deterministic blocks with changing noise character for state tests."""
    sr = int(sample_rate); n = int(block_samples); count = int(count)
    blocks = []
    rng = np.random.default_rng(24680)
    for i in range(count):
        t = (np.arange(n, dtype=np.float32) + i*n) / float(sr)
        speechish = 0.18*np.sin(2*np.pi*220.0*t) + 0.06*np.sin(2*np.pi*440.0*t)
        noise_scale = 0.015 + 0.012*i
        x = speechish + noise_scale*rng.standard_normal(n).astype(np.float32)
        blocks.append(np.asarray(x, dtype=np.float32))
    return SequenceBox(blocks)
