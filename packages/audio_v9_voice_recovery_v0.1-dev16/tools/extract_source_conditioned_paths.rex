numeric digits 30
parse arg fcPath fdPath groupsPath feed leftFile rightFile edgeSerial windowStartSerial outPath tempDir
if outPath='' then do
  say 'usage: extract_source_conditioned_paths.rex FC.f32 FD.f32 groups.tsv FC|FD LEFT RIGHT EDGE_SERIAL WINDOW_START_SERIAL OUT.tsv [TMPDIR]'
  exit 2
end
if tempDir='' then tempDir=filespec('D',outPath)||filespec('P',outPath)||'source_conditioned_tmp'
address system 'mkdir -p '||quote(tempDir)
if rc<>0 then do; say 'FAIL cannot create temp dir'; exit 2; end
root=value('AUDIO_V9_VOICE_ROOT',,'ENVIRONMENT'); if root='' then root='.'
p=.AudioV9SpatialNativeProvider~new(root||'/run/native/av9_spatial.bridge.json')
f=feed~lower; if f\='fc' then if f\='fd' then do; say 'FAIL feed must be FC/FD'; exit 2; end
edge=edgeSerial+0; edgeMs=edge*1000; baseMs=(windowStartSerial+0)*1000
header=.array~of('group_id','kind','families','fc_before','fc_after','fd_before','fd_after','score','fc_mask','fd_mask')
r=.AudioV9TsvReader~new(groupsPath,header)
call stream outPath,'C','OPEN WRITE REPLACE'
call lineout outPath,'id'||'09'x||'feed'||'09'x||'left_file'||'09'x||'right_file'||'09'x||'edge_serial'||'09'x||'source_family'||'09'x||'path_id'||'09'x||'time_ms'||'09'x||'side'||'09'x||'lag_samples'||'09'x||'score'
groups=0; points=0
/* dev9: 16-second seam-local input must produce a trajectory, not one sample
 * per side.  Four-second windows at a two-second step yield three complete
 * BEFORE and three complete AFTER windows around an 8s seam. */
scanWindowMs=4000; scanStepMs=2000

do forever
  a=r~next; if a==.nil then leave
  if a~items=1 & a[1]='' then iterate
  if a~items<>10 then do; say 'FAIL bad groups row'; exit 2; end
  gid=a[1]; gscore=a[8]+0; fcMask=a[9]; fdMask=a[10]
  safe=safeName(gid); ifc=tempDir||'/'||safe||'.fc.f32'; ifd=tempDir||'/'||safe||'.fd.f32'
  p~renderSelection(fcPath,fcMask,ifc,8000,256,64); p~renderSelection(fdPath,fdMask,ifd,8000,256,64)
  scan=p~scan(ifc,ifd,8000,scanWindowMs,scanStepMs,500,25); groups=groups+1
  do row over scan~rows
    absStart=baseMs+row~startMs; absEnd=absStart+scanWindowMs; side=''
    if absEnd<=edgeMs then side='BEFORE'
    else if absStart>=edgeMs then side='AFTER'
    else iterate
    timeMs=absStart+scanWindowMs/2; m=row~measurement
    points=points+emitPoint(outPath,groups,row~index,f,leftFile,rightFile,edge,gid,'ENVELOPE',timeMs,side,m~envelopeLagSamples,m~envelopeScore,gscore)
    points=points+emitPoint(outPath,groups,row~index,f,leftFile,rightFile,edge,gid,'DIRECT',timeMs,side,m~directLagSamples,m~directScore*m~directCoherence,gscore)
    points=points+emitPoint(outPath,groups,row~index,f,leftFile,rightFile,edge,gid,'REFINED',timeMs,side,m~refinedLagSamples,m~refinedScore*m~refinedCoherence,gscore)
  end
  call sysFileDelete ifc; call sysFileDelete ifd
end
r~close
call stream outPath,'C','CLOSE'
say 'PASS source-conditioned path points groups='||groups||' points='||points||' scan_window_ms='||scanWindowMs||' scan_step_ms='||scanStepMs||' out='||outPath
exit 0

emitPoint: procedure
  use arg outPath,gnum,ridx,feed,left,right,edge,gid,path,timeMs,side,lag,score,gscore
  score=score+0
  if score<=0 then return 0
  support=gscore/20; if support>1 then support=1; if support<.10 then support=.10
  final=score*support
  id='SRCPT|'||right(gnum,3,'0')||'|'||right(ridx,3,'0')||'|'||path
  call lineout outPath,id||'09'x||feed||'09'x||left||'09'x||right||'09'x||edge||'09'x||gid||'09'x||path||'09'x||timeMs||'09'x||side||'09'x||lag||'09'x||final
  return 1

safeName: procedure
  use arg s
  out=''; do i=1 to s~length; c=s~substr(i,1); if c~datatype('A') | c~datatype('N') | c='_' | c='-' then out=out||c; else out=out||'_'; end
  return out

quote: procedure
  use arg s
  return "'"||s~changestr("'","'\\''")||"'"
::requires 'AudioV9Tsv.cls'
::requires 'AudioV9SpatialNativeProvider.cls'
