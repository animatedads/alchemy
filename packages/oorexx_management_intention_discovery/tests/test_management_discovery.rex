call addToPath

compute = .FakeComputeAdapter~new
allocation = .AlwaysAllowAdapter~new('allocator')
wlu = .AlwaysAllowAdapter~new('wlu')
router = .AlwaysAllowAdapter~new('router')
computeProvider = .GeneralizedComputeIntentionProvider~new(compute, allocation, wlu, router)
computeAssessor = .WordRelevanceAssessor~new(.array~of('compute', 'run', 'admit', 'route'), 'generalized.compute', 80)
computeSource = .ManagementIntentionSurfaceSource~new('generalized.compute', computeProvider, computeAssessor)

serviceProvider = .MutableSurfaceProvider~new('service.management/0.1', .array~of('GET_SERVICE_STATE', 'EXPLAIN_SERVICE'))
serviceAssessor = .WordRelevanceAssessor~new(.array~of('service', 'hercules', 'down', 'unavailable'), 'service.management', 90)
serviceSource = .ManagementIntentionSurfaceSource~new('service.management', serviceProvider, serviceAssessor)

mvsProvider = .MutableSurfaceProvider~new('mvs.intentions/0.1', .array~of('GET_MVS_STATE', 'LIST_JOBS'))
mvsAssessor = .WordRelevanceAssessor~new(.array~of('mvs', 'ed209z', 'job', 'unavailable'), 'mvs', 95)
mvsSource = .ManagementIntentionSurfaceSource~new('mvs', mvsProvider, mvsAssessor)

directory = .ManagementIntentionDirectory~new
directory~registerSource(computeSource)
directory~registerSource(serviceSource)
directory~registerSource(mvsSource)

/* Fresh discovery, object-preserving surface. */
s1 = directory~discover(.directory~new)
call assertEqual 3, s1~entries~items, 'three intention surfaces discovered'
computeSurface = s1~entries[1]~surface
call assertTrue computeSurface~isA(.Directory), 'compute provider surface object preserved'
call assertEqual 'generalized.compute.intentions/0.1', computeSurface['provider'], 'real compute intention provider discovered'
call assertEqual 3, computeSurface['operations']~items, 'compute operations preserved'

/* Multi-surface resolution: no forced single winner. */
r1 = directory~resolve('why is ED209Z unavailable', .directory~new)
call assertEqual 2, r1~relevantCandidates~items, 'MVS and service both relevant'
call assertEqual 'mvs', r1~preferredCandidate~entry~sourceId, 'highest domain-owned score wins only as convenience projection'

/* A compute request selects the specialist compute intention surface. */
r2 = directory~resolve('can this workload run on available compute', .directory~new)
call assertEqual 1, r2~relevantCandidates~items, 'compute request selects compute specialist'
call assertEqual 'generalized.compute', r2~relevantCandidates[1]~entry~sourceId, 'compute specialist selected'

/* Rediscovery is per-call.  Surface changes are immediately visible. */
serviceProvider~operations = .array~of('GET_SERVICE_STATE', 'EXPLAIN_SERVICE', 'RESTART_SERVICE')
s2 = directory~discover(.directory~new)
call assertEqual 3, s2~entries[2]~surface['operations']~items, 'changed domain surface rediscovered'
call assertTrue s2~generation > s1~generation, 'discovery generation advanced'

/* Relevance is also re-evaluated per resolve; no cached routing truth. */
serviceAssessor~enabled = .false
r3 = directory~resolve('why is ED209Z unavailable', .directory~new)
call assertEqual 1, r3~relevantCandidates~items, 'disabled service relevance disappears on next resolve'
call assertEqual 'mvs', r3~relevantCandidates[1]~entry~sourceId, 'remaining MVS surface retained'

say 'PASS test_management_discovery'
exit 0

assertTrue: procedure
  use arg condition, label
  if \condition then do
    say 'FAIL:' label
    exit 1
  end
return

assertEqual: procedure
  use arg expected, actual, label
  if expected \== actual then do
    say 'FAIL:' label 'expected='expected 'actual='actual
    exit 1
  end
return

addToPath: procedure
  here = directory()
return

::class MutableSurfaceProvider
::method init
  use arg providerId, operations
  self~providerId = providerId
  self~operations = operations
::attribute providerId
::attribute operations
::method discover
  use arg context=.nil
  surface = .directory~new
  surface['provider'] = self~providerId
  surface['operations'] = self~operations
  surface['mutating'] = .false
  surface['context'] = context
  return surface

::class WordRelevanceAssessor subclass ManagementRelevanceAssessor
::method init
  use arg words, authority, score
  self~words = words
  self~authority = authority
  self~scoreValue = score
  self~enabled = .true
::attribute words
::attribute authority
::attribute scoreValue
::attribute enabled
::method assess
  use arg request, surface, context=.nil
  if \self~enabled then return .ManagementRelevanceAssessment~new(.false, 0, self~authority, 'DISABLED')
  text = translate(request)
  do word over self~words
    if pos(translate(word), text) > 0 then return .ManagementRelevanceAssessment~new(.true, self~scoreValue, self~authority, 'DOMAIN_MATCH', surface)
  end
  return .ManagementRelevanceAssessment~new(.false, 0, self~authority, 'NO_DOMAIN_MATCH', surface)

::class FakeResource
::method init
  use arg id
  self~id = id
::attribute id

::class FakeComputeAdapter subclass ComputeIntentionAdapter
::method discoverCandidates
  use arg workload, context=.nil
  return .array~of(.FakeResource~new('cpu-a'))
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

::requires '../src/ManagementIntentionDiscovery.cls'
::requires '../vendor/generalized-compute/GeneralizedComputeIntentions.cls'
