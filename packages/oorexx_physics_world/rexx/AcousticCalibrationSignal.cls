/* AcousticCalibrationSignal.cls
   Deterministic calibration-signal, Doppler time-warp, known-noise subtraction,
   and overlap-estimation primitives for Physics World.

   These classes are generic.  They contain no F11 localisation decisions. */

::class AcousticPatternStep public
::method init
  expose _name _frequency _on _gap
  use strict arg name,frequencyHz,onSeconds,gapSeconds=0
  _name=name;_frequency=frequencyHz+0;_on=onSeconds+0;_gap=gapSeconds+0
  if _frequency<0 | _on<=0 | _gap<0 then raise syntax 88.900 array('valid acoustic pattern step',name frequencyHz onSeconds gapSeconds)
::method name; expose _name; return _name
::method frequencyHz; expose _frequency; return _frequency
::method onSeconds; expose _on; return _on
::method gapSeconds; expose _gap; return _gap
::method durationSeconds; expose _on _gap; return _on+_gap

::class AcousticWarblerPattern public
::method init
  expose _steps _duration _name
  use strict arg name='calibration-warble',totalDurationSeconds='2.4'
  _name=name;_duration=totalDurationSeconds+0;_steps=.array~new
  if _duration<=0 then raise syntax 88.900 array('positive calibration signal duration',_duration)
::method name; expose _name; return _name
::method totalDurationSeconds; expose _duration; return _duration
::method addStep
  expose _steps
  use strict arg step
  _steps~append(step);return self
::method steps; expose _steps; return _steps~copy
::method cycleDurationSeconds
  expose _steps
  total=0
  do s over _steps; total=total+s~durationSeconds; end
  return total
::method cadenceHz
  c=self~cycleDurationSeconds
  if c<=0 then return 0
  return 1/c
::method stepStateAt
  expose _steps _duration
  use strict arg emissionTime
  t=emissionTime+0
  if t<0 | t>=_duration | _steps~items=0 then return .nil
  cycle=self~cycleDurationSeconds
  if cycle<=0 then return .nil
  local=t//cycle
  elapsed=0
  do i=1 to _steps~items
    s=_steps[i]; endOn=elapsed+s~onSeconds; endStep=elapsed+s~durationSeconds
    if local<endOn then do
      d=.directory~new;d['step']=s;d['index']=i;d['active']=.true;d['localSeconds']=local-elapsed;d['cyclePhaseSeconds']=local;return d
    end
    if local<endStep then do
      d=.directory~new;d['step']=s;d['index']=i;d['active']=.false;d['localSeconds']=local-elapsed;d['cyclePhaseSeconds']=local;return d
    end
    elapsed=endStep
  end
  return .nil
::method frequencyAt
  use strict arg emissionTime
  d=self~stepStateAt(emissionTime)
  if d==.nil then return 0
  if d['active']=.false then return 0
  return d['step']~frequencyHz
::method defaultPipWarbler class
  use strict arg totalDurationSeconds='2.4'
  p=self~new('500-1000-2000-1000 Hz pip warbler',totalDurationSeconds)
  p~addStep(.AcousticPatternStep~new('A',500,'0.080','0.020'))
  p~addStep(.AcousticPatternStep~new('B',1000,'0.080','0.020'))
  p~addStep(.AcousticPatternStep~new('C',2000,'0.080','0.020'))
  p~addStep(.AcousticPatternStep~new('D',1000,'0.080','0.020'))
  return p

::class AcousticDopplerWarp public
::method reflectionRatio class
  use strict arg soundSpeed,reflectorVelocity,sourcePoint,reflectionPoint,receiverPoint
  f=.AcousticDoppler~movingReflectionObserved(1,soundSpeed,reflectorVelocity,sourcePoint,reflectionPoint,receiverPoint)
  return f
::method sourceRatio class
  use strict arg soundSpeed,sourceVelocity,sourcePoint,receiverPoint
  return .AcousticDoppler~movingSourceObserved(1,soundSpeed,sourceVelocity,sourcePoint,receiverPoint)
::method observedFrequency class
  use strict arg referenceFrequencyHz,ratio
  return (referenceFrequencyHz+0)*(ratio+0)
::method observedPeriod class
  use strict arg referencePeriodSeconds,ratio
  if ratio<=0 then raise syntax 88.900 array('positive Doppler time-warp ratio',ratio)
  return (referencePeriodSeconds+0)/ratio
