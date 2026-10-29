service = .IntentionService~new
examiner = .SemanticSourceCodeExaminer~new(.FakeAuthority~new)
installer = .SemanticSourceIntentionInstaller~new
provider = installer~install(service, examiner)
ignore = service~refreshDiscovery
call assert service~discoverySurfaces~items = 28, "all Examiner intentions dynamically advertised"

proposals = service~activeSurfaceProposals("find uses")
call assert proposals~items > 0, "find uses proposed from active semantic surface"
call assert proposals[1]~intentionId = "FIND_USES", "find uses intention identity"
call assert proposals[1]~slot("ACTION")~value = "CODE.FIND_USES", "find uses maps to semantic action"

proposals = service~activeSurfaceProposals("accept work")
call assert proposals~items > 0, "privileged work intention advertised"
call assert proposals[1]~slot("ACTION")~value = "WORK.ACCEPT", "accept maps to privileged action"

-- Dynamic discovery must replace stale surfaces rather than cache permanent truth.
cap = .ChangingCapabilitySource~new(examiner)
dynamic = .SemanticSourceIntentionDiscoveryProvider~new(cap)
service2 = .IntentionService~new
service2~registerDiscoveryProvider(dynamic)
ignore = service2~refreshDiscovery
fullCount = service2~discoverySurfaces~items
cap~limited = 1
ignore = service2~refreshDiscovery
call assert fullCount = 28, "full dynamic discovery count"
call assert service2~discoverySurfaces~items = 1, "fresh discovery replaces stale surfaces"
call assert service2~discoveryGeneration = 2, "discovery generation advances on capability change"

say "SEMANTIC SOURCE INTENTION SERVICE TEST: PASS"
exit 0

assert: procedure
  use arg condition, message
  if \condition then do
    say "ASSERT FAILED:" message
    exit 1
  end
  return

::class FakeAuthority

::class ChangingCapabilitySource
::method init
  use arg examiner
  self~examiner = examiner
  self~limited = 0
::attribute examiner
::attribute limited
::method discoverExaminerActions
  use arg context=.nil
  all = self~examiner~intentionDefinitions(context)
  if \self~limited then return all
  return .array~of(all[1])
::method discoveryRevision
  use arg context=.nil
  if self~limited then return "limited/2"
  return "full/1"

::requires "../src/SemanticSourceCodeExaminer.cls"
::requires "../src/SemanticSourceIntentionService.cls"
