/* ooRexx Guitar Tab Audio v0.1-dev5
 * Cross-package guitar proof using Physics World dev43 guitar mechanics /
 * acoustic feedback and Rexx-tronics dev25 magnetic pickup + loaded network.
 *
 * Direct fretted-note sequencing remains event-modal in this package for now.
 * Unplayed/open-string sympathetic motion, shared body motion and monitor
 * acoustic feedback are evolved by Physics World dev43 authority.
 */
numeric digits 30

::class GuitarInputGuard public
::method number class
  use strict arg value,label
  if datatype(value,'N')=0 then raise syntax 88.900 array('numeric value required',label,value)
  return value
::method whole class
  use strict arg value,label
  if datatype(value,'W')=0 then raise syntax 88.900 array('whole-number value required',label,value)
  return value

::class GuitarTuning public
::method standard class
  return .array~of(329.6275569,246.9416506,195.9977180,146.8323840,110,82.4068892)
::method dropD class
  a=self~standard; a[6]=73.41619198; return a

::class GuitarRenderConfig public
::method init
  expose _sampleRate _tempo _columnsPerBeat _duration _tuning _selector _mathProvider
  use strict arg sampleRate=8000,tempoBpm=92,columnsPerBeat=4,durationSeconds=4,tuning=.nil,selector='BRIDGE',mathProvider='AUTO'
  if tuning==.nil then tuning=.GuitarTuning~standard
  _sampleRate=.GuitarInputGuard~whole(sampleRate,'sampleRate')
  _tempo=.GuitarInputGuard~number(tempoBpm,'tempoBpm')
  _columnsPerBeat=.GuitarInputGuard~whole(columnsPerBeat,'columnsPerBeat')
  _duration=.GuitarInputGuard~number(durationSeconds,'durationSeconds')
  _tuning=tuning; _selector=selector~upper; _mathProvider=mathProvider~upper
::method sampleRate; expose _sampleRate; return _sampleRate
::method tempoBpm; expose _tempo; return _tempo
::method columnsPerBeat; expose _columnsPerBeat; return _columnsPerBeat
::method durationSeconds; expose _duration; return _duration
::method tuning; expose _tuning; return _tuning
::method selector; expose _selector; return _selector
::method mathProvider; expose _mathProvider; return _mathProvider
::method secondsPerColumn; return 60/self~tempoBpm/self~columnsPerBeat

::class GuitarPerformanceModel public
::method init
  expose _rakeSeconds _microSeconds _forceDepth _releaseBase
  use strict arg rakeMilliseconds=9,microMilliseconds=1.4,forceDepth=.11,releaseMilliseconds=48
  rakeMilliseconds=.GuitarInputGuard~number(rakeMilliseconds,'rakeMilliseconds')
  microMilliseconds=.GuitarInputGuard~number(microMilliseconds,'microMilliseconds')
  _forceDepth=.GuitarInputGuard~number(forceDepth,'forceDepth')
  releaseMilliseconds=.GuitarInputGuard~number(releaseMilliseconds,'releaseMilliseconds')
  _rakeSeconds=rakeMilliseconds/1000
  _microSeconds=microMilliseconds/1000
  _releaseBase=releaseMilliseconds/1000
::method eventsAtColumn
  use strict arg events,column
  n=0
  do e over events
    if e~column=column then n+=1
  end
  return n
