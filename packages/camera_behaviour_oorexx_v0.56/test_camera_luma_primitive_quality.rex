say 'CAMERA LUMA PRIMITIVE QUALITY SMOKE START'

/* Coherent moving primitive should be admitted. */
good=makeTrack('GOOD',.array~of(2,3,4,5),.array~of(4,4,4,4),.array~of(1,1,1,1))
gq=.CameraLumaPrimitiveQuality~new(good,16,9,2,4)
call assertTrue 'good admitted',gq~admitted
call assertEqual 'good reason','ADMIT',gq~reason
call assertTrue 'good moves',gq~movingStepCount>=1

/* Repeated stationary region is a luminance persistence fragment, not movement. */
static=makeTrack('STATIC',.array~of(5,5,5),.array~of(4,4,4),.array~of(1,1,1))
sq=.CameraLumaPrimitiveQuality~new(static,16,9,2,4)
call assertTrue 'static rejected',\sq~admitted
call assertEqual 'static reason','STATIC_FRAGMENT',sq~reason

/* A primitive living entirely on the frame edge is conservatively excluded. */
edge=makeTrack('EDGE',.array~of(1,2,3,4),.array~of(1,1,1,1),.array~of(1,1,1,1))
eq=.CameraLumaPrimitiveQuality~new(edge,16,9,2,4)
call assertTrue 'edge rejected',\eq~admitted
call assertEqual 'edge reason','EDGE_DOMINATED',eq~reason

/* Wild region-size growth is treated as unstable segmentation. */
first=.CameraLumaTemporalRegion~new(1,4,4,4,4,1,20)
unstable=.CameraLumaTemporalTrack~new('SIZE',first)
ignored=unstable~append(.CameraLumaTemporalRegion~new(2,5,4,8,7,16,30))
ignored=unstable~append(.CameraLumaTemporalRegion~new(3,6,4,6,4,1,25))
uq=.CameraLumaPrimitiveQuality~new(unstable,16,9,2,4)
call assertTrue 'size unstable rejected',\uq~admitted
call assertEqual 'size unstable reason','SIZE_UNSTABLE',uq~reason

paths=.array~new
p1=value('CAMERA_MEDIA_FIXTURE_1',,'ENVIRONMENT')
p2=value('CAMERA_MEDIA_FIXTURE_2',,'ENVIRONMENT')
p3=value('CAMERA_MEDIA_FIXTURE_3',,'ENVIRONMENT')
if p1 == '' then do
  say 'SKIP real media reason=CAMERA_MEDIA_FIXTURE_1 not set'
  say 'CAMERA LUMA PRIMITIVE QUALITY SMOKE: OK'
  exit 0
end
paths~append(p1)
if p2 \== '' then paths~append(p2)
if p3 \== '' then paths~append(p3)

expectedVectors=.array~of(13,3,0)
expectedSubjects=.array~of(13,0,0)
expectedOutliers=.array~of(1,0,0)
clipIndex=0

do path over paths
  clipIndex=clipIndex+1
  source=.CameraFFmpegMediaSource~new(path)
  activity=source~analyzeLumaGrid(16,9,15,12)

  quality=.CameraLumaBehaviourBridge~quality(activity~temporalTracks,16,9,2,4)
  vectors=.CameraLumaBehaviourBridge~qualifiedBehaviourVectors(activity~temporalTracks,40,40,1,16,9,2,4)
  outliers=.CameraLumaBehaviourBridge~qualifiedPeerOutliers(activity~temporalTracks,40,40,1,16,9,2,4,3,3,2)

  call assertEqual 'quality total equals temporal tracks',activity~temporalTracks~trackCount,quality~totalCount
  call assertEqual 'quality conservation',quality~totalCount,quality~admittedCount+quality~rejectedCount
  call assertEqual 'qualified vector count',expectedVectors[clipIndex],vectors~items
  call assertEqual 'peer subject count',expectedSubjects[clipIndex],outliers~subjectCount
  call assertEqual 'peer outlier count',expectedOutliers[clipIndex],outliers~outlierCount

  say '  quality:' path quality~compactText
  say '  peer:' outliers~compactText
  ignored=source~close
end

say 'CAMERA LUMA PRIMITIVE QUALITY SMOKE: OK'
exit 0

makeTrack: procedure
  use arg id,xs,ys,counts
  first=.CameraLumaTemporalRegion~new(1,xs[1],ys[1],xs[1],ys[1],counts[1],20)
  t=.CameraLumaTemporalTrack~new(id,first)
  do i=2 to xs~items
    r=.CameraLumaTemporalRegion~new(i,xs[i],ys[i],xs[i],ys[i],counts[i],20+i)
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
