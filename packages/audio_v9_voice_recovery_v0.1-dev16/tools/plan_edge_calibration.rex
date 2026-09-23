numeric digits 30
parse arg outPath horizonSeconds
if outPath='' then do; say 'usage: plan_edge_calibration.rex OUT.tsv [HORIZON_SECONDS]'; exit 2; end
if horizonSeconds='' then horizonSeconds=60; horizonSeconds=horizonSeconds+0
if horizonSeconds<8 then do; say 'FAIL calibration horizon must be >=8 seconds'; exit 2; end
root=value('AUDIO_V9_VOICE_ROOT',,'ENVIRONMENT'); if root='' then root='.'
campaign=root||'/campaign/CAMPAIGN.tsv'; startText=''; endText=''
tsv=.AudioV9TsvReader~new(campaign,.nil,.false)
do forever
  row=tsv~next; if row==.nil then leave
  if row~items<2 then iterate
  k=row[1]; v=row[2]
  if k='start' then startText=v
  if k='end' then endText=v
end
tsv~close
if startText='' | endText='' then do; say 'FAIL campaign start/end missing'; exit 2; end
start=.AudioV9VoiceClock~parse(startText); finish=.AudioV9VoiceClock~parse(endText)
fc=readNames(root||'/campaign/FC_FILES.txt'); fd=readNames(root||'/campaign/FD_FILES.txt')
fcEdges=edgeTimes(fc); fdEdges=edgeTimes(fd)
call stream outPath,'C','OPEN WRITE REPLACE'; call lineout outPath,'feed'||'09'x||'left_file'||'09'x||'right_file'||'09'x||'edge_serial'||'09'x||'window_start_serial'||'09'x||'window_end_serial'||'09'x||'other_feed_edge_nearby'||'09'x||'purpose'
count=0
count=count+emitFeed('fc',fc,fdEdges,start,finish,horizonSeconds,outPath)
count=count+emitFeed('fd',fd,fcEdges,start,finish,horizonSeconds,outPath)
call stream outPath,'C','CLOSE'
say 'PASS edge calibration plan edges='count' horizon='horizonSeconds' out='outPath
exit 0

emitFeed: procedure
  use arg feed,names,otherEdges,start,finish,horizon,outPath
  count=0
  do i=2 to names~items
    edge=.AudioV9VoiceClock~fromSourceName(names[i]); if edge<start then iterate; if edge>=finish then iterate
    near=0; do x over otherEdges; if abs(x-edge)<16 then do; near=1; leave; end; end
    ws=edge-horizon; if ws<start then ws=start; we=edge+horizon; if we>finish then we=finish
    call lineout outPath,feed||'09'x||names[i-1]||'09'x||names[i]||'09'x||edge||'09'x||ws||'09'x||we||'09'x||near||'09'x||'SOURCE_CONDITIONED_SEAM_AND_TDOA'
    count=count+1
  end
  return count
readNames: procedure
  use arg path; a=.array~new; do while lines(path)>0; n=linein(path)~strip; if n<>'' then a~append(n); end; call stream path,'C','CLOSE'; return a
edgeTimes: procedure
  use arg names; a=.array~new; do i=2 to names~items; a~append(.AudioV9VoiceClock~fromSourceName(names[i])); end; return a
::requires 'AudioV9VoiceCampaign.cls'
::requires 'AudioV9Tsv.cls'
