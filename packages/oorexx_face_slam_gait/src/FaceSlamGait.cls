/* Face SLAM gait geometry v0.1-dev2.
 * Architecture: ooRexx owns observations and gait semantics.
 * Perception owns pose inference, Motion Control owns tracks,
 * Maths owns sqrt and angular evaluation.
 * This module neither discovers nor identifies people.
 * Input is source-PTS-tagged 2D skeletons from an authorised provider.
 */

::class FaceSlamJoint public
::attribute x get
::attribute y get
::attribute visibility get
::method init
  expose x y visibility
  use strict arg x, y, visibility=1
  if \x~datatype('N') | \y~datatype('N') | \visibility~datatype('N') then -
    raise syntax 88.900 array('joint coordinate and visibility must be numeric')
  if visibility<0 | visibility>1 then -
    raise syntax 88.900 array('joint visibility must be between zero and one')
  x=x+0; y=y+0; visibility=visibility+0

::class FaceSlamPoseFrame public
::attribute sourceId get
::attribute cameraId get
::attribute trackId get
::attribute timeUs get
::attribute width get
::attribute height get
::attribute modelDigest get
::attribute sourceDigest get
::attribute coordinateSpace get
::method init
  expose sourceId cameraId trackId timeUs width height modelDigest sourceDigest coordinateSpace joints
  use strict arg sourceId,cameraId,trackId,timeUs,width,height,landmarks,modelDigest,sourceDigest,coordinateSpace='NORMALIZED_IMAGE'
  numeric digits 30
  if sourceId='' | cameraId='' | trackId='' | modelDigest='' | sourceDigest='' then -
    raise syntax 88.900 array('source/camera/track/model/source digest required')
  if \timeUs~datatype('W') | timeUs<0 then -
    raise syntax 88.900 array('source time must be nonnegative integer microseconds')
  if \width~datatype('W') | \height~datatype('W') | width<1 | height<1 then -
    raise syntax 88.900 array('valid frame dimensions required')
  if coordinateSpace\='NORMALIZED_IMAGE' then -
    raise syntax 88.900 array('dev1 supports normalized image coordinates only, not inferred 3D')
  if \landmarks~isA(.Directory) then -
    raise syntax 88.900 array('landmarks must be a Directory')
  joints=.directory~new
  do name over landmarks~allIndexes
    joint=landmarks[name]
    if \joint~isA(.FaceSlamJoint) then raise syntax 88.900 array('invalid joint object',name)
    joints[name~translate]=joint
  end
  numeric digits 30
  timeUs=timeUs+0; width=width+0; height=height+0
::method joint
  expose joints
  use strict arg name,minimumVisibility=0
  name=name~translate
  if \joints~hasIndex(name) then return .nil
  j=joints[name]
  if j~visibility<minimumVisibility then return .nil
  return j
::method point
  expose width height
  use strict arg name,minimumVisibility=0
  j=self~joint(name,minimumVisibility)
  if j==.nil then return .nil
  return .array~of(j~x*width,j~y*height)

::class FaceSlamGaitFeature public
::attribute status get
::attribute reason get
::attribute trackId get
::attribute sourceId get
::attribute timeUs get
::attribute leftKneeDegrees get
::attribute rightKneeDegrees get
::attribute ankleSeparationTorso get
::attribute signedAnkleOffsetTorso get
::attribute torsoPixels get
::attribute confidenceFloor get
::method init
  expose status reason trackId sourceId timeUs leftKneeDegrees rightKneeDegrees -
    ankleSeparationTorso signedAnkleOffsetTorso torsoPixels confidenceFloor
  use strict arg status,reason,trackId,sourceId,timeUs,leftKneeDegrees=.nil,rightKneeDegrees=.nil, -
    ankleSeparationTorso=.nil,signedAnkleOffsetTorso=.nil,torsoPixels=.nil,confidenceFloor=.nil
::method featureRow
  if self~status\='OK' then return .nil
  return .array~of(self~leftKneeDegrees,self~rightKneeDegrees, -
    self~ankleSeparationTorso,self~signedAnkleOffsetTorso)

