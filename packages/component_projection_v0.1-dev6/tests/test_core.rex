#!/usr/bin/env rexx
src=.ComponentProjectionDirectorySource~new
src~values["depth"]=7
src~values["wake"]="idle"
src~values["alpha"]="A"
r=.ComponentProjectionRegistry~new
r~registerReport("QueueRexx","/queuerexx/queues/default/depth",src,"depth")
r~registerReport("QueueRexx","/queuerexx/alpha",src,"alpha")
r~registerControl("QueueRexx","/queuerexx/control/wake",src,"wake")
if r~readObject("/queuerexx/queues/default/depth")<>7 then call fail "report read"
if \r~isDirectory("/queuerexx/queues/default") then call fail "directory synthesis"
a=r~list("/queuerexx")
if a==.nil | a~items<3 then call fail "directory list"
if a[1]<>"alpha" then call fail "directory list deterministic sort"
rel=.ComponentProjectionRelation~new(r)
row=rel~row("/queuerexx/queues/default/depth")
if row==.nil | row["value"]<>7 | row["kind"]<>"REPORT" | \row["readable"] then call fail "relation row"
ctl=rel~row("/queuerexx/control/wake")
if ctl==.nil | ctl["readable"] | \ctl["writable"] | ctl["value_available"] then call fail "write-only control metadata"
r~writeObject("/queuerexx/control/wake","1")
if src~values["wake"]<>"1" then call fail "control write"
if \r~unregister("/queuerexx/alpha") then call fail "unregister"
if r~exists("/queuerexx/alpha") then call fail "unregister still exists"
if r~unregisterTree("/queuerexx/control","QueueRexx")<>1 then call fail "unregister tree"
if r~exists("/queuerexx/control/wake") then call fail "unregister tree still exists"
if r~isDirectory("/queuerexx/control") then call fail "stale synthesized directory"
d=.directory~new; d["z"]="last"; d["a"]="first"
text=.ComponentProjectionText~render(d)
if left(text,8)<>"a=first"||d2c(10) then call fail "deterministic directory text"
say "PASS component projection core"
exit 0
fail: procedure
  parse arg why
  say "FAIL" why
  exit 1
::requires "../src/ComponentProjection.cls"
