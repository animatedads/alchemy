/* Audio spectral estimators v0.3: power-domain, frame-oriented, pure ooRexx.
   Input bins are nonnegative power estimates, NOT FFT coefficients.
   No imaginary-part manipulation, speech synthesis or inferred words. */
::class AudioSpectralNoiseTracker public
::method init
 expose alpha floor noise initialized frames
 use strict arg alpha,floor
 if \datatype(alpha,'N') then raise syntax 93.900 array('alpha must be numeric')
 if \datatype(floor,'N') then raise syntax 93.900 array('floor must be numeric')
 if alpha<0 | alpha>=1 then raise syntax 93.900 array('alpha must be in [0,1)')
 if floor<=0 then raise syntax 93.900 array('floor must be positive')
 noise=.nil; initialized=0; frames=0
::method advance
 expose alpha floor noise initialized frames
 use strict arg powers,noiseOnly
 self~validatePowers(powers)
 if noiseOnly<>0 & noiseOnly<>1 then raise syntax 93.900 array('noiseOnly must be 0 or 1')
 if initialized=0 then do
  if noiseOnly<>1 then raise syntax 93.900 array('initial frame must be declared noise-only')
  noise=.Array~new
  do i=1 to powers~items; noise~append(max(floor,powers[i])); end
  initialized=1
 end
 else do
  if noise~items<>powers~items then raise syntax 93.900 array('spectrum size changed')
  if noiseOnly=1 then do i=1 to powers~items
   noise[i]=max(floor,alpha*noise[i]+(1-alpha)*powers[i])
  end
 end
 frames=frames+1
 return noise~copy
::method estimate
 expose noise
 if noise==.nil then return .nil
 return noise~copy
::method snapshot
 expose noise initialized frames
 if noise==.nil then return .array~of(.nil,initialized,frames)
 return .array~of(noise~copy,initialized,frames)
::method restore
 expose noise initialized frames
 use strict arg state
 if \state~isA(.Array) then raise syntax 93.900 array('snapshot must be array')
 if state~items<>3 then raise syntax 93.900 array('snapshot length')
 if state[2]<>0 & state[2]<>1 then raise syntax 93.900 array('snapshot flag')
 if \datatype(state[3],'W') then raise syntax 93.900 array('snapshot frames')
 if state[3]<0 then raise syntax 93.900 array('snapshot frames')
 if state[1]==.nil then do
  if state[2]<>0 | state[3]<>0 then raise syntax 93.900 array('snapshot inconsistency')
  noise=.nil
 end
 else do
  self~validatePowers(state[1])
  if state[2]<>1 then raise syntax 93.900 array('snapshot inconsistency')
  noise=state[1]~copy
 end
 initialized=state[2]; frames=state[3]
 return self
::method validatePowers
 use strict arg powers
 if \powers~isA(.Array) then raise syntax 93.900 array('powers must be array')
 do i=1 to powers~items
  if \datatype(powers[i],'N') then raise syntax 93.900 array('non-numeric power')
  if powers[i]<0 then raise syntax 93.900 array('negative power')
 end
 return 1

::class AudioWienerGain public
::method init
 expose gainFloor
 use strict arg gainFloor
 if \datatype(gainFloor,'N') then raise syntax 93.900 array('gain floor must be numeric')
 if gainFloor<0 | gainFloor>1 then raise syntax 93.900 array('gain floor out of range')
::method gains
 expose gainFloor
 use strict arg observed,noise
 self~validate(observed,noise)
 gainsOut=.Array~new
 do i=1 to observed~items
  s=max(0,observed[i]-noise[i])
  if observed[i]=0 then g=gainFloor
  else g=max(gainFloor,s/(s+noise[i]))
  gainsOut~append(g)
 end
 return gainsOut
::method validate
 use strict arg observed,noise
 if \observed~isA(.Array) | \noise~isA(.Array) then raise syntax 93.900 array('power arrays required')
 if observed~items<>noise~items then raise syntax 93.900 array('power size mismatch')
 do i=1 to observed~items
  if \datatype(observed[i],'N') | \datatype(noise[i],'N') then raise syntax 93.900 array('non-numeric power')
  if observed[i]<0 | noise[i]<0 then raise syntax 93.900 array('negative power')
 end
 return 1

::class AudioSpectralSubtractionGain subclass AudioWienerGain public
::method init
 expose overSubtraction gainFloor
 use strict arg overSubtraction,gainFloor
 if \datatype(overSubtraction,'N') then raise syntax 93.900 array('overSubtraction must be numeric')
 if overSubtraction<0 then raise syntax 93.900 array('overSubtraction must be nonnegative')
 if \datatype(gainFloor,'N') then raise syntax 93.900 array('gain floor must be numeric')
 if gainFloor<0 | gainFloor>1 then raise syntax 93.900 array('gain floor out of range')
::method gains
 expose overSubtraction gainFloor
 use strict arg observed,noise
 self~validate(observed,noise)
 gainsOut=.Array~new
 do i=1 to observed~items
  residual=max(0,observed[i]-overSubtraction*noise[i])
  if observed[i]=0 then g=gainFloor
  else g=max(gainFloor,min(1,self~root01(residual/observed[i])))
  gainsOut~append(g)
 end
 return gainsOut
::method root01
 use strict arg value
 if value<=0 then return 0
 if value>=1 then return 1
 guess=1
 do j=1 to 30
  guess=(guess+value/guess)/2
 end
 return guess

::class AudioSpectralModelRegistry public
::method names
 return .array~of('NOISE_EWMA','WIENER_GAIN','SPECTRAL_SUBTRACTION_GAIN')
::method create
 use strict arg name,p1,p2
 select
  when translate(name)=='NOISE_EWMA' then return .AudioSpectralNoiseTracker~new(p1,p2)
  when translate(name)=='WIENER_GAIN' then return .AudioWienerGain~new(p1)
  when translate(name)=='SPECTRAL_SUBTRACTION_GAIN' then return .AudioSpectralSubtractionGain~new(p1,p2)
  otherwise raise syntax 93.900 array('Unknown model',name)
 end
