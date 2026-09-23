numeric digits 30
root=value('AUDIO_V9_VOICE_ROOT',,'ENVIRONMENT')
if root='' then root='.'
workersRoot=root||'/run/test/coordinator_workers'
outPath=root||'/run/test/coordinator_merged.tsv'
c=.AudioV9VoiceCampaign~load(root||'/campaign/CAMPAIGN.tsv',root||'/campaign/WORKERS.tsv')
header=.AudioV9SpatialCoordinator~header
startMs=c~start*1000
endMs=c~end*1000
stepMs=c~setting('analysis_step_ms')+0
expected=(endMs-startMs)/stepMs
call assert expected=16200,'expected 16200 global windows'

/* Write each worker in reverse time order to prove merge order is semantic, not file order. */
do w over c~workers
  path=workersRoot||'/'||w~worker||'/evidence/spatial.tsv'
  call stream path,'C','OPEN WRITE REPLACE'
  call lineout path,'schema'||'09'x||'audio.v9.voice-recovery.spatial-window/1'
  call lineout path,header
  do i=expected-1 to 0 by -1
    ms=startMs+i*stepMs
    sec=ms/1000
    if \w~owns(sec) then iterate
    local=(i*stepMs)//60000
    /* Synthetic values are deliberately simple; this test is ownership/phase only. */
    line=ms||'09'x||'1'||'09'x||local
    do z=1 to 13; line=line||'09'x||'0'; end
    call lineout path,line
  end
  call stream path,'C','CLOSE'
end
coordinator=.AudioV9SpatialCoordinator~new
count=coordinator~mergeWorkers(c,workersRoot,outPath)
call assert count=16200,'merged row count'

call stream outPath,'C','OPEN READ'
call assert linein(outPath)='schema'||'09'x||'audio.v9.voice-recovery.spatial-window/1','merged schema'
mergedHeader=linein(outPath)
call assert mergedHeader~right(12)='owner_worker','owner column appended'
seen=0
lastMs=.nil
lastOwner=''
do while lines(outPath)>0
  line=linein(outPath)
  if line='' then iterate
  seen=seen+1
  p=line~pos('09'x); ms=line~substr(1,p-1)+0
  owner=selfield(line,17)
  expectedMs=startMs+(seen-1)*stepMs
  call assert ms=expectedMs,'strict global phase row '||seen
  expectedOwner=''
  do w over c~workers
    if w~owns(ms/1000) then do; expectedOwner=w~worker; leave; end
  end
  call assert owner=expectedOwner,'owner matches core partition row '||seen
  lastMs=ms; lastOwner=owner
end
call stream outPath,'C','CLOSE'
call assert seen=16200,'readback row count'
call assert lastMs=endMs-stepMs,'last global phase'
call assert lastOwner='ed209i','last owner'
say 'PASS test_spatial_coordinator assertions='||(5+seen*2)
exit 0

selfield: procedure
  use strict arg line,index
  rest=line
  do i=1 to index-1
    p=rest~pos('09'x)
    if p=0 then return ''
    rest=rest~substr(p+1)
  end
  p=rest~pos('09'x)
  if p=0 then return rest
  return rest~substr(1,p-1)

assert: procedure
  use strict arg condition,label
  if \condition then do; say 'FAIL' label; exit 1; end
return
::requires 'AudioV9VoiceCampaign.cls'
::requires 'AudioV9SpatialCoordinator.cls'
