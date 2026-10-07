/* Prove Management Intention Discovery only discovers/routes surfaces. */
provider = .CountingProvider~new
assessor = .CountingAssessor~new
source = .ManagementIntentionSurfaceSource~new('counting', provider, assessor)
directory = .ManagementIntentionDirectory~new
directory~registerSource(source)

context = .directory~new
resolution = directory~resolve('inspect thing', context)
if provider~discoveries \== 1 then call fail 'provider discovery count'
if assessor~assessments \== 1 then call fail 'relevance assessment count'
if provider~mutations \== 0 then call fail 'management discovery caused mutation'
if resolution~relevantCandidates~items \== 1 then call fail 'expected one relevant surface'
if resolution~relevantSurfaces[1] \== provider~lastSurface then call fail 'surface identity flattened or copied'

say 'PASS test_non_authority_contract'
exit 0

fail: procedure
  use arg message
  say 'FAIL:' message
  exit 1
return

::class CountingProvider
::method init
  self~discoveries = 0
  self~mutations = 0
  self~lastSurface = .nil
::attribute discoveries
::attribute mutations
::attribute lastSurface
::method discover
  use arg context=.nil
  self~discoveries += 1
  surface = .directory~new
  surface['provider'] = 'counting/0.1'
  surface['token'] = .Object~new
  self~lastSurface = surface
  return surface

::class CountingAssessor subclass ManagementRelevanceAssessor
::method init
  self~assessments = 0
::attribute assessments
::method assess
  use arg request, surface, context=.nil
  self~assessments += 1
  return .ManagementRelevanceAssessment~new(.true, 50, 'counting', 'TEST', surface)

::requires '../src/ManagementIntentionDiscovery.cls'
