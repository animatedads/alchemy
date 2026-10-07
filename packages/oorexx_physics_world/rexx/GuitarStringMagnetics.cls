/* Physics World v0.1-dev39
 * Reduced-order vibrating ferromagnetic string -> magnetic flux physics.
 *
 * Physics owns string motion and flux geometry.  It does NOT produce pickup
 * voltage; Faraday conversion and winding/circuit state belong to Rexx-tronics.
 */
numeric digits 30

::class GuitarStringPhysicalModel public
::method init
  expose _openHz _scale _linearDensity _tension _inharmonicity _damping0 _dampingN _modes _pi _semitoneRatio
  use strict arg openFrequencyHz,scaleLengthM=.648,linearDensityKgPerM=.00045,tensionN=75,inharmonicity=.00008,damping0=2.8,dampingN=.018,modes=8
  if openFrequencyHz<=0 | scaleLengthM<=0 | linearDensityKgPerM<=0 | tensionN<=0 then raise syntax 88.900 array('positive guitar string physical parameters')
  if modes<1 then raise syntax 88.900 array('at least one string mode',modes)
  _openHz=openFrequencyHz+0;_scale=scaleLengthM+0;_linearDensity=linearDensityKgPerM+0;_tension=tensionN+0
  _inharmonicity=inharmonicity+0;_damping0=damping0+0;_dampingN=dampingN+0;_modes=modes+0
  _pi=.Maths~pi(.Maths~defaultContext); _semitoneRatio=RxCalcLog(2)/12
::method openFrequency; expose _openHz; return _openHz
::method modeCount; expose _modes; return _modes
::method linearDensity; expose _linearDensity; return _linearDensity
::method tension; expose _tension; return _tension
::method scaleLength; expose _scale; return _scale
::method effectiveLength
  expose _scale _semitoneRatio
  use strict arg fret
  return _scale/RxCalcExp(_semitoneRatio*fret,30)
::method frequencyForFret
  expose _openHz _semitoneRatio
  use strict arg fret,bendSemitones=0
  return _openHz*RxCalcExp(_semitoneRatio*(fret+bendSemitones),30)
::method modalAngularFrequency
  expose _inharmonicity _pi
  use strict arg fret,mode,bendSemitones=0
  return 2*_pi*self~frequencyForFret(fret,bendSemitones)*mode*RxCalcSqrt(1+_inharmonicity*mode*mode)
::method modalAmplitude
  expose _pi
  use strict arg mode,pluckFraction=.18,pluckDisplacementM=.0008
  if mode<1 | pluckFraction<=0 | pluckFraction>=1 then raise syntax 88.900 array('valid string modal/pluck parameters')
  return 2*pluckDisplacementM*RxCalcSin(_pi*mode*pluckFraction,30,'R')/((_pi*mode)**2*pluckFraction*(1-pluckFraction))
::method modalEffectiveMass
  expose _linearDensity
  use strict arg fret,mode
  if mode<1 then raise syntax 88.900 array('positive string mode',mode)
  return _linearDensity*self~effectiveLength(fret)/2
::method modalDamping
  expose _damping0 _dampingN
  use strict arg mode,articulation='PICK'
  d=_damping0+_dampingN*mode*mode
  if articulation='MUTE' | articulation='DEAD' then d=d*7
  else if articulation='HAMMER' then d=d*1.3
  else if articulation='PULL' then d=d*1.45
  return d
::method displacement
  expose _modes _pi
  use strict arg fret,timeSeconds,positionFraction,pluckFraction=.18,pluckDisplacementM=.0008,articulation='PICK',bendSemitones=0
  if timeSeconds<0 then return 0
  if positionFraction<0 | positionFraction>1 | pluckFraction<=0 | pluckFraction>=1 then raise syntax 88.900 array('string position fractions in physical range')
  y=0
  do n=1 to _modes
    /* Fourier coefficient for an initially triangular pluck. */
    modal=self~modalAmplitude(n,pluckFraction,pluckDisplacementM)
    shape=RxCalcSin(_pi*n*positionFraction,30,'R')
    w=self~modalAngularFrequency(fret,n,bendSemitones)
    d=self~modalDamping(n,articulation)
    y += modal*shape*RxCalcExp(-d*timeSeconds,30)*RxCalcCos(w*timeSeconds,30,'R')
  end
  return y
