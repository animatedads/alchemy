numeric digits 20
pattern=.AcousticWarblerPattern~defaultPipWarbler(2.4)
call near pattern~cycleDurationSeconds,0.4,'cycle duration'
call near pattern~cadenceHz,2.5,'cadence'
if pattern~frequencyAt(0.01)<>500 then do;say 'FAIL first pip';exit 1;end
if pattern~frequencyAt(0.09)<>0 then do;say 'FAIL first gap';exit 1;end
if pattern~frequencyAt(0.11)<>1000 then do;say 'FAIL second pip';exit 1;end
if pattern~frequencyAt(0.21)<>2000 then do;say 'FAIL third pip';exit 1;end
if pattern~frequencyAt(0.31)<>1000 then do;say 'FAIL fourth pip';exit 1;end
if pattern~frequencyAt(2.41)<>0 then do;say 'FAIL fixed duration';exit 1;end

ctx=.Maths~defaultContext
source=.MathVector3~new(0,0,4.8,ctx);q=.MathVector3~new(5,0,1,ctx);receiver=.MathVector3~new(10,2,4.8,ctx)
vel=.MathVector3~new(11.111111111111111,0,0,ctx);c=343
ratio=.AcousticDopplerWarp~reflectionRatio(c,vel,source,q,receiver)
if ratio<=0 then do;say 'FAIL reflection ratio';exit 1;end
call near .AcousticDopplerWarp~observedCadenceHz(pattern~cadenceHz,ratio)/pattern~cadenceHz,ratio,'pitch/cadence common warp','0.000000001'
call near pattern~cycleDurationSeconds/.AcousticDopplerWarp~observedPeriod(pattern~cycleDurationSeconds,ratio),ratio,'period common warp','0.000000001'

samples=.array~new;noise=.array~new;observed=.array~new
sampleRate=1000;count=100
pi=4*RxCalcArcTan(1,30,'R')
do i=0 to count-1
  x=RxCalcSin(2*pi*25*i/sampleRate,30,'R')
  n='0.3'*RxCalcSin(2*pi*70*i/sampleRate,30,'R')
  samples~append(x);noise~append(n);observed~append(x+n)
end
ref=.AcousticSampleBuffer~new(samples,sampleRate,0)
nb=.AcousticSampleBuffer~new(noise,sampleRate,0)
ob=.AcousticSampleBuffer~new(observed,sampleRate,0)
res=.AcousticKnownNoiseSubtractor~subtract(ob,nb)
do i=1 to count
  call near res~pressureAt(i),ref~pressureAt(i),'known-noise pressure subtraction','0.00000001'
end

shifted=.array~new
do i=1 to count
  j=i-7
  if j>=1 then shifted~append(ref~pressureAt(j));else shifted~append(0)
end
sb=.AcousticSampleBuffer~new(shifted,sampleRate,0)
est=.AcousticOverlapEstimator~estimate(ref,sb,-15,15)
if est['lagSamples']<>7 then do;say 'FAIL overlap lag expected 7 got' est['lagSamples'];exit 1;end
say 'PASS acoustic calibration signal / subtraction / overlap'
say 'doppler_ratio='ratio
say 'observed_cadence_hz='.AcousticDopplerWarp~observedCadenceHz(pattern~cadenceHz,ratio)
exit 0
near: procedure
  use arg actual,expected,label,tolerance='0.000001'
  if abs(actual-expected)>tolerance then do;say 'FAIL' label 'actual='actual 'expected='expected;exit 1;end
return
::requires 'AcousticCalibrationSignal.cls'