::class FaceSlamGaitGeometry public
::attribute minVisibility get
::attribute minimumTorsoPixels get
::attribute context get
::method init
  expose minVisibility minimumTorsoPixels context
  use strict arg minVisibility='0.65',minimumTorsoPixels=12,context=.nil
  if context==.nil then context=.MathContext~decimal(35)
  if minVisibility<0 | minVisibility>1 | minimumTorsoPixels<=0 then -
    raise syntax 88.900 array('invalid gait geometry gate')
::method length2 private
  expose context
  use strict arg a,b
  dx=a[1]-b[1]; dy=a[2]-b[2]
  return .Maths~sqrt(dx*dx+dy*dy,context)
::method midpoint private
  use strict arg a,b
  return .array~of((a[1]+b[1])/2,(a[2]+b[2])/2)
::method angleAt private
  expose context
  use strict arg first,vertex,last
  ux=first[1]-vertex[1]; uy=first[2]-vertex[2]
  vx=last[1]-vertex[1]; vy=last[2]-vertex[2]
  cross=ux*vy-uy*vx; dot=ux*vx+uy*vy
  if cross=0 & dot=0 then return .nil
  return .Maths~atan2(abs(cross),dot,context)~degreesValue
::method measure
  expose minVisibility minimumTorsoPixels
  use strict arg frame
  required=.array~of('LEFT_SHOULDER','RIGHT_SHOULDER','LEFT_HIP','RIGHT_HIP', -
    'LEFT_KNEE','RIGHT_KNEE','LEFT_ANKLE','RIGHT_ANKLE')
  p=.directory~new; floor=1
  do name over required
    j=frame~joint(name,minVisibility)
    if j==.nil then return .FaceSlamGaitFeature~new('INSUFFICIENT','MISSING_OR_LOW_VISIBILITY:'||name,frame~trackId,frame~sourceId,frame~timeUs)
    p[name]=frame~point(name,minVisibility)
    if j~visibility<floor then floor=j~visibility
  end
  shoulderMid=self~midpoint(p['LEFT_SHOULDER'],p['RIGHT_SHOULDER'])
  hipMid=self~midpoint(p['LEFT_HIP'],p['RIGHT_HIP'])
  torso=self~length2(shoulderMid,hipMid)
  if torso<minimumTorsoPixels then return .FaceSlamGaitFeature~new('INSUFFICIENT','TORSO_TOO_SMALL',frame~trackId,frame~sourceId,frame~timeUs)
  left=self~angleAt(p['LEFT_HIP'],p['LEFT_KNEE'],p['LEFT_ANKLE'])
  right=self~angleAt(p['RIGHT_HIP'],p['RIGHT_KNEE'],p['RIGHT_ANKLE'])
  if left==.nil | right==.nil then return .FaceSlamGaitFeature~new('INSUFFICIENT','DEGENERATE_KNEE',frame~trackId,frame~sourceId,frame~timeUs)
  dx=p['LEFT_ANKLE'][1]-p['RIGHT_ANKLE'][1]
  ankleSep=self~length2(p['LEFT_ANKLE'],p['RIGHT_ANKLE'])/torso
  return .FaceSlamGaitFeature~new('OK','',frame~trackId,frame~sourceId,frame~timeUs, -
    left,right,ankleSep,dx/torso,torso,floor)

::class FaceSlamGaitTrack public
::attribute sourceId get
::attribute cameraId get
::attribute trackId get
::attribute modelDigest get
::attribute sourceDigest get
::attribute samples get
::attribute lastTimeUs get
::method init
  expose sourceId cameraId trackId modelDigest sourceDigest samples lastTimeUs geometry
  use strict arg sourceId,cameraId,trackId,modelDigest,sourceDigest,geometry=.nil
  if geometry==.nil then geometry=.FaceSlamGaitGeometry~new
  samples=.array~new; lastTimeUs=-1
::method add
  expose sourceId cameraId trackId modelDigest sourceDigest samples lastTimeUs geometry
  use strict arg frame
  numeric digits 30
  if frame~sourceId\==sourceId | frame~cameraId\==cameraId | frame~trackId\==trackId | -
    frame~modelDigest\==modelDigest | frame~sourceDigest\==sourceDigest then -
    raise syntax 88.900 array('track source/camera/model/digest mismatch')
  if frame~timeUs<=lastTimeUs then raise syntax 88.900 array('non-increasing source PTS')
  lastTimeUs=frame~timeUs
  f=geometry~measure(frame)
  if f~status='OK' then samples~append(f)
  return f