::method velocity
  expose _modes _pi
  use strict arg fret,timeSeconds,positionFraction,pluckFraction=.18,pluckDisplacementM=.0008,articulation='PICK',bendSemitones=0
  if timeSeconds<0 then return 0
  v=0
  do n=1 to _modes
    modal=self~modalAmplitude(n,pluckFraction,pluckDisplacementM)
    shape=RxCalcSin(_pi*n*positionFraction,30,'R')
    w=self~modalAngularFrequency(fret,n,bendSemitones);d=self~modalDamping(n,articulation)
    e=RxCalcExp(-d*timeSeconds,30)
    v += modal*shape*e*(-d*RxCalcCos(w*timeSeconds,30,'R')-w*RxCalcSin(w*timeSeconds,30,'R'))
  end
  return v

::class MagneticFluxGeometry public
::method init
  expose _baseline _gradient _position _evidence
  use strict arg baselineFluxWb,fluxDisplacementGradientWbPerM,pickupPositionFraction=.82,evidence=.nil
  if pickupPositionFraction<0 | pickupPositionFraction>1 then raise syntax 88.900 array('pickup position fraction in [0,1]')
  _baseline=baselineFluxWb+0;_gradient=fluxDisplacementGradientWbPerM+0;_position=pickupPositionFraction+0;_evidence=evidence
::method baselineFlux; expose _baseline; return _baseline
::method fluxDisplacementGradient; expose _gradient; return _gradient
::method pickupPositionFraction; expose _position; return _position
::method evidence; expose _evidence; return _evidence

::class PhysicsMagneticFluxObservation public
::method init
  expose _time _flux _displacement _velocity _source _evidence
  use strict arg timeSeconds,fluxWebers,stringDisplacementM,stringVelocityMps,source=.nil,evidence=.nil
  _time=timeSeconds+0;_flux=fluxWebers+0;_displacement=stringDisplacementM+0;_velocity=stringVelocityMps+0;_source=source;_evidence=evidence
::method timeSeconds; expose _time; return _time
::method fluxWebers; expose _flux; return _flux
::method stringDisplacement; expose _displacement; return _displacement
::method stringVelocity; expose _velocity; return _velocity
::method source; expose _source; return _source
::method evidence; expose _evidence; return _evidence

::class GuitarStringMagneticFluxProbe public
::method init
  expose _string _geometry
  use strict arg stringPhysicalModel,magneticFluxGeometry
  _string=stringPhysicalModel;_geometry=magneticFluxGeometry
::method observe
  expose _string _geometry
  use strict arg fret,timeSeconds,pluckFraction=.18,pluckDisplacementM=.0008,articulation='PICK',bendSemitones=0
  q=_geometry~pickupPositionFraction
  y=_string~displacement(fret,timeSeconds,q,pluckFraction,pluckDisplacementM,articulation,bendSemitones)
  v=_string~velocity(fret,timeSeconds,q,pluckFraction,pluckDisplacementM,articulation,bendSemitones)
  /* Linearized local magnetic coupling.  The gradient is explicit evidence,
     not a universal pickup constant. */
  flux=_geometry~baselineFlux+_geometry~fluxDisplacementGradient*y
  ev=.directory~new
  ev['MODEL']='LINEARIZED_LOCAL_FLUX_GRADIENT'
  ev['GEOMETRY']=_geometry
  ev['FRET']=fret
  ev['ARTICULATION']=articulation
  return .PhysicsMagneticFluxObservation~new(timeSeconds,flux,y,v,_string,ev)

::requires 'rxmath' LIBRARY
::requires 'MathsBootstrap.cls'
