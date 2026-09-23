numeric digits 30
parse arg inPath outPath maxRms
if inPath='' | outPath='' then do
  say 'usage: observe_source_conditioned_edges.rex SOURCE_PATH_POINTS.tsv OUT_EVIDENCE.tsv [MAX_RMS_SAMPLES]'
  exit 2
end
if maxRms='' then maxRms=8
header=.array~of('id','feed','left_file','right_file','edge_serial','source_family','path_id','time_ms','side','lag_samples','score')
r=.AudioV9TsvReader~new(inPath,header)
groups=.directory~new

do forever
  f=r~next; if f==.nil then leave
  if f~items=1 & f[1]='' then iterate
  if f~items<>11 then do; say 'FAIL source path row width='f~items; exit 2; end
  side=f[9]~upper; if side\='BEFORE' then if side\='AFTER' then do; say 'FAIL side must be BEFORE/AFTER'; exit 2; end
  key=f[2]||'|'||f[4]||'|'||f[6]||'|'||f[7]
  if \groups~hasIndex(key) then do
    g=.directory~new; g['id']=f[1]; g['feed']=f[2]; g['left']=f[3]; g['right']=f[4]; g['edge']=f[5]+0; g['family']=f[6]; g['path']=f[7]; g['before']=.array~new; g['after']=.array~new; g['score']=0; g['rows']=0; groups[key]=g
  end
  g=groups[key]
  if g['left']\=f[3] | g['edge']\=f[5]+0 then do; say 'FAIL source path group mixes edge identity key='key; exit 2; end
  p=.directory~new; p['time_ms']=f[8]+0; p['lag_samples']=f[10]+0; p['score']=f[11]+0
  if side='BEFORE' then g['before']~append(p); else g['after']~append(p)
  g['score']=g['score']+(f[11]+0); g['rows']=g['rows']+1
end
r~close

outHeader='id'||'09'x||'feed'||'09'x||'left_file'||'09'x||'right_file'||'09'x||'edge_serial'||'09'x||'kind'||'09'x||'estimator'||'09'x||'bundle_id'||'09'x||'independent_group'||'09'x||'value_samples'||'09'x||'score'||'09'x||'source_family'||'09'x||'tdoa_change_samples'||'09'x||'tdoa_known'||'09'x||'note'
call stream outPath,'C','OPEN WRITE REPLACE'; call lineout outPath,outHeader
keys=.array~new; do k over groups~allIndexes; keys~append(k); end; keys~sort
fitter=.AudioV9EdgePathContinuityFitter~new(3,maxRms+0); emitted=0; rejected=0; insufficient=0
do k over keys
  g=groups[k]
  if g['path']~upper='ENVELOPE' then do; rejected=rejected+1; iterate; end
  if g['before']~items<3 | g['after']~items<3 then do; insufficient=insufficient+1; rejected=rejected+1; iterate; end
  avg=1; if g['rows']>0 then avg=g['score']/g['rows']
  e=fitter~fit('PATHFIT|'||g['feed']||'|'||g['right']||'|'||g['family']||'|'||g['path'],g['feed'],g['left'],g['right'],g['edge'],g['family'],g['path'],g['before'],g['after'],avg)
  if e==.nil then do; rejected=rejected+1; iterate; end
  call lineout outPath,e~tsv; emitted=emitted+1
end
call stream outPath,'C','CLOSE'
say 'PASS source-conditioned edge evidence='emitted' rejected_path_fits='rejected' insufficient_trajectory='insufficient' out='outPath
exit 0
::requires 'AudioV9Tsv.cls'
::requires 'AudioV9FileEdgeCalibration.cls'
