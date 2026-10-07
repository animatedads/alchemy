/* Optional accelerated binary64 provider using existing Foreign Runtime. */
ignored=.Maths~registerProvider(.MathNumpyProvider~new)

::class MathNumpyProvider subclass MathProvider public
::method init
  expose _np _version _pythonVersion _providerPath _blasName _blasVersion _lapackName _lapackVersion
  if \.ForeignPython~canImport('numpy') then raise syntax 88.900 array('importable numpy','not available')
  _np=.ForeignPython~import('numpy')
  _version=_np~get('__version__')
  _pythonVersion=_np~pythonVersion
  _providerPath=_np~providerPath
  _blasName='unknown'; _blasVersion='unknown'; _lapackName='unknown'; _lapackVersion='unknown'
  cfg=_np~get('__config__')
  conf=cfg~get('CONFIG')
  if conf~isA(.directory) then if conf~hasIndex('Build Dependencies') then do
    deps=conf['Build Dependencies']
    if deps~isA(.directory) then do
      if deps~hasIndex('blas') then do
        b=deps['blas']; if b~isA(.directory) then do; _blasName=b['name']; _blasVersion=b['version']; end
      end
      if deps~hasIndex('lapack') then do
        l=deps['lapack']; if l~isA(.directory) then do; _lapackName=l['name']; _lapackVersion=l['version']; end
      end
    end
  end
  cfg~close
::method name; return 'NUMPY'
::method version; expose _version; return _version
::method supports
  use strict arg operation
  return operation='matrix.add' | operation='matrix.sub' | operation='matrix.mul' | operation='matrix.transpose' | operation='matrix.solve' | -
         operation='vector.add' | operation='vector.sub' | operation='vector.mul' | operation='vector.hadamard' | -
         operation='series.mean' | operation='series.rms' | operation='spectrum.selected-frequency' | operation='spectrum.selected-frequencies' | operation='spectrum.rfft' | -
         operation='signal.convolve' | operation='signal.oscillator-bank' | operation='signal.state-space'
::method _array
  expose _np
  use strict arg matrix
  if matrix~backendProvider='NUMPY' then do
    if matrix~backendValue \== .nil then return .array~of(matrix~backendValue,.false)
  end
  kw=.ForeignPython~keywords; kw~put('dtype','float64')
  return .array~of(_np~array(matrix~toArray,kw),.true)
::method _evidence
  expose _pythonVersion _providerPath _blasName _blasVersion _lapackName _lapackVersion
  use strict arg operation,context,inputs,algorithm,details=''
  stack='python='_pythonVersion';module='_providerPath';BLAS='_blasName' '_blasVersion';LAPACK='_lapackName' '_lapackVersion
  if details<>'' then stack=stack';'_details
  ev=.MathEvidence~new(operation,context,inputs)
  ev~addStep(.MathPathStep~new(operation,self~name,self~version,algorithm,'BINARY64',16,'NumPy float64 ndarray',stack,'APPROXIMATE_IEEE754','NUMPY,BLAS,LAPACK,'algorithm))
  ev~addWarning('binary64 limits effective significance to about 16 decimal digits; any higher-precision source conversion is lossy and explicit via MathContext~binary64.')
  return ev
::method _vectorArray
  expose _np
  use strict arg vector
  if vector~backendProvider='NUMPY' then do
    if vector~backendValue \== .nil then return .array~of(vector~backendValue,.false)
  end
  kw=.ForeignPython~keywords; kw~put('dtype','float64')
  return .array~of(_np~array(vector~toArray,kw),.true)
::method _float64List
  expose _np
  use strict arg arrayObject
  char=_np~get('char')
  formatted=char~mod('%.17g',arrayObject)
  vals=formatted~tolist
  formatted~close; char~close
  return vals
::method _float64ScalarFromArray
  use strict arg arrayObject
  numeric digits 18
  vals=self~_float64List(arrayObject)
  return vals[1]
