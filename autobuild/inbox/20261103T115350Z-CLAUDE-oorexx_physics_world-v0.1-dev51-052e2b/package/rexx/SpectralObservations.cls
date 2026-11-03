/* ooRexx Physics World v0.1-dev15
   Reusable sampled-signal/spectral observations.
   This is domain-neutral analysis evidence for mechanics and acoustics.
*/
::class SampledScalarHistory public
::method init
  expose _times _values
  _times=.array~new; _values=.array~new
::method append
  expose _times _values
  use strict arg timeSeconds,value
  _times~append(timeSeconds+0); _values~append(value+0); return self
::method count; expose _values; return _values~items
::method duration
  expose _times
  if _times~items<2 then return 0
  return _times[_times~items]-_times[1]
::method mean
  expose _values
  if _values~items=0 then raise syntax 93.900 array('mean requires samples')
  s=0; do v over _values; s=s+v; end
  return s/_values~items
::method rms
  expose _values
  if _values~items=0 then raise syntax 93.900 array('rms requires samples')
  s=0; do v over _values; s=s+v*v; end
  return RxCalcSqrt(s/_values~items,30)
::method component
  expose _times _values
  use strict arg frequencyHz
  numeric digits 30
  n=_values~items
  if n<2 then raise syntax 93.900 array('at least two samples for spectral observation')
  pi=4*RxCalcArcTan(1,30,'R'); c=0; s=0
  do i=1 to n
    a=2*pi*frequencyHz*_times[i]
    c=c+_values[i]*RxCalcCos(a,30,'R')
    s=s+_values[i]*RxCalcSin(a,30,'R')
  end
  return .SpectralComponentObservation~new(frequencyHz,2*RxCalcSqrt(c*c+s*s,30)/n,2*c/n,2*s/n,n)
::method spectrum
  use strict arg frequencies
  result=.array~new
  do f over frequencies; result~append(self~component(f)); end
  return result

::class SpectralComponentObservation public
::method init
  expose _frequency _amplitude _cosine _sine _samples
  use strict arg frequencyHz,amplitude,cosineComponent,sineComponent,sampleCount
  _frequency=frequencyHz; _amplitude=amplitude; _cosine=cosineComponent; _sine=sineComponent; _samples=sampleCount
::method frequency; expose _frequency; return _frequency
::method amplitude; expose _amplitude; return _amplitude
::method cosineComponent; expose _cosine; return _cosine
::method sineComponent; expose _sine; return _sine
::method sampleCount; expose _samples; return _samples

::class BroadbandSourceSample public
::method init
  expose _position _pressure _time _name
  use strict arg name,position,pressure,timeSeconds
  _name=name; _position=position; _pressure=pressure+0; _time=timeSeconds+0
::method name; expose _name; return _name
::method position; expose _position; return _position
::method pressure; expose _pressure; return _pressure
::method time; expose _time; return _time

::class IncoherentSourceAggregator public
/* Statistical RMS combination for explicitly incoherent source contributions.
   This is NOT coherent pressure summation and is deliberately named accordingly. */
::method combinedRms class
  use strict arg rmsContributions
  sumSquares=0
  do p over rmsContributions
    if p<0 then raise syntax 88.900 array('non-negative RMS pressure',p)
    sumSquares=sumSquares+p*p
  end
  return RxCalcSqrt(sumSquares,30)

::requires 'PhysicsWorld.cls'
::requires 'rxmath' LIBRARY
