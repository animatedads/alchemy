import torch
from adapters.audio_asr_foreign import diagnostics, speech_regions, prepare_region

sr=16000
x=torch.zeros(1,4*sr)
# low background plus two synthetic speech-like islands
x += 0.003 * torch.randn_like(x)
x[:,int(.8*sr):int(1.8*sr)] += 0.08*torch.sin(torch.arange(int(1.0*sr))*2*torch.pi*220/sr)
x[:,int(2.4*sr):int(3.2*sr)] += 0.06*torch.sin(torch.arange(int(.8*sr))*2*torch.pi*180/sr)
d=diagnostics(x,sr)
assert d['samples']==4*sr
r=speech_regions(x,sr)
assert len(r)>=1
for q in r:
    assert 0 <= q['start_sample'] < q['end_sample'] <= 4*sr
y=prepare_region(x,r[0]['start_sample'],r[0]['end_sample'],sr)
assert y.ndim==2 and y.shape[0]==1 and y.numel()>0
assert float(y.abs().max()) <= .951
print('ASR PREPARATION: OK regions=%d' % len(r))
