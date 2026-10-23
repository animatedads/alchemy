/* Additive pure ooRexx audio processing models. Independent of Maths provider. */
::class AudioLMS public
::method init
 expose taps mu weights history
 use strict arg taps,mu
 if \datatype(taps,'W') then raise syntax 93.900 array('taps must be integer')
 if taps<1 then raise syntax 93.900 array('taps must be positive')
 if \datatype(mu,'N') then raise syntax 93.900 array('mu must be numeric')
 if mu<=0 then raise syntax 93.900 array('mu must be positive')
 weights=.array~new(taps); history=.array~new(taps)
 do i=1 to taps; weights[i]=0; history[i]=0; end
::method advance
 expose taps mu weights history
 use strict arg reference,desired
 do i=taps to 2 by -1; history[i]=history[i-1]; end
 history[1]=reference
 estimate=0; power=0
 do i=1 to taps
  estimate=estimate+weights[i]*history[i]
  power=power+history[i]*history[i]
 end
 error=desired-estimate
 gain=mu*error/(0.000000001+power)
 do i=1 to taps; weights[i]=weights[i]+gain*history[i]; end
 return .array~of(error,estimate)
::method snapshot
 expose weights history
 return .array~of(weights~copy,history~copy)
::method restore
 expose taps weights history
 use strict arg state
 if state~items<>2 then raise syntax 93.900 array('invalid snapshot')
 if state[1]~items<>taps then raise syntax 93.900 array('snapshot tap mismatch')
 if state[2]~items<>taps then raise syntax 93.900 array('snapshot history mismatch')
 weights=state[1]~copy; history=state[2]~copy
 return self
::method weights
 expose weights
 return weights~copy

::class AudioSpectralFlux public
::method init
 expose previous
 previous=.nil
::method advance
 expose previous
 use strict arg magnitudes
 if previous==.nil then do
  previous=magnitudes~copy
  return 0
 end
 if previous~items<>magnitudes~items then raise syntax 93.900 array('spectrum size changed')
 flux=0
 do i=1 to magnitudes~items
  if magnitudes[i]<0 then raise syntax 93.900 array('negative magnitude')
  delta=magnitudes[i]-previous[i]
  if delta>0 then flux=flux+delta*delta
 end
 previous=magnitudes~copy
 return flux
::method snapshot
 expose previous
 if previous==.nil then return .nil
 return previous~copy
::method restore
 expose previous
 use strict arg state
 if state==.nil then previous=.nil
 else previous=state~copy
 return self

::class AudioZeroCrossing public
::method count
 use strict arg samples
 count=0
 do i=2 to samples~items
  if samples[i-1]<0 & samples[i]>=0 then count=count+1
  if samples[i-1]>=0 & samples[i]<0 then count=count+1
 end
 return count

::class AudioModelRegistry public
::method names
 return .array~of('NORMALIZED_LMS','SPECTRAL_FLUX','ZERO_CROSSING')
::method create
 use strict arg name,p1,p2
 select
  when translate(name)=='NORMALIZED_LMS' then return .AudioLMS~new(p1,p2)
  when translate(name)=='SPECTRAL_FLUX' then return .AudioSpectralFlux~new
  when translate(name)=='ZERO_CROSSING' then return .AudioZeroCrossing~new
  otherwise raise syntax 93.900 array('Unknown model',name)
 end