::method discreteStateSpaceProcess
  use strict arg system,initialState,inputs,context
  numeric digits context~workingDigits
  if context~numberDomain<>'BINARY64' then raise syntax 88.900 array('BINARY64 context for NUMPY discrete state-space provider',context~canonical)
  native=.ForeignPython~import('oorexx_maths_native')
  raw=native~run_discrete_state_space(system~stateMatrix~toArray,system~inputMatrix~toArray,system~outputMatrix~toArray,system~feedthroughMatrix~toArray,initialState~toArray,inputs~toArray)
  ys=raw['outputs']; xs=raw['final_state']
  ev=self~_evidence('signal.state-space',context,.array~of(system~canonical,'samples='inputs~rows),'numpy-state-space-block','single Foreign Runtime call; NumPy float64 block recurrence')
  ev~putCheck('stateCount',system~stateCount); ev~putCheck('inputCount',system~inputCount); ev~putCheck('outputCount',system~outputCount)
  native~close
  return .MathDiscreteStateSpaceTrajectory~new(ys,.MathVector~new(xs,context,ev),inputs~rows,context,ev,.MathDerivation~new('signal.state-space',.array~of(system,initialState,inputs)))

::method vectorAdd
  expose _np
  use strict arg left,right,context
  numeric digits context~workingDigits
  if context~numberDomain<>'BINARY64' then raise syntax 88.900 array('BINARY64 context for NUMPY vector provider',context~canonical)
  if left~size<>right~size then raise syntax 88.900 array('equal vector dimensions',left~size'/'right~size)
  la=self~_vectorArray(left); ra=self~_vectorArray(right); c=_np~add(la[1],ra[1]); vals=self~_float64List(c)
  ev=self~_evidence('vector.add',context,.array~of(left~canonical,right~canonical),'numpy.add','native vectorized ufunc addition')
  out=.MathVector~new(vals,context,ev,.MathDerivation~new('vector.add',.array~of(left,right)),'NUMPY',c)
  if la[2] then la[1]~close; if ra[2] then ra[1]~close
  return out
::method vectorSub
  expose _np
  use strict arg left,right,context
  numeric digits context~workingDigits
  if context~numberDomain<>'BINARY64' then raise syntax 88.900 array('BINARY64 context for NUMPY vector provider',context~canonical)
  if left~size<>right~size then raise syntax 88.900 array('equal vector dimensions',left~size'/'right~size)
  la=self~_vectorArray(left); ra=self~_vectorArray(right); c=_np~subtract(la[1],ra[1]); vals=self~_float64List(c)
  ev=self~_evidence('vector.sub',context,.array~of(left~canonical,right~canonical),'numpy.subtract','native vectorized ufunc subtraction')
  out=.MathVector~new(vals,context,ev,.MathDerivation~new('vector.sub',.array~of(left,right)),'NUMPY',c)
  if la[2] then la[1]~close; if ra[2] then ra[1]~close
  return out
::method vectorMul
  expose _np
  use strict arg left,right,context
  numeric digits context~workingDigits
  if context~numberDomain<>'BINARY64' then raise syntax 88.900 array('BINARY64 context for NUMPY vector provider',context~canonical)
  la=self~_vectorArray(left)
  if right~isA(.MathVector) then do
    if left~size<>right~size then raise syntax 88.900 array('equal vector dimensions',left~size'/'right~size)
    ra=self~_vectorArray(right); prod=_np~multiply(la[1],ra[1])
    kws=.ForeignPython~keywords; kws~put('keepdims',.true)
    total=_np~sum(prod,kws); answer=self~_float64ScalarFromArray(total)
    if la[2] then la[1]~close; if ra[2] then ra[1]~close
    prod~close; total~close
    return answer
  end
  scalar=right; c=_np~multiply(la[1],scalar); vals=self~_float64List(c)
  ev=self~_evidence('vector.scale',context,.array~of(left~canonical,scalar),'numpy.multiply','native vectorized scalar multiplication')
  out=.MathVector~new(vals,context,ev,.MathDerivation~new('vector.scale',.array~of(left),scalar),'NUMPY',c)
  if la[2] then la[1]~close
  return out
