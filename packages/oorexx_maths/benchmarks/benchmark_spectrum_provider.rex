parse arg provider samples bins
if provider='' then provider='PURE'
if samples='' then samples=1024
if bins='' then bins=16
numeric digits 30
if provider='NUMPY' then ctx=.MathContext~binary64('NUMPY'); else ctx=.MathContext~binary64('PURE')
genctx=.MathContext~binary64('RXMATH')
series=.MathSampledScalarSeries~new(ctx)
pi='3.1415926535897932384626433832795028841971693993751'
do i=0 to samples-1
  t=i/samples
  v=.Maths~sin(2*pi*7*t,genctx)+(0.25*.Maths~cos(2*pi*13*t,genctx))
  series~append(t,v)
end
freqs=.array~new; do f=1 to bins; freqs~append(f); end
reset=time('R')
sp=series~spectrum(freqs)
elapsed=time('E')
checksum=0; do c over sp; checksum=checksum+c~amplitude; end
say provider 'samples='samples 'bins='bins 'elapsed='elapsed 'checksum='checksum
::requires 'MathRxMathProvider.cls'
::requires 'MathNumpyProvider.cls'
