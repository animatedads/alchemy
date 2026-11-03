numeric digits 50
assertions=0
ctx=.MathContext~binary64('NUMPY')

/* Native matrix-vector product: important for modal/state-space workloads. */
a=.MathMatrix~new(.array~of(.array~of(1,2),.array~of(3,4)),ctx)
v=.MathVector~new(.array~of(5,6),ctx)
y=a*v
call check y~evidence~primaryProvider='NUMPY','NumPy matrix-vector evidence provider'; assertions+=1
call near y[1],17,'1E-14','NumPy matrix-vector first row'; assertions+=1
call near y[2],39,'1E-14','NumPy matrix-vector second row'; assertions+=1
p=y~prove(.MathClaim~independentlyReproduced('1E-12'))
call check p~outcome='PROVED','NumPy matrix-vector independently reproduced'; assertions+=1
call check p~verificationEvidence~primaryProvider='REFERENCE','matrix-vector proof switches provider'; assertions+=1

/* Multiple RHS solve/inverse now stays in native LAPACK. */
inv=a~inverse
call check inv~evidence~primaryProvider='NUMPY','NumPy multiple-RHS inverse evidence provider'; assertions+=1
call near inv[1,1],-2,'1E-14','NumPy inverse 11'; assertions+=1
call near inv[1,2],1,'1E-14','NumPy inverse 12'; assertions+=1
call near inv[2,1],'1.5','1E-14','NumPy inverse 21'; assertions+=1
call near inv[2,2],'-.5','1E-14','NumPy inverse 22'; assertions+=1

/* Full linear convolution for impulse-response/FIR style work. */
x=.MathVector~new(.array~of(1,2,3),ctx)
h=.MathVector~new(.array~of(4,5),ctx)
c=x~convolve(h)
call check c~evidence~primaryProvider='NUMPY','NumPy convolution evidence provider'; assertions+=1
call check c~size=4,'NumPy convolution output length'; assertions+=1
call near c[1],4,'1E-14','NumPy convolution sample 1'; assertions+=1
call near c[2],13,'1E-14','NumPy convolution sample 2'; assertions+=1
call near c[3],22,'1E-14','NumPy convolution sample 3'; assertions+=1
call near c[4],15,'1E-14','NumPy convolution sample 4'; assertions+=1
p=c~prove(.MathClaim~independentlyReproduced('1E-12'))
call check p~outcome='PROVED','NumPy convolution independently reproduced'; assertions+=1
call check p~verificationEvidence~primaryProvider='REFERENCE','convolution proof switches provider'; assertions+=1

/* Long impulse responses switch to FFT convolution, still witnessed by direct convolution. */
la=.array~new; do i=1 to 512; la~append(1); end
ha=.array~new; do i=1 to 256; ha~append(1); end
lc=.Maths~convolve(la,ha,ctx)
call check lc~evidence~steps[1]~algorithm='numpy-rfft-linear-convolution','long convolution selects native FFT algorithm'; assertions+=1
call check lc~size=767,'FFT convolution exact full output length'; assertions+=1
call near lc[1],1,'2E-12','FFT convolution leading sample'; assertions+=1
call near lc[256],256,'2E-10','FFT convolution plateau entry'; assertions+=1
call near lc[512],256,'2E-10','FFT convolution plateau exit'; assertions+=1
call near lc[767],1,'2E-10','FFT convolution trailing sample'; assertions+=1
p=lc~prove(.MathClaim~independentlyReproduced('2E-9'))
call check p~outcome='PROVED','FFT convolution independently reproduced by direct convolution'; assertions+=1
call check p~checks['differentAlgorithm'],'FFT convolution proof records different algorithm'; assertions+=1

/* Uniform real FFT: FFT native, direct DFT reference witness. */
series=.MathSampledScalarSeries~new(ctx)
pi='3.1415926535897932384626433832795028841971693993751'
n=64; sr=64; freq=8
rxctx=.MathContext~binary64('RXMATH')
do i=0 to n-1
  t=i/sr
  series~append(t,.Maths~sin(2*pi*freq*t,rxctx))
end
fft=series~rfft
call check fft~evidence~primaryProvider='NUMPY','NumPy RFFT evidence provider'; assertions+=1
call check fft~binCount=33,'RFFT half-spectrum bin count'; assertions+=1
b=fft~bin(freq)
call near b~frequencyHz,freq,'1E-14','RFFT target-bin frequency'; assertions+=1
call near b~real,0,'2E-13','RFFT sine real coefficient'; assertions+=1
call near b~imaginary,-32,'2E-13','RFFT sine imaginary coefficient'; assertions+=1
p=fft~prove(.MathClaim~independentlyReproduced('2E-12'))
call check p~outcome='PROVED','NumPy FFT independently reproduced by direct DFT'; assertions+=1
call check p~verificationEvidence~primaryProvider='REFERENCE','FFT proof uses reference provider'; assertions+=1
call check p~checks['differentAlgorithm'],'FFT proof records different algorithm'; assertions+=1

/* Damped oscillator bank: sample axis is vectorized in NumPy. */
bank=.Maths~oscillatorBank(.array~of(2),.array~of(1),.array~of(0),.array~of(0),8,ctx)
r=bank~render(8)
call check r~evidence~primaryProvider='NUMPY','NumPy oscillator-bank evidence provider'; assertions+=1
call check r~size=8,'oscillator-bank sample count'; assertions+=1
call near r[1],0,'1E-14','oscillator-bank starts at sine zero'; assertions+=1
call near r[3],2,'2E-14','oscillator-bank quarter-cycle peak'; assertions+=1
call near r[5],0,'3E-14','oscillator-bank half-cycle zero'; assertions+=1
p=r~prove(.MathClaim~independentlyReproduced('2E-12'))
call check p~outcome='PROVED','NumPy oscillator bank independently reproduced'; assertions+=1
call check p~verificationEvidence~primaryProvider='REFERENCE','oscillator proof switches provider'; assertions+=1

/* Chunked rendering preserves phase/time continuation. */
first=bank~render(4,0); second=bank~render(4,4)
do i=1 to 4
  call near first[i],r[i],'2E-14','oscillator first chunk 'i; assertions+=1
  call near second[i],r[i+4],'2E-14','oscillator second chunk 'i; assertions+=1
end

say 'PASS oorexx_maths native signal acceleration' assertions 'assertions'
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