::method vectorHadamard
  expose _np
  use strict arg left,right,context
  numeric digits context~workingDigits
  if context~numberDomain<>'BINARY64' then raise syntax 88.900 array('BINARY64 context for NUMPY vector provider',context~canonical)
  if left~size<>right~size then raise syntax 88.900 array('equal vector dimensions',left~size'/'right~size)
  la=self~_vectorArray(left); ra=self~_vectorArray(right); c=_np~multiply(la[1],ra[1]); vals=self~_float64List(c)
  ev=self~_evidence('vector.hadamard',context,.array~of(left~canonical,right~canonical),'numpy.multiply','native vectorized elementwise multiplication')
  out=.MathVector~new(vals,context,ev,.MathDerivation~new('vector.hadamard',.array~of(left,right)),'NUMPY',c)
  if la[2] then la[1]~close; if ra[2] then ra[1]~close
  return out
::method seriesMean
  expose _np
  use strict arg series,context
  numeric digits context~workingDigits
  if context~numberDomain<>'BINARY64' then raise syntax 88.900 array('BINARY64 context for NUMPY sampled-series provider',context~canonical)
  vals=series~values; if vals~items=0 then raise syntax 93.900 array('mean requires samples')
  kw=.ForeignPython~keywords; kw~put('dtype','float64'); a=_np~array(vals,kw)
  kwm=.ForeignPython~keywords; kwm~put('keepdims',.true)
  r=_np~mean(a,kwm); answer=self~_float64ScalarFromArray(r); a~close; r~close
  return answer
::method seriesRms
  expose _np
  use strict arg series,context
  numeric digits context~workingDigits
  if context~numberDomain<>'BINARY64' then raise syntax 88.900 array('BINARY64 context for NUMPY sampled-series provider',context~canonical)
  vals=series~values; if vals~items=0 then raise syntax 93.900 array('RMS requires samples')
  kw=.ForeignPython~keywords; kw~put('dtype','float64'); a=_np~array(vals,kw); sq=_np~multiply(a,a)
  kwm=.ForeignPython~keywords; kwm~put('keepdims',.true)
  mean=_np~mean(sq,kwm); r=_np~sqrt(mean); answer=self~_float64ScalarFromArray(r)
  a~close; sq~close; mean~close; r~close
  return answer
::method seriesFourierComponent
  expose _np
  use strict arg series,frequency,context
  numeric digits context~workingDigits
  if context~numberDomain<>'BINARY64' then raise syntax 88.900 array('BINARY64 context for NUMPY spectral provider',context~canonical)
  times=series~times; vals=series~values; n=vals~items
  if n<2 then raise syntax 93.900 array('at least two samples for Fourier projection')
  f=frequency; kw=.ForeignPython~keywords; kw~put('dtype','float64')
  ta=_np~array(times,kw); va=_np~array(vals,kw)
  factor=2*3.1415926535897932384626433832795028841971693993751*f
  angles=_np~multiply(ta,factor); cv=_np~cos(angles); sv=_np~sin(angles)
  cp=_np~multiply(va,cv); sp=_np~multiply(va,sv)
  kws=.ForeignPython~keywords; kws~put('keepdims',.true)
  csum=_np~sum(cp,kws); ssum=_np~sum(sp,kws)
  c=2*self~_float64ScalarFromArray(csum)/n; sn=2*self~_float64ScalarFromArray(ssum)/n
  pair=_np~array(.array~of(c*c+sn*sn),kw); ampa=_np~sqrt(pair); amp=self~_float64ScalarFromArray(ampa)
  ev=self~_evidence('spectrum.selected-frequency',context,.array~of(f,n),'numpy-vectorized-fourier-projection','np.multiply/cos/sin/sum over contiguous float64 arrays')
  deriv=.MathDerivation~new('spectrum.selected-frequency',.array~of(series),f)
  answer=.MathSpectralComponent~new(f,amp,c,sn,n,context,ev,deriv)
  ta~close; va~close; angles~close; cv~close; sv~close; cp~close; sp~close; csum~close; ssum~close; pair~close; ampa~close
  return answer
