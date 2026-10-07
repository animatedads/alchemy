workload = .TestWorkload~new('coding-turn')
local = .TestResource~new('local-llm', 'LLM')
remote = .TestResource~new('remote-llm', 'LLM')
cpu = .TestResource~new('cpu-node', 'CPU')
resources = .array~of(local, remote, cpu)

compute = .FakeComputeAdapter~new(resources)
alloc = .FakeAllocationAdapter~new
wlu = .FakeWLUAdapter~new
router = .FakeRouterAdapter~new
provider = .GeneralizedComputeIntentionProvider~new(compute, alloc, wlu, router)

route = provider~planAdmittance(workload)
call assertEqual 'READY', route~state, 'route state'
call assertEqual 3, route~candidates~items, 'candidate count'
call assertTrue route~candidates[1]~resource == local, 'resource object retained'
call assertTrue route~candidates[1]~isAdmissible, 'local admissible'
call assertTrue \route~candidates[2]~isAdmissible, 'remote rejected by policy/router'
call assertTrue \route~candidates[3]~isAdmissible, 'cpu rejected by WLU'
call assertTrue route~preferredCandidate~resource == local, 'preferred route is local object'
handoff = route~handoff
call assertTrue handoff~route == route, 'handoff retains planned route object'
call assertTrue handoff~resource == local, 'handoff retains selected resource object'
call assertEqual 0, alloc~mutations, 'planner did not allocate'
call assertEqual 0, wlu~mutations, 'planner did not reserve'
call assertEqual 0, router~mutations, 'planner did not dispatch'

surface = provider~discover
call assertEqual 'generalized.compute.intentions/0.1', surface['provider'], 'provider id'
call assertTrue \surface['mutating'], 'surface is non-mutating'
call assertEqual 4, surface['operations']~items, 'surface operation count'

say 'PASS planned admittance route preserves objects and authority boundaries'
exit 0

assertEqual: procedure
  use arg expected, actual, label
  if expected \= actual then do
    say 'FAIL' label 'expected='expected 'actual='actual
    exit 1
  end
  return

assertTrue: procedure
  use arg condition, label
  if \condition then do
    say 'FAIL' label
    exit 1
  end
  return

::class TestWorkload
::method init
  expose id
  use arg id
::attribute id

::class TestResource
::method init
  expose id kind
  use arg id, kind
::attribute id
::attribute kind

::class FakeComputeAdapter subclass ComputeIntentionAdapter
::method init
  expose resources
  use arg resources
::method discoverCandidates
  expose resources
  use arg workload, context=.nil
  return resources
::method assess
  use arg workload, resource, context=.nil
  return .IntentionAssessment~new(.true, 'compute', 'CAPABLE', resource)

::class FakeAllocationAdapter subclass AllocationIntentionAdapter
::method init
  expose mutations
  mutations = 0
::attribute mutations get
::method assess
  use arg workload, resource, context=.nil
  return .IntentionAssessment~new(.true, 'allocation', 'PLACEMENT_ELIGIBLE', resource)

::class FakeWLUAdapter subclass WLUIntentionsAdapter
::method init
  expose mutations
  mutations = 0
::attribute mutations get
::method assess
  use arg workload, resource, context=.nil
  if resource~id = 'cpu-node' then return .IntentionAssessment~new(.false, 'wlu', 'INSUFFICIENT_CAPACITY', resource)
  return .IntentionAssessment~new(.true, 'wlu', 'ADMISSION_FEASIBLE', resource)

::class FakeRouterAdapter subclass RouterIntentionAdapter
::method init
  expose mutations
  mutations = 0
::attribute mutations get
::method assess
  use arg workload, resource, context=.nil
  if resource~id = 'remote-llm' then return .IntentionAssessment~new(.false, 'router', 'REMOTE_POLICY_BLOCKED', resource)
  return .IntentionAssessment~new(.true, 'router', 'ROUTE_ELIGIBLE', resource)

::requires '../src/GeneralizedComputeIntentions.cls'