::method observedDuration class
  use strict arg referenceDurationSeconds,ratio
  return self~observedPeriod(referenceDurationSeconds,ratio)
::method observedCadenceHz class
  use strict arg referenceCadenceHz,ratio
  return (referenceCadenceHz+0)*(ratio+0)


::class AcousticMovingReflectionKinematics public
/* Solve the time of the moving reflection event for a specified receive time.
   The vehicle geometry is evaluated at the reflection time, not at receive time.
   Scalar sampling avoids constructing hundreds of evidence-bearing MathVector3
   objects for each iteration; only the winning physical point becomes a vector. */
::method scatterPointAt class
  use strict arg vehicle,sourcePoint,receiverPoint,timeSeconds,uSamples=17,zSamples=5
  o=vehicle~origin;v=vehicle~velocity
  vx=v~x;vy=v~y;horizontal=RxCalcSqrt(vx*vx+vy*vy)
  if horizontal<'0.000000001' then do;ux=1;uy=0;end
  else do;ux=vx/horizontal;uy=vy/horizontal;end
  cx=o~x+vx*(timeSeconds+0);cy=o~y+vy*(timeSeconds+0);half=vehicle~length/2
  ax=cx-half*ux;ay=cy-half*uy;dx=vehicle~length*ux;dy=vehicle~length*uy
  sx=sourcePoint~x;sy=sourcePoint~y;sz=sourcePoint~z;rx=receiverPoint~x;ry=receiverPoint~y;rz=receiverPoint~z
  bestD=.nil;bestX=0;bestY=0;bestZ=0
  do ui=0 to uSamples-1
    u=ui/(uSamples-1);qx=ax+u*dx;qy=ay+u*dy
    do zi=0 to zSamples-1
      qz=(zi/(zSamples-1))*vehicle~height
      d1=RxCalcSqrt((qx-sx)*(qx-sx)+(qy-sy)*(qy-sy)+(qz-sz)*(qz-sz))
      d2=RxCalcSqrt((rx-qx)*(rx-qx)+(ry-qy)*(ry-qy)+(rz-qz)*(rz-qz))
      d=d1+d2
      if bestD==.nil then do;bestD=d;bestX=qx;bestY=qy;bestZ=qz;end
      else if d<bestD then do;bestD=d;bestX=qx;bestY=qy;bestZ=qz;end
    end
  end
  return .MathVector3~new(bestX,bestY,bestZ,sourcePoint~context)
::method solve class
  use strict arg vehicle,sourcePoint,receiverPoint,receiveTime,soundSpeed,maxIterations=8
  tObs=receiveTime+0;c=soundSpeed+0
  if c<=0 then raise syntax 88.900 array('positive acoustic sound speed',c)
  tRef=tObs;q=.nil
  do iter=1 to maxIterations
    q=self~scatterPointAt(vehicle,sourcePoint,receiverPoint,tRef)
    dx=receiverPoint~x-q~x;dy=receiverPoint~y-q~y;dz=receiverPoint~z-q~z
    outgoing=RxCalcSqrt(dx*dx+dy*dy+dz*dz)
    next=tObs-outgoing/c
    if abs(next-tRef)<'0.0000000001' then do;tRef=next;leave;end
    tRef=next
  end
  q=self~scatterPointAt(vehicle,sourcePoint,receiverPoint,tRef)
  ix=q~x-sourcePoint~x;iy=q~y-sourcePoint~y;iz=q~z-sourcePoint~z
  ox=receiverPoint~x-q~x;oy=receiverPoint~y-q~y;oz=receiverPoint~z-q~z
  incoming=RxCalcSqrt(ix*ix+iy*iy+iz*iz);outgoing=RxCalcSqrt(ox*ox+oy*oy+oz*oz)
  tEmit=tRef-incoming/c
  d=.directory~new
  d['receiveTime']=tObs;d['reflectionTime']=tRef;d['emissionTime']=tEmit;d['reflectionPoint']=q
  d['incidentDistanceM']=incoming;d['receiverDistanceM']=outgoing;d['totalDistanceM']=incoming+outgoing
  d['delaySeconds']=(incoming+outgoing)/c
  return d

