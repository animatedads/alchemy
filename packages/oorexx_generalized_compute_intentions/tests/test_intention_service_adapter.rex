workload = .TestWorkload~new('coding-turn')
resource = .TestResource~new('llm-local')
planner = .GeneralizedComputeIntentionProvider~new( -
    .FakeComputeAdapter~new(.array~of(resource)), -
    .AllowAdapter~new('allocation'), -
    .AllowAdapter~new('wlu'), -
    .AllowAdapter~new('router'))
adapter = .GeneralizedComputeIntentionServiceAdapter~new(planner)
service = .IntentionService~new
regs = adapter~registerCurrentSurface(service, workload)
call assertEqual 4, regs~items, 'registered current surface'
call assertTrue service~registration('PLAN_COMPUTE_ADMITTANCE') \== .nil, 'plan registration id'
call assertTrue service~registration('PREPARE_COMPUTE_ADMISSION') \== .nil, 'prepare registration id'

token = adapter~structuredProvider~stage('PLAN_ADMITTANCE', workload)
decision = service~input(token)
if decision~status = 'CONFIRM' then decision = service~input('yes')
call assertEqual 'READY', decision~status, 'staged plan reaches READY'
route = service~dispatch(decision)
call assertTrue route~workload == workload, 'real Intention Service dispatch keeps workload object'

say 'PASS real Intention Service dev11 registration and structured dispatch'
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
  if \\condition then do
    say 'FAIL' label
    exit 1
  end
  return

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

::requires '../src/GeneralizedComputeIntentionServiceAdapter.cls'
