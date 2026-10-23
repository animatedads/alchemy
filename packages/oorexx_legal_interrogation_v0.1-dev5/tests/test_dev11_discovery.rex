failures = 0

director = .LegalInterrogationDirector~new
port = .LegalInterrogationIntentionPort~new(director)
source = .directory~new
source["kind"] = "fixture-contract"
session = .LegalInterrogationSession~new("SESSION-A", "SRC-A", source, "CONTRACT", "fixture://contract")
clause = .LegalInterrogationClause~new("C12", source, "fixture://contract#12", "Customer shall not assign without consent.")
call assertTrue session~addClause(clause)~ok, "clause admitted"
call assertTrue director~seedClauseQuestions(clause)~ok, "questions seeded"

service = .FakeDev11IntentionService~new
binding = .LegalInterrogationIntentionServiceDev11Binding~new
r = binding~bind(service, port, session)
call assertTrue r~ok, "dev11 discovery provider bound"
call assertEqual "INTENTION_DEV11_DISCOVERY_BOUND", r~code, "binding result code"
call assertEqual 1, service~providers~items, "one discovery provider registered"

snapshots = service~refreshDiscovery
call assertEqual 1, snapshots~items, "one discovery snapshot"
snapshot1 = snapshots[1]
call assertTrue snapshot1~surfaceAdvertisements~items > 1, "mandatory and query surfaces advertised"
answerAd = findSurface(snapshot1, "ANSWER_EXPLAIN_CLAUSE")
call assertTrue answerAd \== .nil, "current answer intention advertised"
call assertEqual session, answerAd~subject~session, "exact session object retained"
call assertEqual session~revision, answerAd~subject~sessionRevision, "surface bound to current session revision"
call assertTrue answerAd~provider~current, "fresh surface is current"

notReady = answerAd~provider~executeReady(.FakeIntentionDecision~new("CONFIRM"), .nil, "PROPOSER")
call assertTrue \notReady~ok, "non-READY decision cannot execute"
call assertEqual "INTENTION_NOT_READY", notReady~code, "non-ready failure code"

answer = .LegalInterrogationAnswer~new("Assignment restriction.", "source wording", "ANSWERED", .array~new, "LLM_PROPOSER")
ready = .FakeIntentionDecision~new("READY")
r = answerAd~provider~executeReady(ready, answer, "LLM_PROPOSER")
call assertTrue r~ok, "READY surface executes structured payload"
call assertTrue session~revision > answerAd~subject~sessionRevision, "mutation advances authoring revision"
call assertTrue \answerAd~provider~current, "surface is stale after mutation"

stale = answerAd~provider~executeReady(ready, answer, "LLM_PROPOSER")
call assertTrue \stale~ok, "stale discovery cannot execute again"
call assertEqual "STALE_DISCOVERY", stale~code, "stale discovery failure is explicit"

snapshots = service~refreshDiscovery
snapshot2 = snapshots[1]
reviewAd = findSurface(snapshot2, "REVIEW_EXPLAIN_CLAUSE")
call assertTrue reviewAd \== .nil, "fresh discovery replaces answer with review intention"
call assertTrue reviewAd~subject~sessionRevision > answerAd~subject~sessionRevision, "new surface records later revision"
review = .LegalInterrogationAnswerReview~new("ACCEPT", "meaning supported", "LEGAL_REVIEWER", .array~new)
r = reviewAd~provider~executeReady(ready, review, "LEGAL_REVIEWER")
call assertTrue r~ok, "review executes through fresh READY surface"

/* Read-only explanation does not mutate the authoring revision. */
snapshots = service~refreshDiscovery
snapshot3 = snapshots[1]
explainAd = findSurface(snapshot3, "EXPLAIN_INTERROGATION_STATE")
call assertTrue explainAd \== .nil, "state explanation surface advertised"
beforeRevision = session~revision
r = explainAd~provider~executeReady(ready, .nil, "AUDITOR")
call assertTrue r~ok, "READY explanation executes"
call assertEqual beforeRevision, session~revision, "read-only explanation does not change authoring revision"
call assertTrue explainAd~provider~current, "read-only surface remains current"

bad = binding~bind(.FakeNoDiscoveryIntentionService~new, port, session)
call assertTrue \bad~ok, "older/non-discovery service fails closed"
call assertEqual "INTENTION_DEV11_DISCOVERY_UNAVAILABLE", bad~code, "missing discovery contract named"

if failures = 0 then do
  say "LEGAL INTERROGATION DEV11 DISCOVERY TESTS: PASS"
  exit 0
end
say "LEGAL INTERROGATION DEV11 DISCOVERY TESTS: FAIL" failures
exit 1

findSurface: procedure
  use arg snapshot, intentionName
  do ad over snapshot~surfaceAdvertisements
    if ad~subject~intentionName == intentionName then return ad
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

::requires "IntentionDev11Contract.cls"
::requires "LegalInterrogationIntentionServiceDev11.cls"
