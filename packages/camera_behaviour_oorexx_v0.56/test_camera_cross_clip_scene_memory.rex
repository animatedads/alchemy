say 'CAMERA CROSS CLIP SCENE MEMORY SMOKE START'

normal1=value('CAMERA_MEDIA_FIXTURE_1',,'ENVIRONMENT')
normal2=value('CAMERA_MEDIA_FIXTURE_2',,'ENVIRONMENT')
normal3=value('CAMERA_MEDIA_FIXTURE_3',,'ENVIRONMENT')
mixedPath=value('CAMERA_MEDIA_SWITCH_FIXTURE_1',,'ENVIRONMENT')

if normal1=='' | normal2=='' | normal3=='' then do
  say 'SKIP real media reason=CAMERA_MEDIA_FIXTURE_1/2/3 not set'
  say 'CAMERA CROSS CLIP SCENE MEMORY SMOKE: OK'
  exit 0
end

memory=.CameraSceneMemory~new

clipIndex=0
do path over .array~of(normal1,normal2,normal3)
  clipIndex=clipIndex+1
  source=.CameraFFmpegMediaSource~new(path)
  segmented=source~analyzeSegmentedScene(16,9,15,12,0.5,20,15)
  observed=memory~observeAnalysis('OUTDOOR3',segmented,2,4,path)

  call assertEqual 'one segment per ordinary clip',1,observed~items
  call assertEqual 'same camera stays in SG1','SG1',observed[1]~id
  call assertEqual 'same camera memory generation count',1,memory~generationCount
  if clipIndex>1 then call assertTrue 'scene fingerprint similarity admitted',memory~lastSceneSimilarity>=memory~sceneSimilarityThreshold

  ignored=source~close
end

generation=memory~currentGeneration('OUTDOOR3')
call assertEqual 'three ordinary clips accumulated',3,generation~segmentCount
call assertEqual '177 comparisons accumulated',177,generation~comparisonCount
call assertEqual 'five recurring low-quality artifact zones',5,generation~recurringArtifactCount
call assertTrue 'central activity cell seen in all clips',generation~cell(5,4)~activeSegmentShare=1
call assertTrue 'another central activity cell seen in all clips',generation~cell(11,4)~activeSegmentShare=1
call assertTrue 'known recurring too-short zone',generation~knownArtifact('TOO_SHORT',5,4)
call assertTrue 'known recurring static-fragment zone',generation~knownArtifact('STATIC_FRAGMENT',2,5)
call assertTrue 'scene fingerprint exposed',generation~lastFingerprint~compactText~pos('CSF1|')=1

recurring=generation~recurringArtifacts
call assertEqual 'recurring artifact array size',5,recurring~items
do artifact over recurring
  call assertTrue 'recurring artifact observed in at least two clips',artifact~clipCount>=2
end

if mixedPath \== '' then do
  source=.CameraFFmpegMediaSource~new(mixedPath)
  mixed=source~analyzeSegmentedScene(16,9,15,12,0.5,20,15)
  observed=memory~observeAnalysis('OUTDOOR3',mixed,2,4,mixedPath)

  call assertEqual 'mixed file yields two observed generations',2,observed~items
  call assertEqual 'first half continues learned scene','SG1',observed[1]~id
  call assertEqual 'source barrier forces fresh generation','SG2',observed[2]~id
  call assertEqual 'memory now has two generations',2,memory~generationCount
  call assertEqual 'fresh generation starts with one segment',1,observed[2]~segmentCount
  call assertEqual 'fresh generation has zero inherited recurring artifacts',0,observed[2]~recurringArtifactCount
  ignored=source~close
end

say '  memory:' memory~compactText
say 'CAMERA CROSS CLIP SCENE MEMORY SMOKE: OK'
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
