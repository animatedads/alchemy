say 'CAMERA SOURCE BOUNDARY AND SCENE PROFILE SMOKE START'

normal=value('CAMERA_MEDIA_FIXTURE_1',,'ENVIRONMENT')
switch1=value('CAMERA_MEDIA_SWITCH_FIXTURE_1',,'ENVIRONMENT')
switch2=value('CAMERA_MEDIA_SWITCH_FIXTURE_2',,'ENVIRONMENT')

if normal == '' then do
  say 'SKIP media reason=CAMERA_MEDIA_FIXTURE_1 not set'
  say 'CAMERA SOURCE BOUNDARY AND SCENE PROFILE SMOKE: OK'
  exit 0
end

/* Ordinary one-camera minute should not manufacture a source transition. */
source=.CameraFFmpegMediaSource~new(normal)
ordinary=source~analyzeSourceBoundaries(16,9,15,12,0.5,20,15)
call assertEqual 'ordinary sampled frames',60,ordinary~sampledFrames
call assertEqual 'ordinary source candidates',0,ordinary~candidateCount
call assertEqual 'ordinary source segments',1,ordinary~sourceSegmentCount
ignored=source~close

/* Scene priors and direction profile are compact summaries of the same
   anonymous activity evidence. */
source=.CameraFFmpegMediaSource~new(normal)
activity=source~analyzeLumaGrid(16,9,15,12)
priors=activity~scenePriors
direction=activity~directionProfile
call assertEqual 'prior active count',activity~activeCellCount,priors~activeCellCount
call assertEqual 'prior comparison count',activity~comparisonCount,priors~comparisonCount
call assertTrue 'prior compact prefix',priors~compactText~pos('CLP1|A=')=1
stepSum=direction~upCount+direction~downCount+direction~leftCount+direction~rightCount+direction~upLeftCount+direction~upRightCount+direction~downLeftCount+direction~downRightCount+direction~stationaryCount
call assertEqual 'direction conservation',direction~stepCount,stepSum
call assertTrue 'direction compact prefix',direction~compactText~pos('CLD1|N=')=1
say '  priors:' priors~compactText
say '  direction:' direction~compactText
ignored=source~close

if switch1 == '' | switch2 == '' then do
  say 'SKIP source-switch fixtures reason=CAMERA_MEDIA_SWITCH_FIXTURE_1/2 not set'
  say 'CAMERA SOURCE BOUNDARY AND SCENE PROFILE SMOKE: OK'
  exit 0
end

do path over .array~of(switch1,switch2)
  source=.CameraFFmpegMediaSource~new(path)
  mixed=source~analyzeSourceBoundaries(16,9,15,12,0.5,20,15)
  call assertEqual 'mixed sampled frames',120,mixed~sampledFrames
  call assertEqual 'one dominant source boundary',1,mixed~candidateCount
  call assertEqual 'two source segments',2,mixed~sourceSegmentCount
  boundary=mixed~dominantBoundary
  call assertTrue 'boundary exists',boundary \== .nil
  call assertEqual 'boundary classification','SOURCE_CHANGE',boundary~boundaryType
  call assertTrue 'boundary comes from media PTS',boundary~pts>0
  call assertTrue 'boundary near middle but not hard-coded',boundary~timeMs>=55000 & boundary~timeMs<=65000
  call assertTrue 'widespread local replacement',boundary~changedShare>=0.5
  call assertTrue 'structural replacement',boundary~structureDelta>=20
  call assertTrue 'pre-cut scene locally stable',boundary~preMeanDelta<=15
  call assertTrue 'post-cut scene locally stable',boundary~postMeanDelta<=15
  say '  boundary:' path boundary~compactText
  ignored=source~close
end

say 'CAMERA SOURCE BOUNDARY AND SCENE PROFILE SMOKE: OK'
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
