numeric digits 50
assertions=0
ctx=.MathContext~binary64('NUMPY')

n=2000
a=.array~new; b=.array~new
do i=1 to n; a~append(i/10); b~append((n-i)/7); end
va=.MathVector~new(a,ctx); vb=.MathVector~new(b,ctx)
vc=va+vb
call check vc~backendProvider='NUMPY','NumPy vector result retains resident backend'; assertions+=1
call near vc[1],a[1]+b[1],'1E-12','NumPy vector add first'; assertions+=1
call near vc[n],a[n]+b[n],'1E-12','NumPy vector add last'; assertions+=1
p=vc~prove(.MathClaim~independentlyReproduced('1E-11'))
call check p~outcome='PROVED','NumPy vector add independently reproduced'; assertions+=1
call check p~verificationEvidence~primaryProvider='PURE','NumPy vector proof uses independent PURE provider'; assertions+=1
vd=vc*2
call check vd~backendProvider='NUMPY','resident NumPy vector reused for chained scale'; assertions+=1
call near vd[100],2*vc[100],'1E-11','NumPy chained scale'; assertions+=1
vh=va~hadamard(vb)
call near vh[55],a[55]*b[55],'1E-10','NumPy hadamard'; assertions+=1
dot=va*vb
pureDot=.MathVector~new(a,.MathContext~binary64('PURE'))*.MathVector~new(b,.MathContext~binary64('PURE'))
call near dot,pureDot,'1E-6','NumPy native dot agrees with PURE represented-value dot'; assertions+=1

series=.MathSampledScalarSeries~new(ctx)
pi='3.1415926535897932384626433832795028841971693993751'
count=1024
freq=7
do i=0 to count-1
  t=i/count
  series~append(t,.Maths~sin(2*pi*freq*t,.MathContext~binary64('RXMATH')))
end
call near series~mean,0,'2E-15','NumPy series mean'; assertions+=1
call near series~rms,'0.7071067811865475','3E-15','NumPy series RMS'; assertions+=1
comp=series~fourierComponent(freq)
call near comp~amplitude,1,'3E-15','NumPy Fourier amplitude'; assertions+=1
call near comp~cosineComponent,0,'3E-14','NumPy Fourier cosine component'; assertions+=1
call near comp~sineComponent,1,'3E-15','NumPy Fourier sine component'; assertions+=1
call check comp~evidence~primaryProvider='NUMPY','NumPy Fourier evidence provider'; assertions+=1
proof=comp~prove(.MathClaim~independentlyReproduced('1E-12'))
call check proof~outcome='PROVED','NumPy Fourier independently reproduced at higher precision'; assertions+=1
call check proof~verificationEvidence~primaryProvider='REFERENCE','Fourier proof switches provider'; assertions+=1
freqs=.array~of(5,7,9)
sp=series~spectrum(freqs)
call check sp~items=3,'NumPy multi-frequency spectrum count'; assertions+=1
call near sp[2]~amplitude,1,'3E-15','NumPy multi-frequency spectrum reuses native input arrays'; assertions+=1
call check sp[2]~evidence~steps[1]~algorithm='numpy-vectorized-fourier-projection-reused-input','spectrum records reused-input native algorithm'; assertions+=1

/* AUTO binary64 picks NumPy for vector/series when registered. */
auto=.MathContext~binary64('AUTO')
x=.MathVector~new(.array~of(1,2,3),auto)+.MathVector~new(.array~of(4,5,6),auto)
call check x~evidence~primaryProvider='NUMPY','AUTO binary64 vector selects NumPy'; assertions+=1

say 'PASS oorexx_maths extended NumPy native' assertions 'assertions'
exit 0
check: procedure
  parse arg condition,label
  if \condition then do; say 'FAIL' label; exit 1; end
  say 'PASS' label
  return
near: procedure
  parse arg actual,expected,tol,label
  numeric digits 50
  if (actual-expected)~abs>tol then do; say 'FAIL' label 'actual='actual 'expected='expected 'tol='tol; exit 1; end
  say 'PASS' label
  return

::requires 'MathRxMathProvider.cls'
::requires 'MathNumpyProvider.cls'
