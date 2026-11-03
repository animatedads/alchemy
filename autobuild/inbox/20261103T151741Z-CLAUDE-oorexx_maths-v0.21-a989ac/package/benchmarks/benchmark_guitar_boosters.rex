parse arg provider samples taps
if provider='' then provider='NUMPY'
if samples='' then samples=2048
if taps='' then taps=256
numeric digits 30
if provider='NUMPY' then ctx=.MathContext~binary64('NUMPY'); else ctx=.MathContext~binary64('PURE')
pi='3.1415926535897932384626433832795028841971693993751'
amps=.array~of(.9,.5,.33,.22,.16,.12)
freqs=.array~of(82.4068892,164.8137784,247.2206676,329.6275568,412.034446,494.4413352)
decays=.array~of(2.8,2.9,3.0,3.1,3.2,3.3)
phases=.array~of(0,0,0,0,0,0)
bank=.Maths~oscillatorBank(amps,freqs,decays,phases,8000,ctx)
reset=time('R'); wave=bank~render(samples); oscElapsed=time('E')
imp=.array~new; do i=0 to taps-1; imp~append((.98**i)); end
h=.MathVector~new(imp,ctx)
reset=time('R'); conv=wave~convolve(h); convElapsed=time('E')
/* FFT only a bounded prefix so PURE direct-DFT benchmark remains practical. */
fftN=min(samples,64); series=.MathSampledScalarSeries~new(ctx)
do i=1 to fftN; series~append((i-1)/8000,wave[i]); end
reset=time('R'); spec=series~rfft; fftElapsed=time('E')
/* Dense modal/state coupling proxy. */
size=64; rows=.array~new; data=.array~new
do i=1 to size
  row=.array~new
  do j=1 to size
    if i=j then v=1.0001
    else v=(i+j)/100000
    row~append(v)
  end
  rows~append(row); data~append(i/1000)
end
m=.MathMatrix~new(rows,ctx); v=.MathVector~new(data,ctx)
reset=time('R'); y=m*v; matElapsed=time('E')
checksum=wave[2]+conv[conv~size]+spec~bin(1)~real+y[1]
say provider 'samples='samples 'taps='taps 'osc='oscElapsed 'conv='convElapsed 'rfft64='fftElapsed 'matvec64='matElapsed 'checksum='checksum
::requires 'MathNumpyProvider.cls'