::class AcousticMovingSourceKinematics public
/* Retarded emission time for a compact moving source observed at receiveTime. */
::method solve class
  use strict arg vehicle,receiverPoint,receiveTime,soundSpeed,maxIterations=12
  tObs=receiveTime+0;c=soundSpeed+0;tEmit=tObs
  do iter=1 to maxIterations
    source=vehicle~sourcePositionAt(tEmit)
    next=tObs-(receiverPoint-source)~norm/c
    if abs(next-tEmit)<'0.0000000001' then do;tEmit=next;leave;end
    tEmit=next
  end
  source=vehicle~sourcePositionAt(tEmit)
  d=.directory~new;d['receiveTime']=tObs;d['emissionTime']=tEmit;d['sourcePoint']=source;d['delaySeconds']=tObs-tEmit
  return d

::class AcousticKnownNoiseSubtractor public
::method subtract class
  use strict arg observedBuffer,knownNoiseBuffer
  if observedBuffer~sampleRateHz<>knownNoiseBuffer~sampleRateHz then raise syntax 88.900 array('matching sample rates for acoustic subtraction')
  if observedBuffer~sampleCount<>knownNoiseBuffer~sampleCount then raise syntax 88.900 array('matching sample counts for acoustic subtraction')
  if observedBuffer~startTime<>knownNoiseBuffer~startTime then raise syntax 88.900 array('matching sample start times for acoustic subtraction')
  out=.array~new
  do i=1 to observedBuffer~sampleCount
    out~append(observedBuffer~pressureAt(i)-knownNoiseBuffer~pressureAt(i))
  end
  return .AcousticSampleBuffer~new(out,observedBuffer~sampleRateHz,observedBuffer~startTime)
::method add class
  use strict arg a,b
  if a~sampleRateHz<>b~sampleRateHz | a~sampleCount<>b~sampleCount | a~startTime<>b~startTime then raise syntax 88.900 array('matching acoustic buffers for addition')
  out=.array~new
  do i=1 to a~sampleCount;out~append(a~pressureAt(i)+b~pressureAt(i));end
  return .AcousticSampleBuffer~new(out,a~sampleRateHz,a~startTime)

::class AcousticOverlapEstimator public
/* Normalized cross-correlation. Positive lag means observed is delayed relative to reference. */
::method estimate class
  use strict arg referenceBuffer,observedBuffer,minLagSamples,maxLagSamples
  if referenceBuffer~sampleRateHz<>observedBuffer~sampleRateHz then raise syntax 88.900 array('matching sample rates for overlap estimation')
  bestLag=0;bestScore=-2;curve=.array~new
  do lag=minLagSamples to maxLagSamples
    sumXY=0;sumX2=0;sumY2=0;count=0
    do i=1 to referenceBuffer~sampleCount
      j=i+lag
      if j<1 | j>observedBuffer~sampleCount then iterate
      x=referenceBuffer~pressureAt(i);y=observedBuffer~pressureAt(j)
      sumXY=sumXY+x*y;sumX2=sumX2+x*x;sumY2=sumY2+y*y;count=count+1
    end
    if count=0 | sumX2<=0 | sumY2<=0 then score=0
    else score=sumXY/RxCalcSqrt(sumX2*sumY2)
    row=.directory~new;row['lagSamples']=lag;row['score']=score;curve~append(row)
    if score>bestScore then do;bestScore=score;bestLag=lag;end
  end
  d=.directory~new;d['lagSamples']=bestLag;d['score']=bestScore;d['curve']=curve
  return d

::class AcousticSyntheticToneFrame public
/* Small deterministic waveform helper for controlled subtraction tests.
   input SPLs are RMS band levels; output is instantaneous pressure in Pa. */
::method pressureAt class
  use strict arg timeSeconds,frequenciesHz,splDbValues
  if frequenciesHz~items<>splDbValues~items then raise syntax 88.900 array('matching frequency/SPL arrays')
  pi=4*RxCalcArcTan(1,30,'R');p=0
  do i=1 to frequenciesHz~items
    if splDbValues[i]==.nil then iterate
    prms=.AcousticLevelMath~pressureForSpl(splDbValues[i])
    p=p+RxCalcSqrt(2)*prms*RxCalcSin(2*pi*frequenciesHz[i]*(timeSeconds+0),30,'R')
  end
  return p

::requires 'AcousticMovingVehicle.cls'
