say 'CAMERA ADAPTIVE LUMA HIERARCHY SMOKE START'

/* Exact synthetic proof: one active fine cell should not force 16 cells to be stored. */
m=.CameraLumaActivityMap~new('synthetic',4,4,1,10)
a=.array~new
b=.array~new
do n=1 to 16
  a~append(100)
  b~append(100)
end
b[16]=140
ignored=m~observeFrameSamples(.nil,a)
ignored=m~observeFrameSamples(a,b)
h=m~hierarchy(8)
call assertEqual 'synthetic active fine cell',1,h~activeFineCellCount
call assertTrue 'hierarchy uses fewer leaves than fine grid',h~leafCount<16
call assertEqual 'leaf partition conservation',h~leafCount,h~invariantLeafCount+h~activeLeafCount
call assertEqual 'one active leaf',1,h~activeLeafCount
call assertTrue 'hierarchy actually descends',h~maximumDepth>0
call assertTrue 'compact hierarchy prefix',h~compactText~pos('CLH1|G=4x4|')=1

paths=.array~new
p1=value('CAMERA_MEDIA_FIXTURE_1',,'ENVIRONMENT')
p2=value('CAMERA_MEDIA_FIXTURE_2',,'ENVIRONMENT')
p3=value('CAMERA_MEDIA_FIXTURE_3',,'ENVIRONMENT')
if p1 == '' then do
  say 'SKIP real media reason=CAMERA_MEDIA_FIXTURE_1 not set'
  say 'CAMERA ADAPTIVE LUMA HIERARCHY SMOKE: OK'
  exit 0
end
paths~append(p1)
if p2 \== '' then paths~append(p2)
if p3 \== '' then paths~append(p3)

count=0
do path over paths
  source=.CameraFFmpegMediaSource~new(path)
  activity=source~analyzeLumaGrid(16,9,15,12)
  hierarchy=activity~hierarchy(8)
  call assertEqual 'fine cell count',144,hierarchy~fineCellCount
  call assertEqual 'active fine cells retained',activity~activeCellCount,hierarchy~activeFineCellCount
  call assertTrue 'adaptive leaves no greater than fine grid',hierarchy~leafCount<=144
  call assertEqual 'leaf classes conserve leaves',hierarchy~leafCount,hierarchy~invariantLeafCount+hierarchy~activeLeafCount
  call assertTrue 'root covers complete grid',hierarchy~root~fineCellCount=144
  call assertTrue 'compact hierarchy emitted',hierarchy~compactText~pos('CLH1|G=16x9|')=1
  say '  hierarchy:' path hierarchy~compactText
  ignored=source~close
  count=count+1
end
call assertEqual 'three real fixtures analyzed',3,count

say 'CAMERA ADAPTIVE LUMA HIERARCHY SMOKE: OK'
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
