#!/usr/bin/env rexx
parse arg root
if root="" then do; say "FAIL missing root"; exit 2; end
store=.QueueStateStore~new(root)
registry=.ComponentProjectionRegistry~new
adapter=.QueueRexxComponentProjectionAdapter~new(registry,store)
if adapter~install<>1 then call fail "actual install count"
if registry~readObject("/queuerexx/jobs/count")<>1 then call fail "actual job count"
if registry~readObject("/queuerexx/jobs/example/state")<>"pending" then call fail "actual state"
if registry~readObject("/queuerexx/jobs/example/name")<>"hello world" then call fail "actual name"
if registry~readObject("/queuerexx/jobs/example/class")<>"DEFAULT" then call fail "actual class"
if registry~readObject("/queuerexx/jobs/example/priority")<>10 then call fail "actual priority"
say "PASS QueueRexx actual store projection adapter"
exit 0
fail: procedure
  parse arg why
  say "FAIL" why
  exit 1
::requires "QueueRexxCore.cls"
::requires "ComponentProjection.cls"
::requires "adapters/ComponentProjectionQueueRexx.cls"
