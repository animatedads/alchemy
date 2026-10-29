numeric digits 30
provider=.MemoryProvider~new
target=.DeploymentTarget~new('T1')
manifest=.DeploymentManifest~new('fixture','1')
manifest~addRequirement(.DeploymentRequirement~new('dir','directory:/app','present'))
d=.Deployment~new(provider)
plan=d~plan(target,manifest)
call must plan~actions~items=1,'one action planned'
result=d~apply(plan)
call must result~satisfied,'fresh post-apply verification satisfied'
plan2=d~plan(target,manifest)
call must plan2~noActionRequired,'second plan is idempotent no-op'
say 'PASS deployment model'
exit 0
must: procedure
 use strict arg c,m
 if \c then do; say 'FAIL' m; exit 1; end
return

::class MemoryProvider subclass DeploymentProvider
::method init
 expose facts
 facts=.directory~new
::method name; return 'memory'
::method discover
 expose facts
 use strict arg target,manifest
 d=.DeploymentDiscovery~new(target)
 do k over facts~allIndexes; d~putFact(k,facts[k]); end
 return d
::method assessRequirement
 use strict arg target,req,discovery,manifest
 actual=discovery~fact(req~kind,'absent'); ok=(actual=req~expected)
 reason=''; if \ok then reason='expected '||req~expected||' observed '||actual
 return .DeploymentAssessmentItem~new(req,actual,ok,reason)
::method actionFor
 use strict arg target,item,discovery,manifest,n
 return .DeploymentAction~new('A'||n,'ESTABLISH',item~reason,item~requirement,'memory',.false,.true)
::method applyAction
 expose facts
 use strict arg target,action,manifest
 req=action~requirement; facts[req~kind]=req~expected
 return .DeploymentActionResult~new(action,.true,'','memory-state-updated')
::requires 'Deployment.cls'
