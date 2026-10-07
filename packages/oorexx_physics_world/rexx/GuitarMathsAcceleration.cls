/* Physics World v0.1-dev44
 * Physics adapter onto Maths v0.10 sampled/modal acceleration.
 * Physics supplies physical modal parameters; Maths owns sampled evaluation.
 */
numeric digits 30

::class GuitarMathsModalRenderer public
::method init
 expose _string _context
 use strict arg stringPhysicalModel,mathContext
 _string=stringPhysicalModel;_context=mathContext

::method couplingScope
 return 'UNCOUPLED_SINGLE_PLUCK_ONLY'
::method isCoupledStateRenderer
 return .false

::method displacementBank
 expose _string _context
 use strict arg fret,positionFraction,sampleRate,pluckFraction=.18,pluckDisplacementM=.0008,articulation='PICK',bendSemitones=0
 if positionFraction<0 | positionFraction>1 then raise syntax 88.900 array('string position fraction in [0,1]')
 amps=.array~new;freqs=.array~new;decays=.array~new;phases=.array~new
 pi=4*RxCalcArcTan(1,30,'R')
 do n=1 to _string~modeCount
   modal=_string~modalAmplitude(n,pluckFraction,pluckDisplacementM)
   shape=RxCalcSin(pi*n*positionFraction,30,'R')
   amps~append(modal*shape)
   freqs~append(_string~modalAngularFrequency(fret,n,bendSemitones)/(2*pi))
   decays~append(_string~modalDamping(n,articulation))
   /* Existing physical string displacement is A exp(-dt) cos(wt). */
   phases~append(pi/2)
 end
 return .Maths~oscillatorBank(amps,freqs,decays,phases,sampleRate,_context)

::method renderDisplacement
 use strict arg fret,positionFraction,sampleRate,sampleCount,startSample=0,pluckFraction=.18,pluckDisplacementM=.0008,articulation='PICK',bendSemitones=0
 bank=self~displacementBank(fret,positionFraction,sampleRate,pluckFraction,pluckDisplacementM,articulation,bendSemitones)
 return bank~render(sampleCount,startSample)

::method renderPickupFlux
 expose _string _context
 use strict arg fret,fluxGeometry,sampleRate,sampleCount,startSample=0,pluckFraction=.18,pluckDisplacementM=.0008,articulation='PICK',bendSemitones=0
 y=self~renderDisplacement(fret,fluxGeometry~pickupPositionFraction,sampleRate,sampleCount,startSample,pluckFraction,pluckDisplacementM,articulation,bendSemitones)
 out=.array~new
 do i=1 to y~size
   out~append(fluxGeometry~baselineFlux+fluxGeometry~fluxDisplacementGradient*y[i])
 end
 return .GuitarSampledFluxBlock~new(startSample,sampleRate,out,y,_context,fluxGeometry)

::class GuitarSampledFluxBlock public
::method init
 expose _start _rate _flux _displacement _context _geometry
 use strict arg startSample,sampleRate,fluxSamples,displacementVector,context,geometry
 _start=startSample;_rate=sampleRate;_flux=fluxSamples~copy;_displacement=displacementVector;_context=context;_geometry=geometry
::method startSample; expose _start; return _start
::method sampleRate; expose _rate; return _rate
::method fluxSamples; expose _flux; return _flux~copy
::method displacementVector; expose _displacement; return _displacement
::method context; expose _context; return _context
::method geometry; expose _geometry; return _geometry
::method evidence
 expose _displacement
 d=.directory~new
 d['MATHS_EVIDENCE']=_displacement~evidence
 d['COUPLING_SCOPE']='UNCOUPLED_SINGLE_PLUCK_ONLY'
 d['LIVE_STEPPED_STATE']=.false
 return d

::requires 'rxmath' LIBRARY
::requires 'GuitarStringMagnetics.cls'
::requires 'MathsBootstrap.cls'
