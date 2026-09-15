say 'CAMERA SOURCE BARRIER STATE RESET SMOKE START'

/* Synthetic proof that one track crossing a boundary becomes two independent
   segment-local tracks and the structural comparison itself belongs to neither. */
sourceTracks=.CameraLumaTemporalTrackSet~new('synthetic',4,2,2.5)

/* Produce a persistent region before and after comparison 3. */
d1=.array~of(20,0,0,0,0,0,0,0)
d2=.array~of(20,0,0,0,0,0,0,0)
d3=.array~of(20,0,0,0,0,0,0,0)
d4=.array~of(20,0,0,0,0,0,0,0)
ignored=sourceTracks~observeComparison(d1,10,1)
ignored=sourceTracks~observeComparison(d2,10,2)
ignored=sourceTracks~observeComparison(d3,10,3)
ignored=sourceTracks~observeComparison(d4,10,4)

left=.CameraLumaSegmentTrackSet~new(sourceTracks,'S1',1,2)
right=.CameraLumaSegmentTrackSet~new(sourceTracks,'S2',4,4)
call assertTrue 'left gets track',left~trackCount>0
call assertTrue 'right gets track',right~trackCount>0
call assertEqual 'left fresh id','LT1',left~tracks[1]~id
call assertEqual 'right fresh id','LT1',right~tracks[1]~id
call assertEqual 'left does not include barrier comparison',2,left~tracks[1]~lastSample
call assertEqual 'right begins after barrier comparison',4,right~tracks[1]~firstSample

normal=value('CAMERA_MEDIA_FIXTURE_1',,'ENVIRONMENT')
switch1=value('CAMERA_MEDIA_SWITCH_FIXTURE_1',,'ENVIRONMENT')
switch2=value('CAMERA_MEDIA_SWITCH_FIXTURE_2',,'ENVIRONMENT')
if normal=='' then do
  say 'SKIP real media reason=CAMERA_MEDIA_FIXTURE_1 not set'
  say 'CAMERA SOURCE BARRIER STATE RESET SMOKE: OK'
  exit 0
end

source=.CameraFFmpegMediaSource~new(normal)
ordinary=source~analyzeSegmentedScene(16,9,15,12,0.5,20,15)
call assertEqual 'ordinary one generation',1,ordinary~segmentCount
call assertEqual 'ordinary no barrier',0,ordinary~boundaryCount
call assertEqual 'ordinary G1','G1',ordinary~segment(1)~generation
call assertEqual 'ordinary comparison count',59,ordinary~segment(1)~trackSet~comparisonCount
call assertEqual 'ordinary prior comparison count',59,ordinary~segment(1)~priors~comparisonCount
ignored=source~close

if switch1=='' | switch2=='' then do
  say 'SKIP source-switch fixtures reason=CAMERA_MEDIA_SWITCH_FIXTURE_1/2 not set'
  say 'CAMERA SOURCE BARRIER STATE RESET SMOKE: OK'
  exit 0
end

do path over .array~of(switch1,switch2)
  source=.CameraFFmpegMediaSource~new(path)
  segmented=source~analyzeSegmentedScene(16,9,15,12,0.5,20,15)
  call assertEqual 'mixed one barrier',1,segmented~boundaryCount
  call assertEqual 'mixed two generations',2,segmented~segmentCount

  s1=segmented~segment(1)
  s2=segmented~segment(2)
  call assertEqual 'first generation id','G1',s1~generation
  call assertEqual 'second generation id','G2',s2~generation
  call assertEqual 'first samples','1-60',s1~startSample || '-' || s1~endSample
  call assertEqual 'second samples','61-120',s2~startSample || '-' || s2~endSample
  call assertEqual 'first comparisons','1-59',s1~firstComparison || '-' || s1~lastComparison
  call assertEqual 'second comparisons','61-119',s2~firstComparison || '-' || s2~lastComparison
  call assertEqual 'barrier comparison excluded',118,s1~trackSet~comparisonCount+s2~trackSet~comparisonCount
  call assertEqual 'first priors local',59,s1~priors~comparisonCount
  call assertEqual 'second priors local',59,s2~priors~comparisonCount
  call assertEqual 'shared boundary time',s1~endTimeMs,s2~startTimeMs

  /* Peer populations are assessed per segment/generation, never across it. */
  peers=.CameraLumaBehaviourBridge~segmentedPeerOutliers(segmented,40,40,1,16,9,2,4,3,3,2)
  call assertEqual 'two isolated peer assessments',2,peers~items
  call assertEqual 'peer generation one','G1',peers[1]~generation
  call assertEqual 'peer generation two','G2',peers[2]~generation
  say '  segmented:' path segmented~compactText
  say '  peers:' peers[1]~compactText
  say '  peers:' peers[2]~compactText
  ignored=source~close
end

say 'CAMERA SOURCE BARRIER STATE RESET SMOKE: OK'
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

::requires 'CameraLumaBehaviourBridge.cls'
