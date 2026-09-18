#!/usr/bin/env rexx
/* Deliberately uses a Directory source so this example has no QueueRexx runtime
 * dependency. A real QueueRexx adapter should call QueueJobStatusProjector and
 * existing typed operations rather than copy state into this Directory. */
facts=.Directory~new
facts["health"]="ok"
facts["depth"]=12
facts["rescan"]=""
source=.ComponentProjectionDirectorySource~new(facts)
registry=.ComponentProjectionRegistry~new
registry~registerReport("QueueRexx","/queuerexx/health",source,"health")
registry~registerReport("QueueRexx","/queuerexx/queues/default/depth",source,"depth")
registry~registerControl("QueueRexx","/queuerexx/control/rescan",source,"rescan","text/plain","example actuator",.false,64)

say .ComponentProjectionText~render(registry~readObject("/queuerexx/health"))
relation=.ComponentProjectionRelation~new(registry)
do row over relation~describeRows
  say row["path"] row["kind"] "read="row["readable"] "write="row["writable"]
end
::requires "ComponentProjection.cls"
