workload = .TestWorkload~new('coding-turn')
resource = .TestResource~new('llm-local')
planner = .GeneralizedComputeIntentionProvider~new( -
    .FakeComputeAdapter~new(.array~of(resource)), -
    .AllowAdapter~new('allocation'), -
    .AllowAdapter~new('wlu'), -
    .AllowAdapter~new('router'))

surface = planner~discoverFor(workload)
call assertEqual 4, surface['operation_descriptors']~items, 'four operation descriptors'
call assertEqual 6, surface['relationships']~items, 'relationship surface'
prepare = surface['operation_descriptors'][4]
call assertTrue prepare['available'], 'prepare available on READY route'

bridge = .GeneralizedComputeStructuredIntentionProvider~new(planner, .FakeProposalFactory~new)
service = .FakeService~new
service~register(.FakeRegistration~new('COMPUTE_PREPARE_ADMISSION'))
token = bridge~stage('PREPARE_ADMISSION', workload)
proposal = bridge~propose(service, token)[1]
event = .GeneralizedComputeIntentionEvent~new(bridge)

blocked = .FakeDecision~new('CONFIRM', proposal~slots)
signal on syntax name caughtNotReady
event~invoke(blocked)
signal off syntax
say 'FAIL structured event accepted non-READY decision'
exit 1
caughtNotReady:
  signal off syntax

ready = .FakeDecision~new('READY', proposal~slots)
handoff = event~invoke(ready)
call assertTrue handoff~workload == workload, 'READY event preserves workload object'

say 'PASS dynamic surface relationships and READY dispatch guard'
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

::class FakeIntentionProposal public
::method init
  expose intentionId score providerName explicit evidence slots
  use arg intentionId, score, providerName, explicit, evidence
  slots = .directory~new
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
  expose status slots
  use arg status, slots
::attribute status get
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
  expose authority
  use arg authority
::method assess
  expose authority
  use arg workload, resource, context=.nil
  return .IntentionAssessment~new(.true, authority, 'ALLOW', resource)

::requires '../src/GeneralizedComputeIntentions.cls'
