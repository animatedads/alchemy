service = .FakeService~new
service~register(.FakeRegistration~new('COMPUTE_PLAN_ADMITTANCE'))
service~register(.FakeRegistration~new('COMPUTE_PREPARE_ADMISSION'))

workload = .TestWorkload~new('llm-coding-turn')
resource = .TestResource~new('local-model')
planner = .GeneralizedComputeIntentionProvider~new( -
    .FakeComputeAdapter~new(.array~of(resource)), -
    .AllowAdapter~new('allocation'), -
    .AllowAdapter~new('wlu'), -
    .AllowAdapter~new('router'))
bridge = .GeneralizedComputeStructuredIntentionProvider~new(planner, .FakeProposalFactory~new)

planToken = bridge~stage('PLAN_ADMITTANCE', workload)
call assertTrue planToken = 'COMPUTE_INTENTION GCI1', 'opaque staged token'
proposals = bridge~propose(service, planToken)
call assertEqual 1, proposals~items, 'one structured proposal'
proposal = proposals[1]
call assertTrue proposal~slots['WORKLOAD'] == workload, 'workload object retained in proposal'
request = proposal~slots['REQUEST']
call assertTrue request~workload == workload, 'request carries original workload object'
route = bridge~executeRequest(request)
call assertTrue route~workload == workload, 'route keeps original workload object'
call assertTrue route~preferredCandidate~resource == resource, 'resource object retained'

handoffToken = bridge~stage('PREPARE_ADMISSION', workload)
handoffProposal = bridge~propose(service, handoffToken)[1]
handoff = bridge~executeRequest(handoffProposal~slots['REQUEST'])
call assertTrue handoff~workload == workload, 'handoff carries workload object'
call assertTrue handoff~resource == resource, 'handoff carries resource object'
call assertEqual 0, planner~allocationAdapter~mutations, 'no allocation mutation'
call assertEqual 0, planner~wluAdapter~mutations, 'no WLU mutation'
call assertEqual 0, planner~routerAdapter~mutations, 'no router mutation'

/* Event adapter consumes the ordinary decision slots shape used by Intention Service. */
decision = .FakeDecision~new(handoffProposal~slots)
event = .GeneralizedComputeIntentionEvent~new(bridge)
eventResult = event~invoke(decision)
call assertTrue eventResult~workload == workload, 'event dispatch preserves request object'

say 'PASS structured Intention Service bridge and planned admission handoff'
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

/* Minimal stand-in for the external Intention Service proposal contract. */
::class FakeIntentionProposal public
::method init
  expose intentionId score providerName explicit evidence slots
  use arg intentionId, score, providerName, explicit, evidence
  slots = .directory~new
::attribute intentionId get
::attribute score get
::attribute providerName get
::attribute explicit get
::attribute evidence get
::attribute slots get
::method putSlot
  expose slots
  use arg name, value, explicit=.false
  slots[translate(name)] = value
  return self

::class FakeProposalFactory
::method newProposal
  use arg intentionId, score, providerName, explicit, evidence
  return .FakeIntentionProposal~new(intentionId, score, providerName, explicit, evidence)

::class FakeRegistration
::method init
  expose id
  use arg id
::attribute id get

::class FakeService
::method init
  expose registrations
  registrations = .directory~new
::method register
  expose registrations
  use arg registration
  registrations[registration~id] = registration
::method registration
  expose registrations
  use arg id
  key = translate(strip(id))
  if registrations~hasIndex(key) = 0 then return .nil
  return registrations[key]

::class FakeDecision
::method init
  expose slots
  use arg slots
::attribute slots get

::class TestWorkload
::method init
  expose id
  use arg id
::attribute id get

::class TestResource
::method init
  expose id
  use arg id
::attribute id get

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

::class AllowAdapter public
::method init
  expose authority mutations
  use arg authority
  mutations = 0
::attribute mutations get
::method assess
  expose authority
  use arg workload, resource, context=.nil
  return .IntentionAssessment~new(.true, authority, 'ALLOW', resource)

::requires '../src/GeneralizedComputeIntentions.cls'
