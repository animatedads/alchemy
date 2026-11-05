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
call charout job,changestr('"time"','"candidate_id": "../escape", "time"',raw)
call charout job
call assert rejects(invoker,job,result),'candidate traversal rejected'
call charout job,changestr('"SYNTHETIC_ONLY"','"VIDEO_FILE", "path": "/etc/hosts"',raw)
call charout job
call assert rejects(invoker,job,result),'source path outside root rejected'
call charout job,raw
call charout job
call assert invoker~preflightPaths(job,result)='ADMITTED','gate recovers after invalid job'
if rxfuncquery('SysFileDelete')=0 then call SysFileDelete job
say 'PASS private Foreign video preflight 5/5 (synthetic)'
exit 0

::routine rejects
  use strict arg gate,jobPath,resultPath
  signal on syntax name rejected
  verdict=gate~preflightPaths(jobPath,resultPath)
  signal off syntax
  return .false
rejected:
  signal off syntax
  return .true

::routine assert
  use strict arg condition,description
  if \condition then raise syntax 93.900 array('FAIL',description)

::requires 'MediaForeignVideoInvoker.cls'
