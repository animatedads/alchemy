numeric digits 30
parse arg edgePlan outPath workersPath
if outPath='' then do
  say 'usage: plan_source_conditioned_jobs.rex EDGE_PLAN.tsv OUT.tsv [WORKERS.tsv]'
  exit 2
end
root=value('AUDIO_V9_VOICE_ROOT',,'ENVIRONMENT'); if root='' then root='.'
if workersPath='' then workersPath=root||'/campaign/WORKERS.tsv'
workers=.array~new
workerHeader=.array~of('worker','core_start','core_end','halo_seconds','provider','address','login')
wtsv=.AudioV9TsvReader~new(workersPath,workerHeader)
do forever
  f=wtsv~next; if f==.nil then leave
  if f~items<>workerHeader~items then do; say 'FAIL bad worker row'; exit 2; end
  d=.directory~new; d['worker']=f[1]; d['start']=.AudioV9VoiceClock~parse(f[2]); d['end']=.AudioV9VoiceClock~parse(f[3]); workers~append(d)
end
wtsv~close
edgeHeader=.array~of('feed','left_file','right_file','edge_serial','window_start_serial','window_end_serial','other_feed_edge_nearby','purpose')
etsv=.AudioV9TsvReader~new(edgePlan,edgeHeader)
expected=joinTabs(edgeHeader)
call stream outPath,'C','OPEN WRITE REPLACE'; call lineout outPath,'worker'||'09'x||'edge_index'||'09'x||expected
count=0; per=.directory~new
do forever
  f=etsv~next; if f==.nil then leave; if f~items<>edgeHeader~items then do; say 'FAIL bad edge plan row'; exit 2; end
  edge=f[4]+0; owner=''
  do w over workers
    if edge>=w['start'] then if edge<w['end'] then do; owner=w['worker']; leave; end
  end
  if owner='' then do; say 'FAIL no worker owns edge='||edge||' right='||f[3]; exit 2; end
  count=count+1; if \per~hasIndex(owner) then per[owner]=0; per[owner]=per[owner]+1
  call lineout outPath,owner||'09'x||count||'09'x||joinTabs(f)
end
etsv~close; call stream outPath,'C','CLOSE'
summary=''; do w over workers; id=w['worker']; n=0; if per~hasIndex(id) then n=per[id]; if summary<>'' then summary=summary||','; summary=summary||id||'='||n; end
say 'PASS source-conditioned job plan edges='||count||' workers='||summary||' out='||outPath
exit 0
joinTabs: procedure
  use arg row
  out=''
  do i=1 to row~items
    if i>1 then out=out||'09'x
    out=out||row[i]
  end
  return out
::requires 'AudioV9VoiceCampaign.cls'
::requires 'AudioV9Tsv.cls'
