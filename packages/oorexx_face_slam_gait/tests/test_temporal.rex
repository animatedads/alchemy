/* Synthetic source-time tests for anonymous projected 2-D limb kinematics. */
numeric digits 30
.environment["FACE_SLAM_CHECKS"]=0
analyser=.FaceSlamGaitTemporal~new(400000,7,500000,.08,12)
features=.array~new
base='1700000000000000'
seq=.array~of(-.28,.24,-.26,.25,-.23,.27,-.22,.20)
do i=1 to seq~items
  left=180; right=180
  if i//2=0 then do; left=145; right=170; end
  else do; left=172; right=143; end
  features~append(.FaceSlamGaitFeature~new('OK','','track-9','video-9',base+(i-1)*100000, -
    left,right,abs(seq[i]),seq[i],140,.9))
end
r=analyser~assess(features)
call check r['status']='MOTION_PERIODICITY_CANDIDATE','cyclic projected ankle and knee evidence'
call check r['ankleOrderReversals']=7,'hysteresis switches'
call check r['durationUs']=700000,'large absolute source timestamps retain microseconds'
call check r['startTimeUs']=base,'source PTS preserved'
call check r['meanReversalIntervalUs']=100000,'source PTS drives temporal intervals'
call check r['leftKneeExcursionDegrees']=27,'left knee movement measured'
call check r['rightKneeExcursionDegrees']=27,'right knee movement measured'
call check r['minimumLandmarkConfidence']=.9,'quality minimum retained'
call check pos('not verified steps',r['interpretation'])>0,'not a step claim'
short=.array~new
short~append(features[1]); short~append(features[2])
call check analyser~assess(short)['status']='INSUFFICIENT','small window abstains'
flat=.array~new
do f over features
  flat~append(.FaceSlamGaitFeature~new('OK','','track-9','video-9',f~timeUs,170,170,.3,f~signedAnkleOffsetTorso,140,.9))
end
call check analyser~assess(flat)['reason']='INSUFFICIENT_KNEE_EXCURSION','no knee motion no periodicity'
uncertain=.array~new
do i=1 to features~items
  f=features[i]
  pos2=0
  if i//2=0 then pos2=.02
  else pos2=-.02
  uncertain~append(.FaceSlamGaitFeature~new('OK','','track-9','video-9',f~timeUs,f~leftKneeDegrees, f~rightKneeDegrees,.3,pos2,140,.9))
end
call check analyser~assess(uncertain)['ankleOrderReversals']=0,'small motion suppressed by hysteresis'
gap=.array~new
do i=1 to features~items
  f=features[i]
  ts=f~timeUs
  if i>4 then ts=ts+900000
  gap~append(.FaceSlamGaitFeature~new('OK','','track-9','video-9',ts,f~leftKneeDegrees,f~rightKneeDegrees,.3,f~signedAnkleOffsetTorso,140,.9))
end
call check analyser~assess(gap)['status']='SEGMENT_REQUIRED','long gap forces segmentation'
replay=.array~new
do f over features; replay~append(f); end
replay[4]=replay[3]
call check analyser~assess(replay)['reason']='NON_MONOTONIC_SOURCE_PTS','replayed PTS blocked'
wrong=.array~new
do f over features; wrong~append(f); end
f=features[4]
wrong[4]=.FaceSlamGaitFeature~new('OK','','different-track','video-9',f~timeUs,180,150,.3,.2,140,.9)
call check analyser~assess(wrong)['reason']='MIXED_TRACK_OR_SOURCE','cross-track interpolation blocked'
call check .FaceSlamGaitTemporal~new~assess(features)['status']='MOTION_PERIODICITY_CANDIDATE','default analyser performs same review'
call check .environment["FACE_SLAM_CHECKS"]=16,'assertion count'
say 'FACE_SLAM_GAIT_TEMPORAL PASS' .environment['FACE_SLAM_CHECKS'] 'checks (synthetic observations; no model inference)'
exit 0
::routine check
  use strict arg ok,reason
  if \ok then raise syntax 88.900 array('FAIL: '||reason)
  .environment["FACE_SLAM_CHECKS"]=.environment["FACE_SLAM_CHECKS"]+1
::requires 'FaceSlamGait.cls'
/* Actual Maths is not invoked here. This is only a temporal-contract test. */
