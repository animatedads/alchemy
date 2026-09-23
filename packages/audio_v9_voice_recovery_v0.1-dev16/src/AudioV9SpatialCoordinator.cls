/* AudioV9SpatialCoordinator.cls
 * Deterministic merge of immutable per-worker spatial evidence.
 * Only core-owned globally phased windows enter the campaign result.
 */

::options numeric inherit

::class AudioV9SpatialCoordinator public
::constant SCHEMA 'audio.v9.voice-recovery.spatial-window/1'

::method header class
  return 'absolute_start_ms'||'09'x||'owned'||'09'x||'local_start_ms'||'09'x||'rms_a'||'09'x||'rms_b'||'09'x||'crest_a'||'09'x||'crest_b'||'09'x||'ratio_db'||'09'x||'env_lag_ms'||'09'x||'env_score'||'09'x||'direct_lag_ms'||'09'x||'direct_score'||'09'x||'direct_coherence'||'09'x||'refined_lag_ms'||'09'x||'refined_score'||'09'x||'refined_coherence'

::method mergeWorkers
  use strict arg campaign,workersRoot,outPath
  rows=.directory~new
  owners=.directory~new
  ownedCount=0
  do worker over campaign~workers
    path=workersRoot||'/'||worker~worker||'/evidence/spatial.tsv'
    if stream(path,'C','QUERY EXISTS')='' then raise syntax 88.900 array('worker spatial evidence missing',worker~worker,path)
    call stream path,'C','OPEN READ'
    schemaLine=linein(path)
    headerLine=linein(path)
    if schemaLine\=('schema'||'09'x||self~SCHEMA) then do
      call stream path,'C','CLOSE'
      raise syntax 88.900 array('worker spatial schema mismatch',worker~worker,schemaLine)
    end
    if headerLine\=.AudioV9SpatialCoordinator~header then do
      call stream path,'C','CLOSE'
      raise syntax 88.900 array('worker spatial header mismatch',worker~worker,headerLine)
    end
    do while lines(path)>0
      line=linein(path)
      if line='' then iterate
      p1=line~pos('09'x)
      if p1=0 then do; call stream path,'C','CLOSE'; raise syntax 88.900 array('malformed spatial row',worker~worker,line); end
      rest=line~substr(p1+1)
      p2=rest~pos('09'x)
      if p2=0 then do; call stream path,'C','CLOSE'; raise syntax 88.900 array('malformed spatial ownership row',worker~worker,line); end
      key=line~substr(1,p1-1)
      owned=rest~substr(1,p2-1)
      if \datatype(key,'W') then do; call stream path,'C','CLOSE'; raise syntax 88.900 array('non-integer spatial start',worker~worker,key); end
      if owned\='0' & owned\='1' then do; call stream path,'C','CLOSE'; raise syntax 88.900 array('invalid spatial ownership flag',worker~worker,owned); end
      if owned='0' then iterate
      if rows~hasIndex(key) then do
        prior=owners[key]
        call stream path,'C','CLOSE'
        raise syntax 88.900 array('duplicate owned spatial window',key,prior,worker~worker)
      end
      rows[key]=line
      owners[key]=worker~worker
      ownedCount=ownedCount+1
    end
    call stream path,'C','CLOSE'
  end

  stepMs=(campaign~setting('analysis_step_ms')+0)
  if stepMs<=0 | stepMs\=trunc(stepMs) then raise syntax 88.900 array('invalid campaign spatial step',stepMs)
  startMs=campaign~start*1000
  endMs=campaign~end*1000
  expectedCount=(endMs-startMs)/stepMs
  if expectedCount\=trunc(expectedCount) then raise syntax 88.900 array('campaign duration not divisible by analysis step',startMs,endMs,stepMs)
  if ownedCount\=expectedCount then raise syntax 88.900 array('owned spatial row count mismatch',ownedCount,expectedCount)

  call stream outPath,'C','OPEN WRITE REPLACE'
  call lineout outPath,'schema'||'09'x||self~SCHEMA
  call lineout outPath,.AudioV9SpatialCoordinator~header||'09'x||'owner_worker'
  do i=0 to expectedCount-1
    key=(startMs+i*stepMs)~string
    if \rows~hasIndex(key) then do
      call stream outPath,'C','CLOSE'
      raise syntax 88.900 array('missing globally phased spatial window',key,i)
    end
    call lineout outPath,rows[key]||'09'x||owners[key]
  end
  call stream outPath,'C','CLOSE'
  return expectedCount
