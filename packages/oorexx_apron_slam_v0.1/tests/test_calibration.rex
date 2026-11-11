/* Synthetic camera/road/vehicle trials only: NO real plate or video. */
numeric digits 30
checks=0
basis=.ApronRoadBasis~new(0,1,0,1,0,1)
cam=.ApronRoadCamera~new(2560,1440,1000,1000,5,basis)
road=.ApronRoadSection~new(6.4,8)
car=.ApronRoadCarBox~new(4.4,1.82,1.53)
trueScene=.ApronRoadScene~new(cam,road,car,35,8,6)
wrongCamera=.ApronRoadCamera~new(2560,1440,850,850,5,basis)
wrongScene=.ApronRoadScene~new(wrongCamera,road,car,35,8,6)
wrongSpeed=.ApronRoadScene~new(cam,road,car,35,8,2)
h1=.ApronRoadHypothesis~new('TRUE_SYNTHETIC',trueScene)
h2=.ApronRoadHypothesis~new('WRONG_FOCAL',wrongScene)
h3=.ApronRoadHypothesis~new('WRONG_SPEED',wrongSpeed)
obs=.ApronCalibrationTrack~new('synthetic-source','synthetic-track')
base=987654321012345
/* First three points are insufficient by deliberate design. */
do i=0 to 2
  t=i*.2
  s=.ApronCalibrationSample~new(base+trunc(t*1000000),trueScene~projectedBoxAt(t),2560,1440,2)
  ignore=obs~add(s)
end
r=.ApronRoadCalibrator~new~evaluate(.array~of(h1,h2),obs)
call equal 'INSUFFICIENT',r~status,'three points insufficient'
call equal 0,r~scores~items,'no scoring on under-observed sequence'
do i=3 to 5
  t=i*.2
  ignore=obs~add(.ApronCalibrationSample~new(base+trunc(t*1000000),trueScene~projectedBoxAt(t),2560,1440,2))
end
call equal 6,obs~count,'synthetic sample count'
call equal 1000000,obs~spanUs,'span uses exact integer microseconds'
r=.ApronRoadCalibrator~new~evaluate(.array~of(h2,h1,h3),obs)
call equal 'UNANCHORED',r~status,'no metric anchor, no absolute calibration'
call equal 'TRUE_SYNTHETIC',r~best~label,'best known synthetic geometry'
call near 0,r~best~normalizedCost,.000000001,'perfect box residual is zero'
if r~runnerUp~normalizedCost<=r~best~normalizedCost then call fail 'wrong model must lose'
checks+=1
/* Two identical geometry alternatives must not become a false certainty. */
duplicate=.ApronRoadHypothesis~new('EQUIVALENT',trueScene)
r=.ApronRoadCalibrator~new~evaluate(.array~of(h1,duplicate),obs)
call equal 'AMBIGUOUS',r~status,'unidentifiable geometry returns ambiguity'
/* A visually estimated road width does NOT establish a surveyed scale. */
edges=trueScene~roadEdgesAt(20)
a=.ApronRoadAnchor~new(20,edges[1],edges[2],2,'ESTIMATED')
ignore=obs~addAnchor(a)
r=.ApronRoadCalibrator~new~evaluate(.array~of(h2,h1,h3),obs)
call equal 'UNANCHORED',r~status,'estimated road anchor cannot qualify calibration'
call equal 1,obs~estimatedAnchorCount,'estimated anchor recorded separately'
/* Independent surveyed anchors improve a conditional geometry fit. */
surveyed=.ApronRoadAnchor~new(24,trueScene~roadEdgesAt(24)[1],trueScene~roadEdgesAt(24)[2],2,'SURVEYED')
ignore=obs~addAnchor(surveyed)
r=.ApronRoadCalibrator~new~evaluate(.array~of(h1,h2,h3),obs)
call equal 'MODEL_CONSISTENT',r~status,'surveyed anchor can make model consistent'
call equal 1,obs~surveyedAnchorCount,'surveyed anchor recorded separately'
call equal 2,r~best~roadAnchorCount,'both physical anchor observations included'
/* A wrong lone model must abstain, even with a surveyed control point. */
r=.ApronRoadCalibrator~new~evaluate(.array~of(h2),obs,1)
call equal 'HIGH_RESIDUAL',r~status,'bad model must not claim fit'
/* Geometry sampling is a threshold, never a registration probability. */
gate=.ApronPlateSamplingGate~new
far=gate~evaluate(trueScene,.2,10000)
call equal 'UNDERSAMPLED',far~status,'distant character below spatial threshold'
call equal .nil,far~exposureSmearSquared,'no blur claim if already undersampled'
nearScene=.ApronRoadScene~new(cam,road,car,8,8,0)
sample=gate~evaluate(nearScene,.5)
call equal 'EXPOSURE_UNKNOWN',sample~status,'no shutter assumption from frame rate'
sample=gate~evaluate(nearScene,.5,1000)
call equal 'GEOMETRICALLY_SAMPLED',sample~status,'close stationary geometry is theoretically eligible'
ignore=obs~close
call equal 0,obs~count,'close clears observations'
call equal 0,obs~surveyedAnchorCount,'close clears anchor counts'
say 'PASS Apron dev4 calibration and pixel sampling checks='checks
exit 0
near: procedure expose checks
 use strict arg expected,actual,tol,label
 if abs(expected-actual)>tol then call fail label||' expected='||expected||' actual='||actual
 checks+=1
 return
equal: procedure expose checks
 use strict arg expected,actual,label
 if expected<>actual then call fail label||' expected='||expected||' actual='||actual
 checks+=1
 return
fail: procedure
 use strict arg message
 say 'FAIL:' message
 exit 1
::requires '../src/ApronRoadCalibration.cls'
