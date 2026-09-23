numeric digits 30
parse arg reportListPath outPath
if reportListPath='' | outPath='' then do; say 'usage: observe_decode_edges_v2.rex REPORT_PATHS.txt OUT.tsv'; exit 2; end
root=value('AUDIO_V9_VOICE_ROOT',,'ENVIRONMENT'); if root='' then root='.'
next=.directory~new; edge=.directory~new
call loadFeed 'fc',root||'/campaign/FC_FILES.txt',next,edge
call loadFeed 'fd',root||'/campaign/FD_FILES.txt',next,edge
found=.directory~new

do while lines(reportListPath)>0
  path=linein(reportListPath)~strip; if path='' then iterate; if stream(path,'C','QUERY EXISTS')='' then iterate
  tsv=.AudioV9TsvReader~new(path); cols=tsv~header; ix=.directory~new; do i=1 to cols~items; ix[cols[i]]=i; end
  required=.array~of('feed','file','action','original_bytes','final_bytes','expected_samples'); usable=.true
  do k over required; if \ix~hasIndex(k) then usable=.false; end
  endCol=''; if ix~hasIndex('slice_end_sample') then endCol='slice_end_sample'; else if ix~hasIndex('slice_end') then endCol='slice_end'; else usable=.false
  if \usable then do; tsv~close; iterate; end
  do forever
    f=tsv~next; if f==.nil then leave; if f~items<cols~items then iterate
    feed=f[ix['feed']]~lower; left=f[ix['file']]; key=feed||'|'||left; if \next~hasIndex(key) then iterate
    right=next[key]; e=edge[key]; observedEnd=f[ix[endCol]]+0; expectedEnd=e; if endCol='slice_end_sample' then expectedEnd=e*8000; if observedEnd\=expectedEnd then iterate
    original=f[ix['original_bytes']]+0; final=f[ix['final_bytes']]+0; delta=original-final
    if delta//4\=0 then iterate
    residual=delta/4; action=f[ix['action']]~upper
    ukey=feed||'|'||right||'|'||residual
    id='MEDIA_EXTENT|'||feed||'|'||right||'|'||residual
    found[ukey]=.AudioV9FileEdgeEvidence~new(id,feed,left,right,e,'MEDIA_EXTENT','DECODE_NORMALIZATION','MEDIA|'||feed||'|'||right,'MEDIA_EXTENT',residual,1,'CONTAINER_GEOMETRY',0,.false,'action='||action||'; original_bytes='||original||'; normalized_bytes='||final)
  end
  tsv~close
end
call stream reportListPath,'C','CLOSE'

headerOut='id'||'09'x||'feed'||'09'x||'left_file'||'09'x||'right_file'||'09'x||'edge_serial'||'09'x||'kind'||'09'x||'estimator'||'09'x||'bundle_id'||'09'x||'independent_group'||'09'x||'value_samples'||'09'x||'score'||'09'x||'source_family'||'09'x||'tdoa_change_samples'||'09'x||'tdoa_known'||'09'x||'note'
call stream outPath,'C','OPEN WRITE REPLACE'; call lineout outPath,headerOut
keys=.array~new; do k over found~allIndexes; keys~append(k); end; keys~sort
do k over keys; call lineout outPath,found[k]~tsv; end
call stream outPath,'C','CLOSE'
say 'PASS v2 decode edge observations='keys~items' out='outPath
exit 0
loadFeed: procedure
  use arg feed,path,next,edge; names=.array~new; do while lines(path)>0; line=linein(path)~strip; if line<>'' then names~append(line); end; call stream path,'C','CLOSE'
  do i=1 to names~items-1; key=feed||'|'||names[i]; next[key]=names[i+1]; edge[key]=.AudioV9VoiceClock~fromSourceName(names[i+1]); end; return
::requires 'AudioV9FileEdgeCalibration.cls'
::requires 'AudioV9Tsv.cls'
