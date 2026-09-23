/* Coherent source stability: stable regular file passes; append and symlink
 * replacement fail closed.  This test intentionally uses the real
 * oorexx.posix/0.1 coherent gap provider. */
parse arg root .
if root='' then root='.'
tmp=root||'/qualification/source_guard'
ignore=.PosixGapFactory~create
p=ignore
/* cleanup without shell */
do path over .array~of(tmp||'.link',tmp||'.b',tmp||'.a')
  if stream(path,'C','QUERY EXISTS')<>'' then x=p~unlink(path)
end
call lineout tmp||'.a','alpha'; call stream tmp||'.a','C','CLOSE'
g=.FDSourceStabilityGuard~new(p,tmp||'.a',50,2)
if \g~establish then call fail 'stable file rejected status='||g~status||' error='||g~lastError
if g~checks<2 | g~targetIdentity='' | g~targetSize<=0 then call fail 'incomplete stable evidence'
call lineout tmp||'.a','beta'; call stream tmp||'.a','C','CLOSE'
if g~check then call fail 'append mutation not detected'
if g~status<>'SOURCE_MUTATED' | \g~mutationDetected then call fail 'wrong append mutation status='||g~status

call lineout tmp||'.b','bravo'; call stream tmp||'.b','C','CLOSE'
r=p~symlink(tmp||'.a',tmp||'.link'); if \r~ok then call fail 'symlink create '||r~error~string
g2=.FDSourceStabilityGuard~new(p,tmp||'.link',50,2)
if \g2~establish then call fail 'symlink stable establishment '||g2~status
r=p~unlink(tmp||'.link'); if \r~ok then call fail 'symlink unlink'
r=p~symlink(tmp||'.b',tmp||'.link'); if \r~ok then call fail 'symlink replace'
if g2~check then call fail 'symlink retarget not detected'
if g2~status<>'SOURCE_MUTATED' then call fail 'wrong symlink mutation status='||g2~status

do path over .array~of(tmp||'.link',tmp||'.b',tmp||'.a')
  if stream(path,'C','QUERY EXISTS')<>'' then x=p~unlink(path)
end
say 'PASS source stability coherent checks='||g~checks 'identity='||g~targetIdentity
exit 0
fail: procedure
  parse arg m
  say 'FAIL' m
  exit 1
::requires 'FDDoorMicroMotion.cls'
::requires 'PosixGap.cls'
