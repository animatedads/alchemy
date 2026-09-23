numeric digits 30
parse arg commandLine
if words(commandLine)<2 then do
  say 'usage: solve_file_edges_v2.rex OUT.tsv EVIDENCE.tsv [EVIDENCE2.tsv ...]'
  exit 2
end
outPath=word(commandLine,1); root=value('AUDIO_V9_VOICE_ROOT',,'ENVIRONMENT'); if root='' then root='.'
header=.array~of('id','feed','left_file','right_file','edge_serial','kind','estimator','bundle_id','independent_group','value_samples','score','source_family','tdoa_change_samples','tdoa_known','note')
groups=.directory~new; seen=.directory~new

do ai=2 to words(commandLine)
  path=word(commandLine,ai); r=.AudioV9TsvReader~new(path,header)
  do forever
    f=r~next; if f==.nil then leave
    if f~items=1 & f[1]='' then iterate
    if f~items<>15 then do; say 'FAIL v2 edge evidence row width='f~items; exit 2; end
    canonical=''
    do ci=1 to f~items; if ci>1 then canonical=canonical||'09'x; canonical=canonical||f[ci]; end
    if seen~hasIndex(f[1]) then do; if seen[f[1]]\=canonical then do; say 'FAIL duplicate v2 evidence differs id='f[1]; exit 2; end; iterate; end; seen[f[1]]=canonical
    known=.false; if f[14]='1' | f[14]~upper='TRUE' then known=.true
    e=.AudioV9FileEdgeEvidence~new(f[1],f[2],f[3],f[4],f[5],f[6],f[7],f[8],f[9],f[10],f[11],f[12],f[13],known,f[15])
    key=e~feed||'|'||e~rightFile; if \groups~hasIndex(key) then groups[key]=.array~new; groups[key]~append(e)
  end
  r~close
end

outHeader='feed'||'09'x||'left_file'||'09'x||'right_file'||'09'x||'edge_serial'||'09'x||'media_extent_residual_samples'||'09'x||'media_extent_status'||'09'x||'clock_step_samples'||'09'x||'cumulative_correction_samples'||'09'x||'seam_gap_samples'||'09'x||'seam_gap_status'||'09'x||'status'||'09'x||'candidate_count'||'09'x||'independent_support'||'09'x||'spread_samples'||'09'x||'seam_support'||'09'x||'spatial_support'||'09'x||'direct_support'||'09'x||'reason'
call stream outPath,'C','OPEN WRITE REPLACE'; call lineout outPath,outHeader
solver=.AudioV9FileEdgeCalibrationSolver~new(4,8,2); total=0; measured=0; candidate=0; ambiguous=0; extentOnly=0; unresolved=0

do feed over .array~of('fc','fd')
  listPath=root||'/campaign/'||feed~upper||'_FILES.txt'; names=.array~new
  do while lines(listPath)>0; n=linein(listPath)~strip; if n<>'' then names~append(n); end; call stream listPath,'C','CLOSE'
  previous=0
  do i=2 to names~items
    left=names[i-1]; right=names[i]; edge=.AudioV9VoiceClock~fromSourceName(right); key=feed||'|'||right
    if groups~hasIndex(key) then obs=groups[key]; else obs=.array~new
    if obs~items>0 then sol=solver~solve(obs,previous)
    else sol=.AudioV9FileEdgeCalibrationSolution~new(feed,left,right,edge,0,'UNKNOWN',0,previous,0,'UNKNOWN','UNRESOLVED',0,0,0,0,0,0,'no evidence')
    if sol~resolved then previous=sol~cumulativeCorrectionSamples
    call lineout outPath,sol~tsv; total=total+1
    select
      when sol~status='CLOCK_MEASURED' then measured=measured+1
      when sol~status='CLOCK_CANDIDATE' then candidate=candidate+1
      when sol~status='CLOCK_AMBIGUOUS' then ambiguous=ambiguous+1
      when sol~status='EXTENT_ONLY' then extentOnly=extentOnly+1
      otherwise unresolved=unresolved+1
    end
  end
end
call stream outPath,'C','CLOSE'
say 'PASS file-edge calibration v2 edges='total' measured='measured' candidate='candidate' ambiguous='ambiguous' extent_only='extentOnly' unresolved='unresolved' out='outPath
exit 0
::requires 'AudioV9Tsv.cls'
::requires 'AudioV9FileEdgeCalibration.cls'
