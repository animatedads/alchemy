/* Synthetic-only ooRexx privacy boundary qualification.
 * Must be executed with resident Foreign Runtime and an existing private
 * ALCHEMY_PRIVATE_MEDIA_ROOT outside ALL Git worktrees.
 */
root=value('ALCHEMY_PRIVATE_MEDIA_ROOT',,'ENVIRONMENT')
if root='' then do
  say 'FAIL: set ALCHEMY_PRIVATE_MEDIA_ROOT to a private absolute test directory'
  exit 64
end
providerDir='tests/fixtures/foreign_runtime_video'
raw=charin(providerDir||'/job.json',1,chars(providerDir||'/job.json'))
call charin providerDir||'/job.json'
raw=changestr('"/tmp"','"'||root||'"',raw)
job=root||'/synthetic-private-gate-job.json'
result=root||'/synthetic-private-gate-result.json'
call charout job,raw
call charout job
invoker=.MediaForeignVideoInvoker~new(providerDir)
call assert invoker~preflightPaths(job,result)='ADMITTED','valid synthetic job'
call assert rejects(invoker,job,'/etc/invalid-outside-root.json'),'result path outside root'
call assert rejects(invoker,job,result,'VIDEO.RECON.MOVING_STRIP_MOSAIC'),'method mismatch rejected'
badNameJob=root||'/synthetic-private-gate-traversal.json'
call charout badNameJob,changestr('"time"','"candidate_id": "../escape", "time"',raw)
call charout badNameJob
call assert rejects(invoker,badNameJob,result),'candidate traversal rejected'
badSourceJob=root||'/synthetic-private-gate-outside-source.json'
call charout badSourceJob,changestr('"SYNTHETIC_ONLY"','"VIDEO_FILE", "path": "/etc/hosts"',raw)
call charout badSourceJob
call assert rejects(invoker,badSourceJob,result),'source path outside root rejected'
badKindJob=root||'/synthetic-private-gate-unsupported-source.json'
call charout badKindJob,changestr('"SYNTHETIC_ONLY"','"UNSUPPORTED_SOURCE"',raw)
call charout badKindJob
call assert rejects(invoker,badKindJob,result),'unsupported source kind rejected'
call assert invoker~preflightPaths(job,result)='ADMITTED','gate remains valid after rejected jobs'
if rxfuncquery('SysFileDelete')=0 then do
  call SysFileDelete job
  call SysFileDelete badNameJob
  call SysFileDelete badSourceJob
  call SysFileDelete badKindJob
end
say 'PASS private Foreign video preflight 7/7 (synthetic)'
exit 0

::routine rejects
  use strict arg gate,jobPath,resultPath,expectedMethodologyId=''
  signal on syntax name rejected
  verdict=gate~preflightPaths(jobPath,resultPath,expectedMethodologyId)
  signal off syntax
  return .false
rejected:
  signal off syntax
  return .true

::routine assert
  use strict arg condition,description
  if \condition then raise syntax 93.900 array('FAIL',description)

::requires 'MediaForeignVideoInvoker.cls'