::method seriesSpectrum
  expose _np
  use strict arg series,frequencies,context
  numeric digits context~workingDigits
  if context~numberDomain<>'BINARY64' then raise syntax 88.900 array('BINARY64 context for NUMPY spectral provider',context~canonical)
  times=series~times; vals=series~values; n=vals~items
  if n<2 then raise syntax 93.900 array('at least two samples for Fourier projection')
  kw=.ForeignPython~keywords; kw~put('dtype','float64')
  ta=_np~array(times,kw); va=_np~array(vals,kw); out=.array~new
  do frequency over frequencies
    f=frequency
    factor=2*3.1415926535897932384626433832795028841971693993751*f
    angles=_np~multiply(ta,factor); cv=_np~cos(angles); sv=_np~sin(angles)
    cp=_np~multiply(va,cv); sp=_np~multiply(va,sv)
    kws=.ForeignPython~keywords; kws~put('keepdims',.true)
    csum=_np~sum(cp,kws); ssum=_np~sum(sp,kws)
    c=2*self~_float64ScalarFromArray(csum)/n; sn=2*self~_float64ScalarFromArray(ssum)/n
    pair=_np~array(.array~of(c*c+sn*sn),kw); ampa=_np~sqrt(pair); amp=self~_float64ScalarFromArray(ampa)
    ev=self~_evidence('spectrum.selected-frequency',context,.array~of(f,n),'numpy-vectorized-fourier-projection-reused-input','base time/value float64 arrays retained across multi-frequency spectrum request')
    deriv=.MathDerivation~new('spectrum.selected-frequency',.array~of(series),f)
    out~append(.MathSpectralComponent~new(f,amp,c,sn,n,context,ev,deriv))
    angles~close; cv~close; sv~close; cp~close; sp~close; csum~close; ssum~close; pair~close; ampa~close
  end
  ta~close; va~close
  return out
::method seriesRfft
  expose _np
  use strict arg series,context
  numeric digits context~workingDigits
  if context~numberDomain<>'BINARY64' then raise syntax 88.900 array('BINARY64 context for NUMPY real FFT provider',context~canonical)
  if series~count<2 then raise syntax 93.900 array('at least two samples for real FFT')
  if \series~isUniform then raise syntax 88.900 array('uniformly sampled series for real FFT')
  times=series~times; vals=series~values; n=vals~items; dt=times[2]-times[1]; t0=times[1]
  kw=.ForeignPython~keywords; kw~put('dtype','float64'); va=_np~array(vals,kw)
  fft=_np~get('fft'); spec=fft~rfft(va); reala=spec~get('real'); imaga=spec~get('imag'); freqa=fft~rfftfreq(n,dt)
  reals=self~_float64List(reala); imags=self~_float64List(imaga); freqs=self~_float64List(freqa); bins=.array~new
  do i=1 to freqs~items; bins~append(.MathFFTBin~new(i-1,freqs[i],reals[i],imags[i],n,context)); end
  ev=self~_evidence('spectrum.rfft',context,.array~of(n,dt,t0),'numpy.fft.rfft','native real-input FFT; coefficients use the first retained sample as time origin')
  deriv=.MathDerivation~new('spectrum.rfft',.array~of(series))
  out=.MathFFTResult~new(bins,1/dt,n,t0,context,ev,deriv)
  va~close; reala~close; imaga~close; freqa~close; spec~close; fft~close
  return out
