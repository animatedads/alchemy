/* Peer-relative transient-track outlier tests. */

say 'CAMERA PEER OUTLIER SMOKE START'

tracks=.array~new
tracks~append(buildLinear('A',1000,100,100,10,0,30,20))
tracks~append(buildLinear('B',1000,200,100,10,0,30,20))
tracks~append(buildLinear('C',1000,300,100,10,0,30,20))

/* D is not identified as a person; it is merely the fourth transient track.
   Its movement geometry departs from its three peers. */
d=.CameraTrack~new('D')
call addPoint d,1000,400,100,30,20
call addPoint d,1001,410,110,30,20
call addPoint d,1002,400,120,30,20
call addPoint d,1003,410,130,30,20
call addPoint d,1004,400,140,30,20
tracks~append(d)

peerSet=.CameraPeerOutlierModel~assessTracks(tracks,3,3,2)

call assertEqual 'four subjects assessed',4,peerSet~subjectCount
call assertEqual 'exactly one outlier',1,peerSet~outlierCount
call assertEqual 'D strongest subject','D',peerSet~strongestSubjectId
call assertTrue 'D classified outlier',peerSet~assessment('D')~outlier
call assertTrue 'D shifts at least two features',peerSet~assessment('D')~shiftedFeatureCount>=2
call assertTrue 'A remains normal',\peerSet~assessment('A')~outlier
call assertTrue 'B remains normal',\peerSet~assessment('B')~outlier
call assertTrue 'C remains normal',\peerSet~assessment('C')~outlier
call assertTrue 'compact form names D only',peerSet~compactText~pos('D:')>0
call assertTrue 'compact form excludes A detail',peerSet~compactText~pos('A:')=0

/* Scaling the same motion and box dimensions together should preserve the vector. */
small=buildLinear('SMALL',2000,100,200,10,0,30,20)
large=buildLinear('LARGE',2000,100,200,20,0,60,40)
sv=.CameraTrackBehaviourVector~new(small)
lv=.CameraTrackBehaviourVector~new(large)
call assertNear 'scale-normalized DX',sv~feature('DX'),lv~feature('DX'),0.000001
call assertNear 'scale-normalized LENGTH',sv~feature('LENGTH'),lv~feature('LENGTH'),0.000001
call assertNear 'scale-normalized SPEED',sv~feature('SPEED'),lv~feature('SPEED'),0.000001
call assertNear 'straightness invariant',sv~feature('STRAIGHT'),lv~feature('STRAIGHT'),0.000001

/* Insufficient peers must not manufacture an outlier judgement. */
tooFew=.array~of(tracks[1],tracks[2],tracks[3])
fewResult=.CameraPeerOutlierModel~assessTracks(tooFew,3,3,2)
call assertEqual 'insufficient peer group yields no assessments',0,fewResult~subjectCount
call assertEqual 'insufficient peer group yields no outliers',0,fewResult~outlierCount

say '  peer compact:' peerSet~compactText
say '  D score/features:' peerSet~assessment('D')~score peerSet~assessment('D')~shiftedFeatureCount peerSet~assessment('D')~strongestFeature
say 'CAMERA PEER OUTLIER SMOKE: OK'
exit 0

buildLinear: procedure
  use arg id,startTime,startX,startY,stepX,stepY,width,height
  t=.CameraTrack~new(id)
  do n=0 to 4
    call addPoint t,startTime+n,startX+(stepX*n),startY+(stepY*n),width,height
  end
  return t

addPoint: procedure
  use arg track,timestamp,x,y,width,height
  observation=.CameraObservation~new(timestamp,.CameraBox~new('OBS',x,y,width,height),1,1)
  ignored=track~addObservation(observation)
  return

assertEqual: procedure
  use arg label,expected,actual
  if expected==actual then return .true
  say 'ASSERT FAILED:' label
  say ' expected:' expected
  say ' actual:  ' actual
  exit 1

assertTrue: procedure
  use arg label,actual
  if actual then return .true
  say 'ASSERT FAILED:' label
  exit 1

assertNear: procedure
  use arg label,expected,actual,tolerance
  if abs(expected-actual)<=tolerance then return .true
  say 'ASSERT FAILED:' label
  say ' expected:' expected
  say ' actual:  ' actual
  exit 1

::requires 'CameraCore.cls'