::method temporal
  expose samples
  use strict arg analyser=.nil
  if analyser==.nil then analyser=.FaceSlamGaitTemporal~new
  return analyser~assess(samples)
::method report
  expose samples sourceId trackId
  numeric digits 30
  out=.directory~new
  out['trackId']=trackId; out['sourceId']=sourceId; out['sampleCount']=samples~items
  out['status']='INSUFFICIENT'; out['alternations']=0
  if samples~items<3 then return out
  leftSum=0; rightSum=0; leftLo=999; rightLo=999; leftHi=-999; rightHi=-999
  signs=0; alternations=0
  do f over samples
    left=f~leftKneeDegrees; right=f~rightKneeDegrees
    leftSum=leftSum+left; rightSum=rightSum+right
    if left<leftLo then leftLo=left
    if right<rightLo then rightLo=right
    if left>leftHi then leftHi=left
    if right>rightHi then rightHi=right
    currentSign=0
    if f~signedAnkleOffsetTorso>0 then currentSign=1
    if f~signedAnkleOffsetTorso<0 then currentSign=-1
    if currentSign\=0 then do
      if signs\=0 & signs\=currentSign then alternations=alternations+1
      signs=currentSign
    end
  end
  out['status']='DESCRIPTIVE_ONLY'
  out['meanLeftKneeDeg']=leftSum/samples~items
  out['meanRightKneeDeg']=rightSum/samples~items
  out['leftRangeDeg']=leftHi-leftLo
  out['rightRangeDeg']=rightHi-rightLo
  out['alternations']=alternations
  out['durationUs']=samples[samples~items]~timeUs-samples[1]~timeUs
  out['interpretation']='2D projected kinematics, NOT identified steps, gait identity or ground speed'
  return out

/* Exact topology mapping. Providers must not silently treat COCO's 17
 * landmarks as MediaPipe's 33 or treat a 2-D coordinate as measured depth.
 * A provider adapter supplies one Array per landmark: x,y,visibility.
 */
::class FaceSlamPoseTopology public
::method map class
  use strict arg name
  name=name~translate
  d=.directory~new
  if name='MEDIAPIPE33' then do
    d['LEFT_SHOULDER']=11; d['RIGHT_SHOULDER']=12
    d['LEFT_ELBOW']=13; d['RIGHT_ELBOW']=14
    d['LEFT_WRIST']=15; d['RIGHT_WRIST']=16
    d['LEFT_HIP']=23; d['RIGHT_HIP']=24
    d['LEFT_KNEE']=25; d['RIGHT_KNEE']=26
    d['LEFT_ANKLE']=27; d['RIGHT_ANKLE']=28
    d['LEFT_HEEL']=29; d['RIGHT_HEEL']=30
    d['LEFT_TOE']=31; d['RIGHT_TOE']=32
    return d
  end
  if name='COCO17' then do
    d['LEFT_SHOULDER']=5; d['RIGHT_SHOULDER']=6
    d['LEFT_ELBOW']=7; d['RIGHT_ELBOW']=8
    d['LEFT_WRIST']=9; d['RIGHT_WRIST']=10
    d['LEFT_HIP']=11; d['RIGHT_HIP']=12
    d['LEFT_KNEE']=13; d['RIGHT_KNEE']=14
    d['LEFT_ANKLE']=15; d['RIGHT_ANKLE']=16
    return d
  end
  raise syntax 88.900 array('unrecognised pose landmark topology',name)
::method fromOrdered class
  use strict arg name,landmarks
  if \landmarks~isA(.Array) then raise syntax 88.900 array('ordered landmarks must be Array')
  mapping=self~map(name)
  out=.directory~new
  do jointName over mapping~allIndexes
    providerIndex=mapping[jointName]+1  /* providers index from zero; ooRexx from one */
    if providerIndex>landmarks~items then iterate
    item=landmarks[providerIndex]
    if item==.nil then iterate
    if \item~isA(.Array) | item~items<3 then -
      raise syntax 88.900 array('landmark must have x,y,visibility',jointName)
    out[jointName]=.FaceSlamJoint~new(item[1],item[2],item[3])
  end
  return out

::requires 'FaceSlamGaitTemporal.cls'
