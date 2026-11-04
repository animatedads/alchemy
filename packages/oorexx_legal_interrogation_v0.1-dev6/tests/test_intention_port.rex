/* Dynamic Intention -> Legal Interrogation qualification. */
failures = 0

source = .directory~new
source["kind"] = "CONTRACT_FIXTURE"
source["name"] = "assignment agreement"
session = .LegalInterrogationSession~new("NEG1", "fixture:negotiation:1", source, "CONTRACT")
port = .LegalInterrogationIntentionPort~new

r = port~discover(session)
call assertTrue r~ok, "initial discover"
surface = r~value
call assertEqual "INGEST_CLAUSE", surface~intentions[1]~name, "empty session asks to ingest clause"
generation1 = surface~generation

clauseText = "Customer shall not assign this Agreement without Supplier's prior written consent, except to an Affiliate."
clause = .LegalInterrogationClause~new("C12", source, "clause 12", clauseText)
r = port~execute(session, surface~intentions[1], clause, "SOURCE_INGESTOR")
call assertTrue r~ok, "ingest through intention port"
call assertEqual 12, clause~questions~items, "ingest seeds interrogation"

r = port~discover(session)
call assertTrue r~value~generation > generation1, "discovery is refreshed"
answerIntention = r~value~intentions[1]
call assertEqual "ANSWER_EXPLAIN_CLAUSE", answerIntention~name, "first clause question"
answer1 = .LegalInterrogationAnswer~new("This forbids assignment.", "first LLM proposal", "ANSWERED", .array~new, "LLM_PROPOSER")
call assertTrue port~execute(session, answerIntention, answer1, "LLM_PROPOSER")~ok, "record proposed answer"

r = port~discover(session)
reviewIntention = r~value~intentions[1]
call assertEqual "REVIEW_EXPLAIN_CLAUSE", reviewIntention~name, "answer requires review"
review1 = .LegalInterrogationAnswerReview~new("REVISE", "Too broad: Affiliate exception omitted", "LEGAL_REVIEWER")
call assertTrue port~execute(session, reviewIntention, review1, "LEGAL_REVIEWER")~ok, "review can return answer for revision"

r = port~discover(session)
call assertEqual "ANSWER_EXPLAIN_CLAUSE", r~value~intentions[1]~name, "revision returns to answer intention"
answer2 = .LegalInterrogationAnswer~new("This restricts assignment without prior written consent, subject to the Affiliate exception.", "revised answer", "ANSWERED", .array~new, "LLM_PROPOSER")
call assertTrue port~execute(session, r~value~intentions[1], answer2, "LLM_PROPOSER")~ok, "revised answer recorded"
r = port~discover(session)
call assertEqual "REVIEW_EXPLAIN_CLAUSE", r~value~intentions[1]~name, "revised answer reviewed"
call assertTrue port~execute(session, r~value~intentions[1], .LegalInterrogationAnswerReview~new("ACCEPT", "Now captures the exception", "LEGAL_REVIEWER"), "LEGAL_REVIEWER")~ok, "revised answer accepted"
call assertEqual 2, clause~questionById(answerIntention~subjectRef)~answerHistory~items, "answer history retained"
call assertEqual 2, clause~questionById(answerIntention~subjectRef)~reviewHistory~items, "review history retained"

do forever
  r = port~discover(session)
  intention = r~value~intentions[1]
  name = intention~name
  if name~left(7) == "ANSWER_" then do
    value = "fixture answer for " || name
    if name == "ANSWER_UNCERTAINTY" then value = "No unresolved semantic uncertainty in this fixture"
    a = .LegalInterrogationAnswer~new(value, "fixture", "ANSWERED", .array~new, "LLM_PROPOSER")
    call assertTrue port~execute(session, intention, a, "LLM_PROPOSER")~ok, "answer dynamic question"
    iterate
  end
  if name~left(7) == "REVIEW_" then do
    review = .LegalInterrogationAnswerReview~new("ACCEPT", "fixture review", "LEGAL_REVIEWER")
    call assertTrue port~execute(session, intention, review, "LEGAL_REVIEWER")~ok, "review dynamic answer"
    iterate
  end
  leave
end
call assertEqual "PROPOSE_LEGAL_PROPOSITION", name, "proposition requested after clause questions"

draft = .LegalInterrogationPropositionDraft~new("If Customer assigns to a non-Affiliate without prior written Supplier consent, clause 12 prohibits the assignment.", "NORMATIVE", "Customer", "ASSIGN", "Agreement", "PROHIBITION")
draft~addCondition("no prior written Supplier consent")
draft~addException("assignee is Affiliate")
draft~addEvidence(.LegalInterrogationEvidenceLink~new("SOURCE_SPAN", source, "clause 12", clauseText))
r = port~execute(session, intention, draft, "LLM_PROPOSER")
call assertTrue r~ok, "proposition proposed through intention port"
p = r~value

r = port~discover(session)
call assertEqual "CHALLENGE_PROPOSITION", r~value~intentions[1]~name, "proposition is challenged before resolution"
call assertTrue port~execute(session, r~value~intentions[1], .nil, "INTERROGATOR")~ok, "seed proposition challenge"

