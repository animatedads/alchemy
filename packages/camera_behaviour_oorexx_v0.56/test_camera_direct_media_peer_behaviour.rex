say 'CAMERA DIRECT MEDIA PEER BEHAVIOUR SMOKE START'

/* Synthetic A/B/C ordinary and D geometrically different, expressed first as
   luma temporal primitives, then converted through the exact production bridge. */
tracks=.CameraLumaTemporalTrackSet~new('synthetic',16,9,2.5)

a=makePrimitive('A',1,.array~of(1,2,3,4,5),.array~of(1,2,3,4,5),.array~of(3,3,3,3,3))
b=makePrimitive('B',1,.array~of(1,2,3,4,5),.array~of(2,3,4,5,6),.array~of(3,3,3,3,3))
c=makePrimitive('C',1,.array~of(1,2,3,4,5),.array~of(3,4,5,6,7),.array~of(3,3,3,3,3))
d=makePrimitive('D',1,.array~of(1,2,3,4,5),.array~of(4,5,4,5,4),.array~of(3,4,5,6,7))

synthetic=.array~of(a,b,c,d)
cameraTracks=.array~new
do primitive over synthetic
  cameraTracks~append(.CameraLumaBehaviourBridge~toCameraTrack(primitive,40,40,1))
end
peer=.CameraPeerOutlierModel~assessTracks(cameraTracks,3,3,2)
call assertEqual 'four synthetic subjects',4,peer~subjectCount
call assertEqual 'one synthetic outlier',1,peer~outlierCount
call assertEqual 'D synthetic outlier','D',peer~strongestSubjectId
call assertTrue 'D flagged',peer~assessment('D')~outlier

/* Real MP4 path. */
paths=.array~new
p1=value('CAMERA_MEDIA_FIXTURE_1',,'ENVIRONMENT')
p2=value('CAMERA_MEDIA_FIXTURE_2',,'ENVIRONMENT')
p3=value('CAMERA_MEDIA_FIXTURE_3',,'ENVIRONMENT')
if p1 == '' then do
  say 'SKIP real media reason=CAMERA_MEDIA_FIXTURE_1 not set'
  say 'CAMERA DIRECT MEDIA PEER BEHAVIOUR SMOKE: OK'
  exit 0
end
paths~append(p1)
if p2 \== '' then paths~append(p2)
if p3 \== '' then paths~append(p3)

counts=.array~new
do path over paths
  source=.CameraFFmpegMediaSource~new(path)
  activity=source~analyzeLumaGrid(16,9,15,12)
  vectors=.CameraLumaBehaviourBridge~behaviourVectors(activity~temporalTracks,40,40,1,2)
  outliers=.CameraLumaBehaviourBridge~peerOutliers(activity~temporalTracks,40,40,1,2,3,3,2)

  call assertEqual 'vectors equal persistent temporal tracks',activity~temporalTracks~persistentTrackCount,vectors~items
  call assertTrue 'outlier subject count bounded by vectors',outliers~subjectCount<=vectors~items
  if vectors~items < 4 then call assertEqual 'insufficient peer population suppresses assessment',0,outliers~subjectCount

  say '  direct peer:' path 'V='vectors~items outliers~compactText
  counts~append(vectors~items)
  ignored=source~close
end

call assertEqual 'fixture1 vectors',19,counts[1]
call assertEqual 'fixture2 vectors',10,counts[2]
call assertEqual 'fixture3 vectors',3,counts[3]

say 'CAMERA DIRECT MEDIA PEER BEHAVIOUR SMOKE: OK'
exit 0

makePrimitive: procedure
  use arg id,startSample,xs,ys
  first=.CameraLumaTemporalRegion~new(startSample,xs[1],ys[1],xs[1],ys[1],1,20)
  t=.CameraLumaTemporalTrack~new(id,first)
  do i=2 to xs~items
    r=.CameraLumaTemporalRegion~new(startSample+i-1,xs[i],ys[i],xs[i],ys[i],1,20+i)
    ignored=t~append(r)
  end
  return t

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

::requires 'CameraLumaBehaviourBridge.cls'
