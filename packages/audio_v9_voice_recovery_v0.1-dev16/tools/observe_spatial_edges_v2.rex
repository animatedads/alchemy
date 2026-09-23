numeric digits 30
parse arg spatialPath feed outPath horizonMs windowMs
if spatialPath='' | feed='' | outPath='' then do; say 'usage: observe_spatial_edges_v2.rex SPATIAL.tsv FC|FD OUT.tsv [HORIZON_MS] [WINDOW_MS]'; exit 2; end
if horizonMs='' then horizonMs=60000; if windowMs='' then windowMs=8000; horizonMs=horizonMs+0; windowMs=windowMs+0
root=value('AUDIO_V9_VOICE_ROOT',,'ENVIRONMENT'); if root='' then root='.'; f=feed~lower
if f='fc' then do; listPath=root||'/campaign/FC_FILES.txt'; otherPath=root||'/campaign/FD_FILES.txt'; end
else if f='fd' then do; listPath=root||'/campaign/FD_FILES.txt'; otherPath=root||'/campaign/FC_FILES.txt'; end
else do; say 'FAIL feed must be FC/FD'; exit 2; end
rows=.array~new; tsv=.AudioV9TsvReader~new(spatialPath,.nil,.false)
schema=tsv~next; if schema==.nil then do; say 'FAIL spatial schema line missing'; exit 2; end
if schema~items<1 | schema[1]\='schema' then do; say 'FAIL spatial schema line missing'; exit 2; end
cols=tsv~next; if cols==.nil then do; say 'FAIL spatial header missing'; exit 2; end
ix=.directory~new; do i=1 to cols~items; ix[cols[i]]=i; end
required=.array~of('absolute_start_ms','owned','env_lag_ms','env_score','direct_lag_ms','direct_score','refined_lag_ms','refined_score'); do k over required; if \ix~hasIndex(k) then do; say 'FAIL spatial column missing 'k; exit 2; end; end

do forever
  ff=tsv~next; if ff==.nil then leave; if ff~items<cols~items then iterate; own=ff[ix['owned']]~upper; if own\='1' then if own\='TRUE' then iterate
  d=.directory~new; do k over required; d[k]=ff[ix[k]]; end; rows~append(d)
end
tsv~close
names=readNames(listPath); other=readNames(otherPath); otherEdges=.array~new; do i=2 to other~items; otherEdges~append(.AudioV9VoiceClock~fromSourceName(other[i])*1000); end
outHeader='id'||'09'x||'feed'||'09'x||'left_file'||'09'x||'right_file'||'09'x||'edge_serial'||'09'x||'kind'||'09'x||'estimator'||'09'x||'bundle_id'||'09'x||'independent_group'||'09'x||'value_samples'||'09'x||'score'||'09'x||'source_family'||'09'x||'tdoa_change_samples'||'09'x||'tdoa_known'||'09'x||'note'
call stream outPath,'C','OPEN WRITE REPLACE'; call lineout outPath,outHeader
emitted=0; skippedConfounded=0; skippedEvidence=0

do i=2 to names~items
  left=names[i-1]; right=names[i]; edge=.AudioV9VoiceClock~fromSourceName(right); edgeMs=edge*1000; confounded=.false
  do x over otherEdges; if abs(x-edgeMs)<windowMs*2 then do; confounded=.true; leave; end; end
  if confounded then do; skippedConfounded=skippedConfounded+1; iterate; end
  do estimator over .array~of('ENV','DIRECT','REFINED')
    if estimator='ENV' then do; lagKey='env_lag_ms'; scoreKey='env_score'; end
    else if estimator='DIRECT' then do; lagKey='direct_lag_ms'; scoreKey='direct_score'; end
    else do; lagKey='refined_lag_ms'; scoreKey='refined_score'; end
    beforeSum=0; beforeWeight=0; beforeCount=0; afterSum=0; afterWeight=0; afterCount=0
    do r over rows
      t=r['absolute_start_ms']+0; w=r[scoreKey]+0; if w<=0 then iterate
      if t+windowMs<=edgeMs & t>=edgeMs-horizonMs then do; ls=(r[lagKey]+0)*8; beforeSum=beforeSum+ls*w; beforeWeight=beforeWeight+w; beforeCount=beforeCount+1; end
      else if t>=edgeMs & t<edgeMs+horizonMs then do; ls=(r[lagKey]+0)*8; afterSum=afterSum+ls*w; afterWeight=afterWeight+w; afterCount=afterCount+1; end
    end
    if beforeCount<2 | afterCount<2 | beforeWeight<=0 | afterWeight<=0 then do; skippedEvidence=skippedEvidence+1; iterate; end
    before=beforeSum/beforeWeight; after=afterSum/afterWeight; jump=trunc((after-before)+0.5*sign(after-before)); ab=beforeWeight/beforeCount; aa=afterWeight/afterCount; score=ab; if aa<score then score=aa
    id='RAW_LAG|'||f||'|'||right||'|'||estimator
    e=.AudioV9FileEdgeEvidence~spatialLagJump(id,f,left,right,edge,jump,score,'UNATTRIBUTED_WINDOW|'||f||'|'||right,'UNATTRIBUTED_WINDOW','UNLABELLED',0,.false,estimator,'TDOA_CHANGE_UNKNOWN; diagnostic lag jump only')
    call lineout outPath,e~tsv; emitted=emitted+1
  end
end
call stream outPath,'C','CLOSE'; say 'PASS v2 spatial lag evidence='emitted' confounded_edges='skippedConfounded' insufficient_estimators='skippedEvidence' out='outPath
exit 0
readNames: procedure
  use arg path; a=.array~new; do while lines(path)>0; line=linein(path)~strip; if line<>'' then a~append(line); end; call stream path,'C','CLOSE'; return a
::requires 'AudioV9FileEdgeCalibration.cls'
::requires 'AudioV9Tsv.cls'
