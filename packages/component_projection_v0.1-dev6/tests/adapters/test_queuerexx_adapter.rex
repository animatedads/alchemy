#!/usr/bin/env rexx
store=.FakeQueueRexxStore~new
store~add(.FakeQueueRexxRecord~new("17","pending","/q/pending/17.job","demo","AUDIO",42,"echo hi"))
store~add(.FakeQueueRexxRecord~new("a/b","running","/q/running/ab.job","slash","DEFAULT",5,"true"))
registry=.ComponentProjectionRegistry~new
adapter=.QueueRexxComponentProjectionAdapter~new(registry,store,.FakeStatusProjector~new,.FakeHealthScanner~new)
if adapter~install<>2 then call fail "install job count"
if registry~readObject("/queuerexx/jobs/count")<>2 then call fail "job count"
if registry~readObject("/queuerexx/jobs/17/state")<>"pending" then call fail "state"
if registry~readObject("/queuerexx/jobs/17/class")<>"AUDIO" then call fail "class"
if registry~readObject("/queuerexx/jobs/a%2Fb/state")<>"running" then call fail "typed slash qid dispatch"
status=registry~readObject("/queuerexx/jobs/17/status")
if status["qid"]<>"17" then call fail "status projector delegation"
health=registry~readObject("/queuerexx/health")
if health["status"]<>"OK" then call fail "health delegation"
store~clear
if adapter~refresh<>0 then call fail "refresh count"
if registry~exists("/queuerexx/jobs/17") then call fail "stale job namespace"
if adapter~uninstall<1 then call fail "uninstall"
say "PASS QueueRexx component projection adapter"
exit 0
fail: procedure
  parse arg why
  say "FAIL" why
  exit 1

::class FakeQueueRexxRecord
::attribute qid get
::attribute stateName get
::attribute path get
::attribute name get
::attribute effectiveJobClass get
::attribute priority get
::attribute commandLine get
::method init
  expose qid stateName path name effectiveJobClass priority commandLine
  use strict arg qid,stateName,path,name,effectiveJobClass,priority,commandLine

::class FakeQueueRexxStore
::method init
  expose rows
  rows=.array~new
::method add
  expose rows
  use strict arg row
  rows~append(row)
::method clear
  expose rows
  rows=.array~new
::method records
  expose rows
  return rows
::method findAll
  expose rows
  use strict arg qid
  out=.array~new
  do row over rows
    if row~qid=qid then out~append(row)
  end
  return out

::class FakeProjection
::attribute data get
::method init
  expose data
  use strict arg data
::method asDirectory
  expose data
  return data

::class FakeStatusProjector
::method project
  use strict arg qid
  d=.directory~new; d["qid"]=qid; d["code"]="OK"
  return .FakeProjection~new(d)

::class FakeHealthScanner
::method scan
  d=.directory~new; d["status"]="OK"
  return .FakeProjection~new(d)

::requires "ComponentProjection.cls"
::requires "adapters/ComponentProjectionQueueRexx.cls"
