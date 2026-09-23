numeric digits 30
parse arg commandLine
if words(commandLine)<2 then do
  say 'usage: migrate_edge_observations_v2.rex OUT.tsv LEGACY_OBS.tsv [LEGACY_OBS2.tsv ...]'
  exit 2
end
outPath=word(commandLine,1)
legacyHeader=.array~of('id','feed','left_file','right_file','edge_serial','estimator','step_samples','score','source_family','tdoa_before_samples','tdoa_after_samples')
newHeader='id'||'09'x||'feed'||'09'x||'left_file'||'09'x||'right_file'||'09'x||'edge_serial'||'09'x||'kind'||'09'x||'estimator'||'09'x||'bundle_id'||'09'x||'independent_group'||'09'x||'value_samples'||'09'x||'score'||'09'x||'source_family'||'09'x||'tdoa_change_samples'||'09'x||'tdoa_known'||'09'x||'note'
seen=.directory~new; out=.array~new

do ai=2 to words(commandLine)
  path=word(commandLine,ai); tsv=.AudioV9TsvReader~new(path,legacyHeader)
  do forever
    f=tsv~next; if f==.nil then leave
    if f~items<>11 then do; say 'FAIL legacy observation row width='f~items' path='path; exit 2; end
    id=f[1]; signature=rowSignature(f); if seen~hasIndex(id) then do; if seen[id]\=signature then do; say 'FAIL duplicate legacy observation differs id='id; exit 2; end; iterate; end; seen[id]=signature
    feed=f[2]~lower; estimator=f[6]~upper; oldStep=f[7]+0
    if estimator~pos('DECODE')=1 | estimator='DECODED_LENGTH' then do
      e=.AudioV9FileEdgeEvidence~new(id,feed,f[3],f[4],f[5],'MEDIA_EXTENT',estimator,'LEGACY_MEDIA|'||feed||'|'||f[4],'MEDIA_EXTENT',oldStep,f[8],f[9],0,.false,'MIGRATED_FROM_DEV4; extent residual only; not clock authority')
    end
    else do
      /* dev4 step = +lagJump for FC and -lagJump for FD because T was forced to zero. */
      lagJump=oldStep; if feed='fd' then lagJump=-oldStep
      e=.AudioV9FileEdgeEvidence~new(id,feed,f[3],f[4],f[5],'SPATIAL_LAG_JUMP',estimator,'LEGACY_SPATIAL|'||feed||'|'||f[4],'LEGACY_SPATIAL_WINDOW',lagJump,f[8],f[9],0,.false,'MIGRATED_FROM_DEV4; TDOA_CHANGE_UNKNOWN; cannot measure clock')
    end
    out~append(e)
  end
  tsv~close
end
call stream outPath,'C','OPEN WRITE REPLACE'; call lineout outPath,newHeader
out~sortWith(.EdgeEvidenceComparator~new)
do e over out; call lineout outPath,e~tsv; end
call stream outPath,'C','CLOSE'
say 'PASS migrated edge observations='out~items' out='outPath
exit 0
rowSignature: procedure
  use arg row
  out=''
  do i=1 to row~items; v=row[i]~string; out=out||length(v)||':'||v||';'; end
  return out

::class EdgeEvidenceComparator private
::method compare
  use strict arg a,b
  if a~feed<b~feed then return -1
  if a~feed>b~feed then return 1
  if a~edgeSerial<b~edgeSerial then return -1
  if a~edgeSerial>b~edgeSerial then return 1
  if a~id<b~id then return -1
  if a~id>b~id then return 1
  return 0
::requires 'AudioV9FileEdgeCalibration.cls'
::requires 'AudioV9Tsv.cls'
