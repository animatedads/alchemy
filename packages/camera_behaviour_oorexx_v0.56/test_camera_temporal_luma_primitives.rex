say 'CAMERA TEMPORAL LUMA PRIMITIVE SMOKE START'

/* Synthetic four-frame movement: one changed cell moves right each comparison. */
m=.CameraLumaActivityMap~new('synthetic',4,2,1,10)
f1=.array~of(100,100,100,100,100,100,100,100)
f2=.array~of(140,100,100,100,100,100,100,100)
f3=.array~of(100,140,100,100,100,100,100,100)
f4=.array~of(100,100,140,100,100,100,100,100)
ignored=m~observeFrameSamples(.nil,f1)
ignored=m~observeFrameSamples(f1,f2)
ignored=m~observeFrameSamples(f2,f3)
ignored=m~observeFrameSamples(f3,f4)

tracks=m~temporalTracks
call assertEqual 'synthetic comparisons',3,tracks~comparisonCount
call assertTrue 'synthetic regions exist',tracks~regionCount>=3
call assertTrue 'persistent temporal track exists',tracks~persistentTrackCount>=1
call assertTrue 'longest temporal track spans multiple samples',tracks~longestTrackObservations>=2
call assertTrue 'compact temporal prefix',tracks~compactText~pos('CLT1|CMP=3|')=1

paths=.array~new
p1=value('CAMERA_MEDIA_FIXTURE_1',,'ENVIRONMENT')
p2=value('CAMERA_MEDIA_FIXTURE_2',,'ENVIRONMENT')
p3=value('CAMERA_MEDIA_FIXTURE_3',,'ENVIRONMENT')
if p1 == '' then do
  say 'SKIP real media reason=CAMERA_MEDIA_FIXTURE_1 not set'
  say 'CAMERA TEMPORAL LUMA PRIMITIVE SMOKE: OK'
  exit 0
end
paths~append(p1)
if p2 \== '' then paths~append(p2)
if p3 \== '' then paths~append(p3)

count=0
do path over paths
  source=.CameraFFmpegMediaSource~new(path)
  activity=source~analyzeLumaGrid(16,9,15,12)
  temporal=activity~temporalTracks
  call assertEqual 'real comparisons',59,temporal~comparisonCount
  call assertTrue 'region count nonnegative',temporal~regionCount>=0
  call assertTrue 'track count nonnegative',temporal~trackCount>=0
  call assertTrue 'persistent bounded by tracks',temporal~persistentTrackCount<=temporal~trackCount
  call assertTrue 'compact temporal emitted',temporal~compactText~pos('CLT1|CMP=59|')=1
  say '  temporal:' path temporal~compactText
  ignored=source~close
  count=count+1
end
call assertEqual 'three real fixtures analyzed',3,count

say 'CAMERA TEMPORAL LUMA PRIMITIVE SMOKE: OK'
exit 0

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

::requires 'CameraFFmpegMediaSource.cls'