::method signalConvolve
  expose _np
  use strict arg left,right,context
  numeric digits context~workingDigits
  if context~numberDomain<>'BINARY64' then raise syntax 88.900 array('BINARY64 context for NUMPY convolution provider',context~canonical)
  if left~size=0 | right~size=0 then raise syntax 93.900 array('non-empty vectors for convolution')
  la=self~_vectorArray(left); ra=self~_vectorArray(right); outn=left~size+right~size-1
  /* For longer filters/impulse responses, switch from the native direct kernel
     to zero-padded real FFT convolution. The PURE/REFERENCE witness remains
     direct convolution, so the proof path is algorithmically different. */
  if left~size*right~size>=65536 then do
    fftSize=1; do while fftSize<outn; fftSize=fftSize*2; end
    fft=_np~get('fft'); fa=fft~rfft(la[1],fftSize); fb=fft~rfft(ra[1],fftSize); prod=_np~multiply(fa,fb); padded=fft~irfft(prod,fftSize)
    all=self~_float64List(padded); vals=.array~new; do i=1 to outn; vals~append(all[i]); end
    kw=.ForeignPython~keywords; kw~put('dtype','float64'); c=_np~array(vals,kw)
    ev=self~_evidence('signal.convolve',context,.array~of(left~canonical,right~canonical),'numpy-rfft-linear-convolution','zero-padded real FFT convolution; fftSize='fftSize'; output trimmed to exact full-convolution length')
    fa~close; fb~close; prod~close; padded~close; fft~close
  end
  else do
    c=_np~convolve(la[1],ra[1],'full'); vals=self~_float64List(c)
    ev=self~_evidence('signal.convolve',context,.array~of(left~canonical,right~canonical),'numpy.convolve','native NumPy full discrete linear convolution')
  end
  out=.MathVector~new(vals,context,ev,.MathDerivation~new('signal.convolve',.array~of(left,right)),'NUMPY',c)
  if la[2] then la[1]~close; if ra[2] then ra[1]~close
  return out
::method oscillatorBankRender
  expose _np
  use strict arg bank,sampleCount,startSample,context
  numeric digits context~workingDigits
  if context~numberDomain<>'BINARY64' then raise syntax 88.900 array('BINARY64 context for NUMPY oscillator-bank provider',context~canonical)
  if \datatype(sampleCount,'W') | sampleCount<1 then raise syntax 88.900 array('positive oscillator sample count',sampleCount)
  if \datatype(startSample,'W') | startSample<0 then raise syntax 88.900 array('non-negative oscillator start sample',startSample)
  kw=.ForeignPython~keywords; kw~put('dtype','float64')
  idx=_np~arange(sampleCount,kw); shifted=_np~add(idx,startSample); t=_np~divide(shifted,bank~sampleRate); outa=_np~zeros(sampleCount,kw)
  amps=bank~amplitudes; freqs=bank~frequenciesHz; decays=bank~decayPerSecond; phases=bank~phaseRadians
  pi=3.1415926535897932384626433832795028841971693993751
  do i=1 to amps~items
    angle=_np~multiply(t,2*pi*freqs[i]); if phases[i]<>0 then do; next=_np~add(angle,phases[i]); angle~close; angle=next; end
    wave=_np~sin(angle); exponent=_np~multiply(t,-decays[i]); envelope=_np~exp(exponent)
    shaped=_np~multiply(wave,envelope); contrib=_np~multiply(shaped,amps[i]); next=_np~add(outa,contrib)
    outa~close; outa=next
    angle~close; wave~close; exponent~close; envelope~close; shaped~close; contrib~close
  end
  vals=self~_float64List(outa)
  ev=self~_evidence('signal.oscillator-bank',context,.array~of(bank~canonical,sampleCount,startSample),'numpy-vectorized-damped-oscillator-bank','sample axis executed in native NumPy; ooRexx loops over modes only')
  rendered=.MathVector~new(vals,context,ev,.MathDerivation~new('signal.oscillator-bank',.array~of(bank,sampleCount,startSample)),'NUMPY',outa)
  idx~close; shifted~close; t~close
  return rendered

::method matrixAdd
  expose _np
  use strict arg left,right,context
  numeric digits context~workingDigits
  call rx_math_check_same_shape left,right
  la=self~_array(left); ra=self~_array(right)
  c=_np~add(la[1],ra[1]); rows=self~_float64List(c)
  ev=self~_evidence('matrix.add',context,.array~of(left~canonical,right~canonical),'numpy.add','ufunc elementwise addition')
  out=.MathMatrix~new(rows,context,ev,.MathDerivation~new('matrix.add',.array~of(left,right)),'NUMPY',c)
  if la[2] then la[1]~close; if ra[2] then ra[1]~close
  return out
