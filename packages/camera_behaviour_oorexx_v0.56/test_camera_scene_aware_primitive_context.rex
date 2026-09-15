say 'CAMERA SCENE AWARE PRIMITIVE CONTEXT SMOKE START'

p1=value('CAMERA_MEDIA_FIXTURE_1',,'ENVIRONMENT')
p2=value('CAMERA_MEDIA_FIXTURE_2',,'ENVIRONMENT')
p3=value('CAMERA_MEDIA_FIXTURE_3',,'ENVIRONMENT')
mixedPath=value('CAMERA_MEDIA_SWITCH_FIXTURE_1',,'ENVIRONMENT')

if p1=='' | p2=='' | p3=='' then do
  say 'SKIP real media reason=CAMERA_MEDIA_FIXTURE_1/2/3 not set'
  say 'CAMERA SCENE AWARE PRIMITIVE CONTEXT SMOKE: OK'
  exit 0
end

memory=.CameraSceneMemory~new

/* Learn scene context from two distinct earlier clips only. */
do path over .array~of(p1,p2)
  source=.CameraFFmpegMediaSource~new(path)
  segmented=source~analyzeSegmentedScene(16,9,15,12,0.5,20,15)
  ignored=memory~observeAnalysis('OUTDOOR3',segmented,2,4,path)
  ignored=source~close
end

generation=memory~currentGeneration('OUTDOOR3')
call assertEqual 'single learned scene generation',1,memory~generationCount
call assertEqual 'two learned segments',2,generation~segmentCount
call assertEqual 'three recurring nuisance zones after two clips',3,generation~recurringArtifactCount
call assertTrue '5,4 is known nuisance zone',generation~knownArtifactZone(5,4)
call assertTrue '11,5 is known nuisance zone',generation~knownArtifactZone(11,5)
call assertTrue '6,4 remains historically unseen nuisance zone',\generation~knownArtifactZone(6,4)

/* Assess the third clip BEFORE adding it to memory: no self-explanation. */
source=.CameraFFmpegMediaSource~new(p3)
segmented=source~analyzeSegmentedScene(16,9,15,12,0.5,20,15)
segment=segmented~segment(1)
aware=memory~assessSegment('OUTDOOR3',segment,2,4)

call assertEqual 'third clip four primitive observations',4,aware~totalCount
call assertEqual 'two expected scene fragments',2,aware~expectedSceneCount
call assertEqual 'two novel low-quality fragments',2,aware~novelFragmentCount
call assertEqual 'no admitted motion in quiet clip',0,aware~admittedMotionCount
call assertEqual 'no missing context',0,aware~noContextCount
call assertEqual 'observation conservation',4,aware~expectedSceneCount+aware~novelFragmentCount+aware~admittedMotionCount+aware~noContextCount

lt1=aware~assessment('LT1')
lt2=aware~assessment('LT2')
lt3=aware~assessment('LT3')
lt4=aware~assessment('LT4')

call assertEqual 'LT1 novel','NOVEL_LOW_QUALITY_FRAGMENT',lt1~contextState
call assertEqual 'LT1 zone','6,4',lt1~column || ',' || lt1~row
call assertEqual 'LT2 novel','NOVEL_LOW_QUALITY_FRAGMENT',lt2~contextState
call assertEqual 'LT2 zone','7,4',lt2~column || ',' || lt2~row

call assertEqual 'LT3 expected','EXPECTED_SCENE_ACTIVITY',lt3~contextState
call assertEqual 'LT3 zone','11,5',lt3~column || ',' || lt3~row
call assertEqual 'LT3 current base quality remains static','STATIC_FRAGMENT',lt3~baseQuality~reason
call assertEqual 'LT3 explained by zone not exact reason',0,lt3~exactRecurringArtifact
call assertEqual 'LT3 has recurring-zone reason','RECURRING_ZONE',lt3~contextReason
call assertEqual 'LT3 historical reason','TOO_SHORT',lt3~recurringReasons[1]

call assertEqual 'LT4 expected','EXPECTED_SCENE_ACTIVITY',lt4~contextState
call assertEqual 'LT4 zone','5,4',lt4~column || ',' || lt4~row
call assertEqual 'LT4 current base quality remains static','STATIC_FRAGMENT',lt4~baseQuality~reason
call assertEqual 'LT4 explained by zone not exact reason',0,lt4~exactRecurringArtifact
call assertEqual 'LT4 historical reason','TOO_SHORT',lt4~recurringReasons[1]

call assertEqual 'expected filtered view',2,aware~expectedSceneAssessments~items
call assertEqual 'novel filtered view',2,aware~novelFragmentAssessments~items

say '  scene-aware:' aware~compactText
ignored=source~close

/* A CSB1 barrier starts a fresh generation with no inherited nuisance context. */
if mixedPath \== '' then do
  source=.CameraFFmpegMediaSource~new(mixedPath)
  mixed=source~analyzeSegmentedScene(16,9,15,12,0.5,20,15)

  q1=.CameraLumaBehaviourBridge~quality(mixed~segment(1)~trackSet,16,9,2,4)
  beforeBarrier=memory~observeSegment('OUTDOOR3',mixed~segment(1),q1,mixedPath || ':S1',.false)

  q2=.CameraLumaBehaviourBridge~quality(mixed~segment(2)~trackSet,16,9,2,4)
  fresh=memory~observeSegment('OUTDOOR3',mixed~segment(2),q2,mixedPath || ':S2',.true)

  call assertTrue 'barrier creates a different generation',fresh~id \== beforeBarrier~id
  call assertEqual 'fresh generation has no recurring nuisance artifacts',0,fresh~recurringArtifactCount
  call assertTrue 'fresh generation does not inherit 5,4 nuisance zone',\fresh~knownArtifactZone(5,4)
  call assertTrue 'fresh generation does not inherit 11,5 nuisance zone',\fresh~knownArtifactZone(11,5)
  ignored=source~close
end

say 'CAMERA SCENE AWARE PRIMITIVE CONTEXT SMOKE: OK'
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

::requires 'CameraSceneMemory.cls'
