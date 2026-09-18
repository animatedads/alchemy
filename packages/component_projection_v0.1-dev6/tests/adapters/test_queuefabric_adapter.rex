#!/usr/bin/env rexx
manager=.ObjectQueueManager~new("",.nil,"admin")
create=manager~createQueue("TEST.Q","TEMPORARY","DEFAULT",10,"admin")
if \create~ok then call fail "queue create"
create2=manager~createQueue("A/B","TEMPORARY","DEFAULT",10,"admin")
if \create2~ok then call fail "slash queue create"
registry=.ComponentProjectionRegistry~new
adapter=.QueueFabricComponentProjectionAdapter~new(registry,manager,"admin")
if adapter~install<>2 then call fail "install queue count"
if registry~readObject("/queuefabric/queue_count")<>2 then call fail "manager queue count"
row=registry~readObject("/queuefabric/queues/TEST.Q/depth")
if row["total"]<>0 then call fail "initial depth"
ctl=registry~endpoint("/queuefabric/queues/TEST.Q/inject")
if ctl==.nil | ctl~readable | \ctl~writable then call fail "inject control metadata"
if \registry~writeObject("/queuefabric/queues/TEST.Q/inject","hello projection") then call fail "inject rejected"
if \registry~writeObject("/queuefabric/queues/A%2FB/inject","slash payload") then call fail "slash inject rejected"
slashBrowse=manager~browse("A/B","admin")
if \slashBrowse~ok | slashBrowse~value~payload<>"slash payload" then call fail "typed slash queue dispatch"
row=registry~readObject("/queuefabric/queues/TEST.Q/depth")
if row["ready"]<>1 | row["total"]<>1 then call fail "depth after inject"
b=manager~browse("TEST.Q","admin")
if \b~ok | b~value~payload<>"hello projection" then call fail "payload authority path"
registry2=.ComponentProjectionRegistry~new
adapter2=.QueueFabricComponentProjectionAdapter~new(registry2,manager,"nobody","/qf2")
adapter2~install
if registry2~writeObject("/qf2/queues/TEST.Q/inject","denied") then call fail "authority bypass"
if adapter~uninstall<1 then call fail "uninstall"
if registry~exists("/queuefabric") then call fail "stale namespace"
say "PASS Queue Fabric component projection adapter"
exit 0
fail: procedure
  parse arg why
  say "FAIL" why
  exit 1
::requires "ObjectQueueFabric.cls"
::requires "ComponentProjection.cls"
::requires "adapters/ComponentProjectionQueueFabric.cls"
