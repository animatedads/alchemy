mgr=.ObjectQueueManager~new("",.nil,"queue-admin")
cr=mgr~createQueue("exec-node-a","TEMPORARY","JOB-NODE",10,"queue-admin")
call assertTrue cr~ok,"queue create"

lease=.JobNodePlacementLease~new("PLACE-1","JOB-1","NODE-A","OWNER-A",7,11,100,1000,"R","C","O","P","PR","WLU-1","")
env=.JobNodeDispatchEnvelope~new(lease,"PAYLOAD")
d=.JobNodeQueueFabricDispatcher~new(mgr)~bindNodeQueue("NODE-A","exec-node-a")
r=d~dispatch(env,"queue-admin")
call assertTrue r~ok,"queue dispatch"
call assertTrue mgr~depth("exec-node-a","queue-admin")~value["ready"]=1,"ready depth"
p=mgr~claim("exec-node-a","queue-admin")
call assertTrue p~ok,"claim"
wp=p~value
call assertTrue wp~correlationId="PLACE-1","placement correlation"
call assertTrue wp~headers["job-node-owner-node-id"]="OWNER-A","owner preserved"
call assertTrue wp~headers["job-node-execution-node-id"]="NODE-A","execution preserved"
call assertTrue wp~headers["job-node-capability-generation"]=7,"capability generation preserved"
say "PASS Queue Fabric v0.9-dev4 placement dispatch adapter"
exit 0
assertTrue: procedure
 use arg condition,label
 if \condition then do; say "FAIL" label; exit 1; end
 return
::requires "JobNodeQueueFabricAdapter.cls"
