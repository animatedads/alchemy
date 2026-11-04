/* Live contract test against the repository's actual Intention Service dev11. */
failures = 0

director = .LegalInterrogationDirector~new
port = .LegalInterrogationIntentionPort~new(director)
source = .directory~new
source["kind"] = "live-dev11-fixture"
session = .LegalInterrogationSession~new("SESSION-LIVE", "SRC-LIVE", source, "CONTRACT", "fixture://live-dev11")
clause = .LegalInterrogationClause~new("C-LIVE", source, "fixture://live-dev11#clause", "Customer shall not assign without consent.")
call assertTrue session~addClause(clause)~ok, "clause admitted"
call assertTrue director~seedClauseQuestions(clause)~ok, "questions seeded"

service = .IntentionService~new
call assertEqual "0.1-dev11", service~version, "real Intention Service version"
binding = .LegalInterrogationIntentionServiceDev11Binding~new
bound = binding~bind(service, port, session)
call assertTrue bound~ok, "adapter bound to real service"

firstGeneration = service~refreshDiscovery
call assertTrue firstGeneration > 0, "first discovery generation assigned"
call assertEqual 1, service~discoverySnapshots~items, "one legal snapshot"
call assertTrue service~discoverySurfaces~items > 1, "live service received legal surfaces"
answerAd = findSurface(service~discoverySurfaces, "ANSWER_EXPLAIN_CLAUSE")
call assertTrue answerAd \== .nil, "answer surface present in service surface set"
call assertEqual "ADVISORY", answerAd~authority, "advertisement is advisory"
call assertEqual "DISCOVERY", answerAd~lifetime, "advertisement lifetime is discovery"
call assertEqual firstGeneration, answerAd~discoveryGeneration, "service stamps its generation"

/* A refresh with no legal-state change must not manufacture a new generation. */
secondGeneration = service~refreshDiscovery
call assertEqual firstGeneration, secondGeneration, "unchanged legal state keeps discovery generation stable"
answerAd2 = findSurface(service~discoverySurfaces, "ANSWER_EXPLAIN_CLAUSE")
call assertTrue answerAd2 \== .nil, "answer surface survives stable refresh"
call assertEqual firstGeneration, answerAd2~discoveryGeneration, "stable refresh keeps advertisement generation"

ready = .IntentionDecision~ready("structured legal answer", .nil, .nil)
answer = .LegalInterrogationAnswer~new("Assignment restriction.", "source wording", "ANSWERED", .array~new, "LLM_PROPOSER")
oldRevision = session~revision
executed = answerAd2~provider~executeReady(ready, answer, "LLM_PROPOSER")
call assertTrue executed~ok, "READY surface executes through real dev11 advertisement"
call assertTrue session~revision > oldRevision, "legal mutation advances session revision"
call assertTrue \answerAd2~provider~current, "pre-mutation surface becomes stale"

thirdGeneration = service~refreshDiscovery
call assertTrue thirdGeneration > secondGeneration, "legal mutation advances service discovery generation"
call assertEqual thirdGeneration, service~discoverySurfaces[1]~discoveryGeneration, "refreshed surfaces carry new service generation"
reviewAd = findSurface(service~discoverySurfaces, "REVIEW_EXPLAIN_CLAUSE")
call assertTrue reviewAd \== .nil, "review replaces answer after mutation"

if failures = 0 then do
  say "LEGAL INTERROGATION LIVE INTENTION SERVICE DEV11 TESTS: PASS"
  exit 0
end
say "LEGAL INTERROGATION LIVE INTENTION SERVICE DEV11 TESTS: FAIL" failures
exit 1

findSurface: procedure
  use arg advertisements, intentionName
  do ad over advertisements
    subject = ad~sourceObject
    if subject \== .nil then if subject~hasMethod("INTENTIONNAME") then if subject~intentionName == intentionName then return ad
  end
  return .nil

assertTrue: procedure expose failures
  use arg condition, label
  if condition then return
  failures = failures + 1
  say "FAIL:" label
  return

assertEqual: procedure expose failures
  use arg expected, actual, label
  if expected == actual then return
  failures = failures + 1
  say "FAIL:" label "expected="expected "actual="actual
  return

::requires "IntentionService.cls"
::requires "LegalInterrogationIntentionServiceDev11.cls"
