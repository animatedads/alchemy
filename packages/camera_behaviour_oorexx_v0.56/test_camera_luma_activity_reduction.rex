say 'CAMERA LUMA ACTIVITY REDUCTION SMOKE START'

paths=.array~new
p1=value('CAMERA_MEDIA_FIXTURE_1',,'ENVIRONMENT')
p2=value('CAMERA_MEDIA_FIXTURE_2',,'ENVIRONMENT')
p3=value('CAMERA_MEDIA_FIXTURE_3',,'ENVIRONMENT')
if p1 == '' then do
  say 'SKIP CAMERA LUMA ACTIVITY REDUCTION reason=CAMERA_MEDIA_FIXTURE_1 not set'
  say 'CAMERA LUMA ACTIVITY REDUCTION SMOKE: OK'
  exit 0
end
paths~append(p1)
if p2 \== '' then paths~append(p2)
if p3 \== '' then paths~append(p3)

count=0
do path over paths
  source=.CameraFFmpegMediaSource~new(path)
  activity=source~analyzeLumaGrid(16,9,15,12)
  call assertEqual 'grid columns',16,activity~gridColumns
  call assertEqual 'grid rows',9,activity~gridRows
  call assertEqual 'sampled frames',60,activity~sampledFrames
  call assertEqual 'comparisons',59,activity~comparisonCount
  call assertTrue 'some cells invariant',activity~invariantCellCount>0
  call assertTrue 'not all cells invariant',activity~activeCellCount>0
  call assertEqual 'cell conservation',144,activity~activeCellCount+activity~invariantCellCount
  call assertTrue 'compact map populated',activity~compactText~pos('CLA1|G=16x9|')=1
  say '  activity:' path activity~compactText
  ignored=source~close
  count=count+1
end
call assertEqual 'three fixtures analyzed',3,count

/* Deterministic synthetic activity map verifies exact activation semantics. */
m=.CameraLumaActivityMap~new('synthetic',2,2,1,10)
a=.array~of(10,20,30,40)
b=.array~of(10,60,30,40)
ignored=m~observeFrameSamples(.nil,a)
ignored=m~observeFrameSamples(a,b)
call assertEqual 'synthetic samples',2,m~sampledFrames
call assertEqual 'synthetic comparisons',1,m~comparisonCount
call assertEqual 'synthetic active cells',4,m~activeCellCount
call assertEqual 'synthetic invariant cells',0,m~invariantCellCount
call assertTrue 'cell 2 active',m~cell(2,1)~active
call assertTrue 'cell 4 active',m~cell(2,2)~active
call assertTrue 'cell 1 responds to relative normalization',m~cell(1,1)~active

say 'CAMERA LUMA ACTIVITY REDUCTION SMOKE: OK'
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