::method strokeDirection
  use strict arg column
  if ((column-1)//16)<8 then return 'DOWN'
  return 'UP'
::method timingOffset
  expose _rakeSeconds _microSeconds
  use strict arg ev,events
  same=self~eventsAtColumn(events,ev~column)
  h=((ev~column*37+ev~stringNumber*19)//17)-8
  micro=(h/8)*_microSeconds
  if same<2 then return micro
  dir=self~strokeDirection(ev~column)
  if dir='DOWN' then rank=6-ev~stringNumber
  else rank=ev~stringNumber-1
  return micro + rank*(_rakeSeconds/5)
::method forceScale
  expose _forceDepth
  use strict arg ev
  h=((ev~column*29+ev~stringNumber*13)//11)-5
  scale=1+(h/5)*_forceDepth
  select
    when ev~kind='DEAD' then scale*=.72
    when ev~articulation='HAMMER' then scale*=.78
    when ev~articulation='PULL' then scale*=.74
    when ev~articulation='SLIDE_UP' | ev~articulation='SLIDE_DOWN' then scale*=.86
    otherwise nop
  end
  if scale<.55 then scale=.55
  if scale>1.22 then scale=1.22
  return scale
::method releaseTail
  expose _releaseBase
  use strict arg ev
  h=((ev~column*11+ev~stringNumber*7)//7)-3
  tail=_releaseBase+h*.004
  if ev~kind='DEAD' then tail=.012
  if tail<.015 then tail=.015
  return tail

::class GuitarAmplifierModel public
::method init
  expose _gain _drive _toneHz _sampleRate _toneState
  use strict arg gain=38,drive=7,toneHz=5200,sampleRate=8000
  _gain=.GuitarInputGuard~number(gain,'gain')
  _drive=.GuitarInputGuard~number(drive,'drive')
  _toneHz=.GuitarInputGuard~number(toneHz,'toneHz')
  _sampleRate=.GuitarInputGuard~whole(sampleRate,'sampleRate')
  _toneState=0
::method reset; expose _toneState; _toneState=0
::method process
  expose _gain _drive _toneHz _sampleRate _toneState
  use strict arg input
  pi=4*RxCalcArcTan(1,30,'R')
  alpha=1-RxCalcExp(-2*pi*_toneHz/_sampleRate,30)
  _toneState=_toneState+alpha*(input-_toneState)
  x=_gain*_drive*_toneState
  return x/(1+abs(x))

::class LoudspeakerAcousticModel public
::method init
  expose _sampleRate _mass _resonance _q _forcePerVolt _area _rho _distance _soundSpeed _x _v
  use strict arg sampleRate=8000,massKg=.018,resonanceHz=105,q=.75,forcePerVolt=.55,areaSquareMetres=.012,rho=1.204,distanceMetres=1,soundSpeed=343
  _sampleRate=.GuitarInputGuard~whole(sampleRate,'sampleRate')
  _mass=.GuitarInputGuard~number(massKg,'massKg')
  _resonance=.GuitarInputGuard~number(resonanceHz,'resonanceHz')
  _q=.GuitarInputGuard~number(q,'q')
  _forcePerVolt=.GuitarInputGuard~number(forcePerVolt,'forcePerVolt')
  _area=.GuitarInputGuard~number(areaSquareMetres,'areaSquareMetres')
  _rho=.GuitarInputGuard~number(rho,'rho')
  _distance=.GuitarInputGuard~number(distanceMetres,'distanceMetres')
  _soundSpeed=.GuitarInputGuard~number(soundSpeed,'soundSpeed')
  _x=0; _v=0
::method accelerationForVoltage
  expose _sampleRate _mass _resonance _q _forcePerVolt _x _v
  use strict arg voltage
  pi=4*RxCalcArcTan(1,30,'R'); omega=2*pi*_resonance
  k=_mass*omega*omega; c=_mass*omega/_q
  a=(_forcePerVolt*voltage-c*_v-k*_x)/_mass
  dt=1/_sampleRate; _v=_v+a*dt; _x=_x+_v*dt
  return a
::method pressureForAcceleration
  expose _rho _area _distance
  use strict arg acceleration
  pi=4*RxCalcArcTan(1,30,'R')
  return _rho*_area*acceleration/(4*pi*_distance)
::method propagationDelaySamples
  expose _distance _soundSpeed _sampleRate
  return (_distance/_soundSpeed*_sampleRate)~round

::class GuitarTabRenderer public
::method render class
  use strict arg events,config,gaugeFile=''
  sr=config~sampleRate; dt=1/sr; total=(config~durationSeconds*sr)~trunc
  pi=4*RxCalcArcTan(1,30,'R')
  mathCtx=.MathContext~binary64(config~mathProvider)
  neck=.GuitarMagneticPickup~new('NECK',800,.Units~q(5800,.Units~ohm),.Units~q(2.2,.Units~henry),.Units~q(85E-12,.Units~farad))
  bridge=.GuitarMagneticPickup~new('BRIDGE',800,.Units~q(6400,.Units~ohm),.Units~q(2.6,.Units~henry),.Units~q(95E-12,.Units~farad))
  selector=.GuitarPickupSelector~new(config~selector)
  net=.GuitarLoadedNetwork~new(.Units~q(500000,.Units~ohm),.Units~q(500000,.Units~ohm),.Units~q(22E-9,.Units~farad),.Units~q(470E-12,.Units~farad),.Units~q(1000000,.Units~ohm),.92,.82)
  fluxGradient=.00012
  neckPos=.70; bridgePos=.82; pluckPos=.18; inharm=.00008; modes=6
  player=.GuitarPerformanceModel~new
  direct=.array~new(total); do i=1 to total; direct[i]=0; end
  directByString=.array~new
  do sidx=1 to 6
    sa=.array~new(total); do i=1 to total; sa[i]=0; end
    directByString~append(sa)
  end
  do ev over events
    openHz=config~tuning[ev~stringNumber]
    f0=openHz*RxCalcExp(ev~fret*RxCalcLog(2,30)/12,30)
    perfOffset=player~timingOffset(ev,events)
    start=(((ev~column-1)*config~secondsPerColumn+perfOffset)*sr)~trunc+1
    if start<1 then start=1
    if start>total then iterate
    maxDuration=1.2; nextColumn=0
    do candidate over events
      if candidate~stringNumber<>ev~stringNumber | candidate~column<=ev~column then iterate
      if nextColumn=0 | candidate~column<nextColumn then nextColumn=candidate~column
    end
    if nextColumn>0 then do
      d=(nextColumn-ev~column)*config~secondsPerColumn+player~releaseTail(ev)
      if d<maxDuration then maxDuration=d
    end
    if ev~kind='DEAD' then if maxDuration>.14 then maxDuration=.14
    if maxDuration<.025 then maxDuration=.025
    count=(maxDuration*sr)~trunc; if start+count-1>total then count=total-start+1
    amplitude=.0008*player~forceScale(ev); damp0=2.8; dampN=.018; attack=1
    if ev~kind='DEAD' then do; damp0=20; dampN=.35; amplitude=amplitude*.25; end
    else select
      when ev~articulation='HAMMER' then do; attack=.55; amplitude=amplitude*.65; damp0=3.6; end
      when ev~articulation='PULL' then do; attack=.48; amplitude=amplitude*.60; damp0=4.0; end
      when ev~articulation='SLIDE_UP' | ev~articulation='SLIDE_DOWN' then attack=.72
      otherwise nop
    end
    bankAmps=.array~new; bankFreqs=.array~new; bankDecays=.array~new; bankPhases=.array~new
    do n=1 to modes
      omega=2*pi*f0*n*RxCalcSqrt(1+inharm*n*n,30); freq=omega/(2*pi)
      modal=2*amplitude*RxCalcSin(pi*n*pluckPos,30,'R')/((pi*n)**2*pluckPos*(1-pluckPos))
      ns=RxCalcSin(pi*n*neckPos,30,'R'); bs=RxCalcSin(pi*n*bridgePos,30,'R')
      nv=neck~turns*fluxGradient*modal*ns*omega*attack
      bv=bridge~turns*fluxGradient*modal*bs*omega*attack
      loaded=net~outputMagnitudeForSelector(selector,neck,nv,bridge,bv,.Units~q(freq,.Units~hertz))
      bankAmps~append(-loaded); bankFreqs~append(freq); bankDecays~append(damp0+dampN*n*n); bankPhases~append(0)
    end
    wave=.Maths~oscillatorBank(bankAmps,bankFreqs,bankDecays,bankPhases,sr,mathCtx)~render(count)
    do j=0 to count-1
      idx=start+j; sampleV=wave[j+1]
      direct[idx]=direct[idx]+sampleV
      directByString[ev~stringNumber][idx]=directByString[ev~stringNumber][idx]+sampleV
    end
  end

  models=.array~new
  do f over .array~of(82.4068892,110,146.832384,195.997718,246.9416506,329.6275569)
    models~append(.GuitarStringPhysicalModel~new(f,.648,.00045,75,.00008,2.8,.018,1))
  end
  bodyDefs=.array~of(.GuitarBodyMode~new('BODY-110',110,.20,.035,.045,.55),.GuitarBodyMode~new('BODY-180',180,.16,.045,.055,.75),.GuitarBodyMode~new('BODY-280',280,.12,.055,.035,.45))
  instrument=.GuitarInstrumentFactory~standardSixString(models,.array~of(0,0,0,0,0,0),bodyDefs,.GuitarBoundaryImpedance~new('BRIDGE',1200,.10,1,'dev43 demo bridge'),.nil,0,0,.18)
  feedback=.GuitarAcousticFeedbackDriver~new(instrument,.GuitarAcousticForceCoupling~new(.000002,.045,1,1,'dev43 monitor feedback fixture'))
  schedule=.directory~new
  do ev over events
    idx=(((ev~column-1)*config~secondsPerColumn+player~timingOffset(ev,events))*sr)~trunc+1
    if idx<1 then idx=1
    if idx>total then iterate
    key=idx~string
    a=schedule[key]; if a==.nil then do; a=.array~new; schedule[key]=a; end
    a~append(ev)
  end
  amp=.GuitarAmplifierModel~new(38,7,5200,sr); speaker=.LoudspeakerAcousticModel~new(sr)
  delay=speaker~propagationDelaySamples; delayed=.array~new(total+delay+4); do i=1 to total+delay+4; delayed[i]=0; end
  pickupSamples=.array~new(total); symSamples=.array~new(total); ampSamples=.array~new(total); pressureSamples=.array~new(total)
  symGain=.array~new(6)
  do pidx=1 to 6
    f=models[pidx]~openFrequency
    g=net~outputMagnitudeForSelector(selector,neck,1,bridge,1,.Units~q(f,.Units~hertz))
    symGain[pidx]=g
  end
  if gaugeFile<>'' then call lineout gaugeFile,'time_s,direct_pickup_v,sympathetic_pickup_v,total_pickup_v,amp_out,pressure_pa,body_energy_j,direct_s1_v,direct_s2_v,direct_s3_v,direct_s4_v,direct_s5_v,direct_s6_v,phys_open_E2_j,phys_open_A2_j,phys_open_D3_j,phys_open_G3_j,phys_open_B3_j,phys_open_E4_j'
  do i=1 to total
    a=schedule[i~string]
    if a<>.nil then do ev over a
      if ev~kind='NOTE' then if ev~fret=0 then do
        pidx=7-ev~stringNumber; course=instrument~courses[pidx]; n=0
        do q over course~oscillators
          n+=1; kick=models[pidx]~modalAmplitude(n,.18,.0008)
          if ev~articulation='HAMMER' then kick=kick*.65
          if ev~kind='DEAD' then kick=kick*.2
          q~setState(q~displacement+kick,q~velocity)
        end
      end
    end
    sym=0; pidx=0
    do course over instrument~courses
      pidx+=1
      vn=course~velocityAt(neckPos); vb=course~velocityAt(bridgePos)
      sourceV=-neck~turns*fluxGradient*vn - bridge~turns*fluxGradient*vb
      sym += sourceV*symGain[pidx]
    end
    input=direct[i]+sym
    pickupSamples[i]=input; symSamples[i]=sym
    aout=amp~process(input); ampSamples[i]=aout
    acc=speaker~accelerationForVoltage(aout); p=speaker~pressureForAcceleration(acc)
    delayed[i+delay]=p; pressureSamples[i]=delayed[i]
    obs=.GuitarAcousticPressureObservation~new((i-1)*dt,delayed[i],'monitor-speaker','speaker -> air -> guitar','dev43 integrated demo')
    if i=1 then feedback~step(dt,obs)
    else if i//4=0 then feedback~step(4*dt,obs)
    if gaugeFile<>'' then if i=1 | i//80=0 then do
      be=0; do b over instrument~bodyModes; be+=b~mechanicalEnergy; end
      cs=instrument~courses
      row=((i-1)*dt)','direct[i]','sym','input','aout','delayed[i]','be
      do k=1 to 6; row=row','directByString[k][i]; end
      do k=1 to 6; row=row','cs[k]~mechanicalEnergy; end
      call lineout gaugeFile,row
    end
  end
  if gaugeFile<>'' then call lineout gaugeFile
  pressureBuffer=.AcousticSampleBuffer~new(pressureSamples,.Units~q(sr,.Units~hertz),.Units~q(0,.Units~second))
  out=.directory~new; out['PICKUP']=pickupSamples; out['SYMPATHETIC_PICKUP']=symSamples; out['AMPLIFIER']=ampSamples; out['PRESSURE']=pressureBuffer; out['INSTRUMENT']=instrument
  return out

::requires 'Acoustics.cls'
::requires 'GuitarStringMagnetics.cls'
::requires 'GuitarInstrumentMechanics.cls'
::requires 'GuitarAcousticFeedback.cls'
::requires 'RexxTronicsGuitar.cls'
::requires 'rxmath' LIBRARY

::requires 'MathsBootstrap.cls'
