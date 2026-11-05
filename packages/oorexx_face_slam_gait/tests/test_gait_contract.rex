/* Contract-only geometry regression. This file supplies test-only Maths shims;
   it does NOT prove linked canonical Maths or MediaPipe inference. */
checks=0
.environment["MATHS"] = .Maths
.environment["MATHCONTEXT"] = .MathContext
j=.FaceSlamJoint~new(.45,.5,.9)
call check j~x=.45,'joint x'
call check j~visibility=.9,'joint visibility'
f=makeFrame(1000000,.45,.55)
g=.FaceSlamGaitGeometry~new(.5,12,'TEST_CTX')
r=g~measure(f)
call check r~status='OK','standing pose accepted'
call check abs(r~leftKneeDegrees-180)<.01,'left knee straight'
call check abs(r~rightKneeDegrees-180)<.01,'right knee straight'
call check r~torsoPixels>140,'torso pixel-normalized'
call check r~signedAnkleOffsetTorso<0,'ankle signed offset negative'
t=.FaceSlamGaitTrack~new('fixture','cam-A','track-1','model-digest','source-digest',g)
call check t~add(f)~status='OK','initial track sample accepted'
call check t~add(makeFrame(1100000,.57,.53))~status='OK','second track sample accepted'
call check t~add(makeFrame(1200000,.44,.56))~status='OK','third track sample accepted'
report=t~report
call check report['sampleCount']=3,'report sample count'
call check report['alternations']=2,'two planar ankle order switches'
call check report['durationUs']=200000,'exact source PTS duration'
call check report['status']='DESCRIPTIVE_ONLY','not identity claim'
f2=makeFrame(1300000,.45,.55)
call check g~measure(f2)~confidenceFloor>=.9,'landmark confidence floor'
call check failedDuplicate(t,f2),'duplicate PTS fails closed'
call check failedWrongModel(t),'model mixing fails closed'
call check failedLowConfidence(g),'bad confidence fails closed'
call check .FaceSlamPoseTopology~map('MEDIAPIPE33')['LEFT_HEEL']=29,'MediaPipe heel topology'
call check .FaceSlamPoseTopology~map('COCO17')['LEFT_ANKLE']=15,'COCO ankle topology'
call check \(.FaceSlamPoseTopology~map('COCO17')~hasIndex('LEFT_HEEL')),'COCO heel absent'
p33=.array~new
do i=1 to 33; p33~append(.array~of(.1,.2,1)); end
converted=.FaceSlamPoseTopology~fromOrdered('MEDIAPIPE33',p33)
call check converted['RIGHT_TOE']~visibility=1,'zero-based provider adapter'
say 'FACE_SLAM_GAIT_CONTRACT PASS 22 checks (test-only Maths shim; actual Maths link NOT_RUN)'
exit 0

::routine check
  use strict arg ok,reason
  if \ok then raise syntax 88.900 array('FAIL: '||reason)

::routine makeFrame
  use strict arg pts,leftAx,rightAx
  d=.directory~new
  d['LEFT_SHOULDER']=.FaceSlamJoint~new(.4,.2,.95)
  d['RIGHT_SHOULDER']=.FaceSlamJoint~new(.6,.2,.95)
  d['LEFT_HIP']=.FaceSlamJoint~new(.45,.5,.95)
  d['RIGHT_HIP']=.FaceSlamJoint~new(.55,.5,.95)
  d['LEFT_KNEE']=.FaceSlamJoint~new(.45,.7,.95)
  d['RIGHT_KNEE']=.FaceSlamJoint~new(.55,.7,.95)
  d['LEFT_ANKLE']=.FaceSlamJoint~new(leftAx,.9,.95)
  d['RIGHT_ANKLE']=.FaceSlamJoint~new(rightAx,.9,.95)
  return .FaceSlamPoseFrame~new('fixture','cam-A','track-1',pts,640,480,d,'model-digest','source-digest')
::routine failedDuplicate
  signal on syntax name expected
  use strict arg t,f
  ignored=t~add(f)
  ignored=t~add(f)
  return .false
expected: return .true
::routine failedWrongModel
  signal on syntax name expected
  use strict arg t
  f=makeFrame(1500000,.45,.55)
  d=.directory~new
  do name over .array~of('LEFT_SHOULDER','RIGHT_SHOULDER')
    d[name]=f~joint(name)
  end
  bad=.FaceSlamPoseFrame~new('fixture','cam-A','track-1',1500000,640,480,d,'model-different','source-digest')
  ignored=t~add(bad)
  return .false
expected: return .true
::routine failedLowConfidence
  use strict arg g
  d=.directory~new
  d['LEFT_HIP']=.FaceSlamJoint~new(.45,.5,.1)
  f=.FaceSlamPoseFrame~new('fixture','cam-A','track-1',10000,640,480,d,'model-digest','source-digest')
  return g~measure(f)~status='INSUFFICIENT'

/* TEST-ONLY stand-ins to exercise integration shape without claiming
   production Maths availability. Production uses MathsBootstrap.cls. */
::class MathContext public
::method decimal class
  use strict arg digits
  return 'TEST_CTX'
::class TestMathAngle public
::attribute degreesValue get
::method init
  expose degreesValue
  use strict arg degreesValue
::class Maths public
::method sqrt class
  use strict arg value,ctx=.nil
  return RxCalcSqrt(value,16)
::method atan2 class
  use strict arg y,x,ctx=.nil
  if x>0 then a=RxCalcArcTan(y/x,16,'D')
  else if x<0 then do
    a=RxCalcArcTan(y/x,16,'D')
    if y>=0 then a=a+180
    else a=a-180
  end
  else do
    if y>0 then a=90
    else if y<0 then a=-90
    else a=0
  end
  return .TestMathAngle~new(a)
::routine RxCalcArcTan external "LIBRARY rxmath RxCalcArcTan"
::routine RxCalcSqrt external "LIBRARY rxmath RxCalcSqrt"
::requires 'FaceSlamGait.cls'