::method matrixSub
  expose _np
  use strict arg left,right,context
  numeric digits context~workingDigits
  call rx_math_check_same_shape left,right
  la=self~_array(left); ra=self~_array(right)
  c=_np~subtract(la[1],ra[1]); rows=self~_float64List(c)
  ev=self~_evidence('matrix.sub',context,.array~of(left~canonical,right~canonical),'numpy.subtract','ufunc elementwise subtraction')
  out=.MathMatrix~new(rows,context,ev,.MathDerivation~new('matrix.sub',.array~of(left,right)),'NUMPY',c)
  if la[2] then la[1]~close; if ra[2] then ra[1]~close
  return out
::method matrixMul
  expose _np
  use strict arg left,right,context
  numeric digits context~workingDigits
  if right~isA(.MathMatrix) then do
    if left~cols<>right~rows then raise syntax 88.900 array('compatible matrix dimensions',left~cols'/'right~rows)
    la=self~_array(left); ra=self~_array(right); c=_np~matmul(la[1],ra[1]); rows=self~_float64List(c)
    ev=self~_evidence('matrix.matmul',context,.array~of(left~canonical,right~canonical),'numpy.matmul','NumPy dispatches matrix product through its configured native numerical stack')
    out=.MathMatrix~new(rows,context,ev,.MathDerivation~new('matrix.matmul',.array~of(left,right)),'NUMPY',c)
    if la[2] then la[1]~close; if ra[2] then ra[1]~close
    return out
  end
  if right~isA(.MathVector) then do
    if left~cols<>right~size then raise syntax 88.900 array('compatible matrix/vector dimensions',left~cols'/'right~size)
    la=self~_array(left); ra=self~_vectorArray(right); c=_np~matmul(la[1],ra[1]); vals=self~_float64List(c)
    ev=self~_evidence('matrix.matvec',context,.array~of(left~canonical,right~canonical),'numpy.matmul-matvec','native matrix-vector product through NumPy numerical stack')
    out=.MathVector~new(vals,context,ev,.MathDerivation~new('matrix.matvec',.array~of(left,right)),'NUMPY',c)
    if la[2] then la[1]~close; if ra[2] then ra[1]~close
    return out
  end
  return .Maths~provider('PURE')~matrixMul(left,right,context)
::method matrixTranspose
  use strict arg a,context
  numeric digits context~workingDigits
  aa=self~_array(a); c=aa[1]~get('T')
  rows=self~_float64List(c)
  ev=self~_evidence('matrix.transpose',context,.array~of(a~canonical),'numpy.ndarray.T','view/copy semantics remain provider-owned')
  out=.MathMatrix~new(rows,context,ev,.MathDerivation~new('matrix.transpose',.array~of(a)),'NUMPY',c)
  if aa[2] then aa[1]~close
  return out
::method matrixSolve
  expose _np
  use strict arg a,b,context
  numeric digits context~workingDigits
  aa=self~_array(a)
  kw=.ForeignPython~keywords; kw~put('dtype','float64')
  if b~isA(.MathMatrix) then do
    ba=self~_array(b); bb=ba[1]
  end
  else do; ba=.nil; bb=_np~array(b~toArray,kw); end
  linalg=_np~get('linalg'); x=linalg~solve(aa[1],bb); vals=self~_float64List(x)
  ev=self~_evidence('matrix.solve',context,.array~of(a~canonical,b~canonical),'numpy.linalg.solve','provider-selected LAPACK solve path; exact LAPACK routine depends on NumPy build')
  if b~isA(.MathMatrix) then out=.MathMatrix~new(vals,context,ev,.MathDerivation~new('matrix.solve.matrix',.array~of(a,b)),'NUMPY',x)
  else do
    out=.MathVector~new(vals,context,ev,.MathDerivation~new('matrix.solve',.array~of(a,b)))
    ev~putCheck('residualInf',rx_math_residual_norm_inf(a,out,b,context))
  end
  if aa[2] then aa[1]~close
  if b~isA(.MathMatrix) then do; if ba[2] then bb~close; end; else bb~close
  linalg~close
  return out
::method uninit
  expose _np
  if symbol('_np')='VAR' then if _np \== .nil then _np~close

::requires 'MathsBootstrap.cls'
::requires 'python_foreign.cls'
