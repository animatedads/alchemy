callsBefore=0
a=.AIModelRouteCandidate~new('MODEL-A','OPENAI-COMPAT','model-a','direct','EU',.false,'AI:A',100,200,'prod','client-a','model.complete',.array~of('CHAT','TOOLS'))
b=.AIModelRouteCandidate~new('MODEL-B','LOCAL','model-b','local','ANY',.false,'AI:B',80,150,'prod','client-b','model.complete',.array~of('CHAT'))

router=.FakeModelRouter~new('MODEL-A')
routeContext=.AIModelRouterPlanningContext~new(.Object~new,.Object~new,.Object~new,.Object~new,.Object~new,'AI-MODEL-ROUTE')
context=.directory~new
context['AI_MODEL_ROUTER_CONTEXT']=routeContext

compute=.CandidateCompute~new(.array~of(a,b))
allow=.AlwaysAllow~new
planner=.GeneralizedComputeIntentionProvider~new(compute,allow,allow,.AIModelRouterIntentionAdapter~new(router))

route=planner~planAdmittance(.Object~new,context)
call assertEqual 1,router~calls,'AI Model Router evaluated once for the complete planning turn'
call assertEqual 'READY',route~state,'one permitted model route keeps plan READY'
call assertTrue route~candidates[1]~isAdmissible,'selected model route remains admissible'
call assertTrue \route~candidates[2]~isAdmissible,'non-selected model route is rejected by router evidence'
call assertTrue route~preferredCandidate~resource==a,'selected route keeps original AIModelRouteCandidate object'
call assertEqual 'AI_MODEL_ROUTE_PERMITTED_NOT_ADMITTED',route~candidates[1]~routerAssessment~reason,'router evidence does not claim admission'
call assertTrue route~candidates[1]~routerAssessment~evidence==router~lastOutcome,'original router outcome retained as evidence'
call assertTrue \router~lastPlan~admitted,'router plan still reports not admitted'
call assertTrue \router~lastPlan~executableAuthority,'router plan still reports no execution authority'

missing=planner~planAdmittance(.Object~new,.directory~new)
call assertEqual 'INFEASIBLE',missing~state,'missing router authority context fails closed'
call assertEqual 1,router~calls,'missing context does not call router'

say 'PASS AI Model Router adapter preserves one-decision-per-plan and non-entitling authority'
exit 0

assertEqual: procedure
  use strict arg expected,actual,label
  if expected \= actual then raise syntax 93.900 array('assertEqual failed:' label 'expected='expected 'actual='actual)
  return
assertTrue: procedure
  use strict arg value,label
  if value \== .true then raise syntax 93.900 array('assertTrue failed:' label)
  return

::class CandidateCompute subclass ComputeIntentionAdapter
::method init
  expose candidates
  use strict arg candidates
::method discoverCandidates
  expose candidates
  use arg workload,context=.nil
  return candidates
::method assess
  use arg workload,resource,context=.nil
  return .IntentionAssessment~new(.true,'compute','CAPABLE',resource)

::class AlwaysAllow
::method assess
  use arg workload,resource,context=.nil
  return .IntentionAssessment~new(.true,'test-authority','ALLOW',resource)

::class FakeModelPlan
::method init
  expose routeId
  use strict arg routeId
::attribute routeId get
::method admitted
  return .false
::method executableAuthority
  return .false

::class FakeModelOutcome
::method init
  expose ok code detail value
  use strict arg value
  ok=.true
  code='OK'
  detail=''
::attribute ok get
::attribute code get
::attribute detail get
::attribute value get

::class FakeModelRouter
::method init
  expose selected calls lastOutcome lastPlan
  use strict arg selected
  calls=0
  lastOutcome=.nil
  lastPlan=.nil
::attribute calls get
::attribute lastOutcome get
::attribute lastPlan get
::method route
  expose selected calls lastOutcome lastPlan
  use strict arg catalog,request,source,advisoryPolicy,policyCatalog,policyId,actionTime=.nil,actorMode='AUTOMATED'
  calls+=1
  lastPlan=.FakeModelPlan~new(selected)
  lastOutcome=.FakeModelOutcome~new(lastPlan)
  return lastOutcome

::requires '../src/GeneralizedComputeAIModelRouterAdapter.cls'