do forever
  r = port~discover(session)
  intention = r~value~intentions[1]
  name = intention~name
  if name~left(7) == "ANSWER_" then do
    a = .LegalInterrogationAnswer~new("Checked against exact clause text", "challenge answer", "ANSWERED", .array~new, "LLM_PROPOSER")
    call assertTrue port~execute(session, intention, a, "LLM_PROPOSER")~ok, "answer challenge"
    iterate
  end
  if name~left(7) == "REVIEW_" then do
    call assertTrue port~execute(session, intention, .LegalInterrogationAnswerReview~new("ACCEPT", "source-supported", "LEGAL_REVIEWER"), "LEGAL_REVIEWER")~ok, "review challenge"
    iterate
  end
  leave
end
call assertEqual "RESOLVE_PROPOSITION", name, "resolution follows cross-examination"
resolution = .LegalInterrogationPropositionResolution~new("SUPPORTED", "Direct source language plus captured Affiliate exception")
call assertTrue port~execute(session, intention, resolution, "LEGAL_REVIEWER")~ok, "resolve proposition"

testDraft = .LegalInterrogationTestDraft~new(p~id, "IMPLICATION", "assignment(any party) -> supplier consent required")
r = port~execute(session, "TEST_LEGAL_PROPOSITION", testDraft, "LEGAL_REVIEWER", p~id)
call assertTrue r~ok, "explicit proposition test created"
t = r~value
r = port~discover(session)
call assertEqual "RESOLVE_PROPOSITION_TEST", r~value~intentions[1]~name, "unresolved test becomes next intention"
testResolution = .LegalInterrogationTestResolution~new("CONTRADICTED", "Affiliate assignments are expressly excepted")
call assertTrue port~execute(session, r~value~intentions[1], testResolution, "LEGAL_REVIEWER")~ok, "proposition test resolved"
call assertEqual "CONTRADICTED", t~result, "over-broad implication rejected"

r = port~discover(session)
call assertEqual "START_DOCUMENT_RECONCILIATION", r~value~intentions[1]~name, "reconciliation requested"
call assertTrue port~execute(session, r~value~intentions[1], .nil, "INTERROGATOR")~ok, "seed reconciliation"

do forever
  r = port~discover(session)
  intention = r~value~intentions[1]
  name = intention~name
  if name~left(7) == "ANSWER_" then do
    a = .LegalInterrogationAnswer~new("No cross-clause alteration in single-clause fixture", "reconciliation", "ANSWERED", .array~new, "LLM_PROPOSER")
    call assertTrue port~execute(session, intention, a, "LLM_PROPOSER")~ok, "answer reconciliation"
    iterate
  end
  if name~left(7) == "REVIEW_" then do
    call assertTrue port~execute(session, intention, .LegalInterrogationAnswerReview~new("ACCEPT", "reconciled", "LEGAL_REVIEWER"), "LEGAL_REVIEWER")~ok, "review reconciliation"
    iterate
  end
  leave
end
call assertEqual "HANDOFF_LEGAL_COMPILATION", name, "only closed document is handed off"
r = port~execute(session, intention, .nil, "COMPILATION_COORDINATOR")
call assertTrue r~ok, "compile handoff produced"
call assertTrue \r~value~authoritative, "handoff remains non-authoritative"
call assertTrue session~negotiationHistory~items > 20, "negotiation history retained"

binding = .LegalInterrogationIntentionBinding~new
bindAdapter = .FakeIntentionRegistrationAdapter~new
call assertTrue binding~bind(.directory~new, port, bindAdapter)~ok, "host intention binding seam"
call assertEqual port~id, bindAdapter~registeredId, "actual port passed to host adapter"

action = .directory~new; action["operation"] = "ASSIGN"
context = .directory~new; context["jurisdiction"] = "FIXTURE"
request = .LegalEffectTestRequest~new("APPLIES", r~value, action, context, .nil, .array~new)
effectPort = .LegalEffectTestPort~new
call assertEqual 14, effectPort~supportedTests~items, "legal effect test interface inventory"
effectAdapter = .FakeLegalEffectAdapter~new
effectResult = effectPort~evaluate(request, effectAdapter)
call assertTrue effectResult~ok, "legal effect test adapter invoked"
call assertEqual "ASSIGN", effectResult~value["operation"], "full action object carried through test port"
action["probe"] = "object-retained"
call assertEqual "object-retained", request~actionObject["probe"], "test request retains Rexx object rather than flattening it"

badAnswer = .LegalInterrogationAnswer~new("x", "", "MAGIC", .array~new, "BAD")
qProbe = .LegalInterrogationQuestion~new("QBAD", "PROBE", "TEST", "probe")
call assertTrue \qProbe~answerQuestion(badAnswer)~ok, "unknown answer disposition rejected"

badEffectRequest = .LegalEffectTestRequest~new("INVENTED_TEST", r~value, action, context)
call assertTrue \effectPort~evaluate(badEffectRequest, effectAdapter)~ok, "unknown legal-effect test rejected"

if failures = 0 then do
  say "LEGAL INTERROGATION INTENTION PORT TESTS: PASS"
  exit 0
end
say "LEGAL INTERROGATION INTENTION PORT TESTS: FAIL" failures
exit 1

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

::class FakeIntentionRegistrationAdapter public
::attribute registeredId
::method registerLegalInterrogationProvider
  use strict arg service, port
  self~registeredId = port~id
  return port

::class FakeLegalEffectAdapter public
::method evaluateLegalEffectTest
  use strict arg request
  return request~actionObject

::requires "LegalInterrogationIntentionPort.cls"
