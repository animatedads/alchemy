/* Real Generalized Compute + real MVS + real Managed Service surfaces. */

compute = .FakeComputeAdapter~new
allocation = .AlwaysAllowAdapter~new('allocator')
wlu = .AlwaysAllowAdapter~new('wlu')
router = .AlwaysAllowAdapter~new('router')
computeProvider = .GeneralizedComputeIntentionProvider~new(compute, allocation, wlu, router)
computeAssessor = .ComputeDomainAssessor~new
computeSource = .ManagementIntentionSurfaceSource~new('generalized.compute', computeProvider, computeAssessor)

mvsRunner = .MvsIntentionRunner~new('ED209Z', .MvsFixtureDiscoveryBackend~new)
mvsSource = .ManagementMvsIntentionSurfaceSource~new(mvsRunner)

serviceObject = .ManagedServiceFixture~new('JES-ED209Z', 'JES', 'ED209Z')
serviceRegistry = .MutableServiceRegistry~new(.Array~of(serviceObject))
serviceProvider = .ManagedServiceIntentionProvider~new(serviceRegistry)
serviceSource = .ManagementSelfAssessingIntentionSurfaceSource~new('service.management', serviceProvider)

directory = .ManagementIntentionDirectory~new
directory~registerSource(computeSource)
directory~registerSource(mvsSource)
directory~registerSource(serviceSource)

/* The sentence independently belongs to MVS (LIST_JOBS) and service management. */
r1 = directory~resolve('show jobs for this service', .Directory~new)
call assertEqual 2, r1~relevantCandidates~items, 'MVS and service surfaces compose'
call assertTrue hasSource(r1, 'mvs'), 'MVS included'
call assertTrue hasSource(r1, 'service.management'), 'service included'

/* Named real service object alone selects service semantics. */
r2 = directory~resolve('is JES healthy', .Directory~new)
call assertEqual 1, r2~relevantCandidates~items, 'JES service selected'
call assertEqual 'service.management', r2~relevantCandidates[1]~entry~sourceId, 'service source selected'
call assertTrue r2~relevantCandidates[1]~assessment~evidence['objects'][1] == serviceObject, 'service object preserved'

/* Compute remains a separate specialist. */
r3 = directory~resolve('can this workload run on available compute', .Directory~new)
call assertEqual 1, r3~relevantCandidates~items, 'compute specialist stands alone'
call assertEqual 'generalized.compute', r3~relevantCandidates[1]~entry~sourceId, 'compute selected'

say 'PASS test_cross_domain_composition'
exit 0

hasSource: procedure
  use arg resolution, wanted
  do candidate over resolution~relevantCandidates
    if candidate~entry~sourceId == wanted then return .true
  end
  return .false

assertTrue: procedure
  use arg condition, label
  if \condition then do; say 'FAIL:' label; exit 1; end
return
assertEqual: procedure
  use arg expected, actual, label
  if expected \== actual then do; say 'FAIL:' label 'expected='expected 'actual='actual; exit 1; end
return

::class ComputeDomainAssessor subclass ManagementRelevanceAssessor
::method assess
  use arg request, surface, context=.nil
  text = translate(request)
  relevant = pos('WORKLOAD', text) > 0 | pos('COMPUTE', text) > 0
  if relevant then return .ManagementRelevanceAssessment~new(.true, 90, 'GENERALIZED_COMPUTE', 'COMPUTE_REQUEST', surface)
  return .ManagementRelevanceAssessment~new(.false, 0, 'GENERALIZED_COMPUTE', 'NO_COMPUTE_REQUEST', surface)

::class FakeResource
::method init
  use arg id
  self~id = id
::attribute id

::class FakeComputeAdapter subclass ComputeIntentionAdapter
::method discoverCandidates
  use arg workload, context=.nil
  return .Array~of(.FakeResource~new('cpu-a'))
::method assess
  use arg workload, resource, context=.nil
  return .IntentionAssessment~new(.true, 'compute', 'CAPABLE')

::class AlwaysAllowAdapter
::method init
  use arg authority
  self~authority = authority
::attribute authority
::method assess
  use arg workload, resource, context=.nil
  return .IntentionAssessment~new(.true, self~authority, 'ALLOWED')

::class ManagedServiceFixture
::method init
  use arg id, kind, host
  self~id = id; self~name = id; self~kind = kind; self~host = host; self~aliases = .Array~new
::attribute id
::attribute name
::attribute kind
::attribute host
::attribute aliases

::class MutableServiceRegistry
::method init
  use arg services
  self~services = services
::attribute services
::method discoverServices
  use arg context=.nil
  return self~services

::requires '../src/ManagementIntentionDiscovery.cls'
::requires '../src/MvsIntentionSurfaceAdapter.cls'
::requires '../src/MachineServiceIntentions.cls'
::requires '../vendor/mvs-intentions/MvsIntention.cls'
::requires '../vendor/generalized-compute/GeneralizedComputeIntentions.cls'
