/* dev3 document intake, revision, stale-handoff and supersession qualification. */
failures = 0

source = .directory~new
source["kind"] = "CONTRACT_DOCUMENT_FIXTURE"
source["name"] = "assignment agreement"
sourceEvidence = .array~new
publisherEvidence = .directory~new
publisherEvidence["kind"] = "FIXTURE_SOURCE_EVIDENCE"
sourceEvidence~append(publisherEvidence)

request = .LegalInterrogationDocumentRequest~new("DOC1", "fixture:document:1", source, "CONTRACT", "agreement.pdf", sourceEvidence)
docPort = .LegalInterrogationDocumentPort~new
r = docPort~begin(request)
call assertTrue r~ok, "document admitted"
session = r~value
call assertEqual "agreement.pdf", session~sourceLocator, "source locator retained"
source["identity_probe"] = "whole-object-retained"
call assertEqual "whole-object-retained", session~sourceObject["identity_probe"], "original source object retained"
call assertEqual publisherEvidence, session~sourceEvidence[1], "source evidence object retained"

port = .LegalInterrogationIntentionPort~new
adapter = .FakeClauseSourceAdapter~new(source)
r = docPort~ingestClauses(session, adapter, port, "SOURCE_ADAPTER")
call assertTrue r~ok, "document clauses admitted through intention path"
call assertEqual 1, session~clauses~items, "one clause ingested"
call assertTrue session~revision > 0, "ingestion advances authoring revision"
clause = session~clauses[1]

/* Complete base interrogation. */
intention = drainQuestions(port, session)
call assertEqual "PROPOSE_LEGAL_PROPOSITION", intention~name, "base interrogation leads to proposition"

draft = .LegalInterrogationPropositionDraft~new("If Customer assigns to a non-Affiliate without prior written Supplier consent, clause 12 prohibits the assignment.", "NORMATIVE", "Customer", "ASSIGN", "Agreement", "PROHIBITION")
draft~addCondition("no prior written Supplier consent")
draft~addException("assignee is Affiliate")
draft~addEvidence(.LegalInterrogationEvidenceLink~new("SOURCE_SPAN", source, "clause 12", clause~exactText))
r = port~execute(session, intention, draft, "LLM_PROPOSER")
call assertTrue r~ok, "first proposition proposed"
p1 = r~value

r = port~discover(session)
call assertEqual "CHALLENGE_PROPOSITION", r~value~intentions[1]~name, "first proposition challenged"
call assertTrue port~execute(session, r~value~intentions[1], .nil, "INTERROGATOR")~ok, "challenge seeded"
intention = drainQuestions(port, session)
call assertEqual "RESOLVE_PROPOSITION", intention~name, "challenge leads to resolution"
call assertTrue port~execute(session, intention, .LegalInterrogationPropositionResolution~new("SUPPORTED", "source-supported"), "LEGAL_REVIEWER")~ok, "first proposition resolved"

testDraft = .LegalInterrogationTestDraft~new(p1~id, "IMPLICATION", "assignment(any party) -> supplier consent required")
r = port~execute(session, "TEST_LEGAL_PROPOSITION", testDraft, "LEGAL_REVIEWER", p1~id)
call assertTrue r~ok, "first proposition test created"
t1 = r~value
r = port~discover(session)
call assertEqual "RESOLVE_PROPOSITION_TEST", r~value~intentions[1]~name, "test resolution discovered"
call assertTrue port~execute(session, r~value~intentions[1], .LegalInterrogationTestResolution~new("CONTRADICTED", "Affiliate exception"), "LEGAL_REVIEWER")~ok, "over-broad test rejected"

r = port~discover(session)
call assertEqual "START_DOCUMENT_RECONCILIATION", r~value~intentions[1]~name, "reconciliation required"
call assertTrue port~execute(session, r~value~intentions[1], .nil, "INTERROGATOR")~ok, "reconciliation seeded"
intention = drainQuestions(port, session)
call assertEqual "HANDOFF_LEGAL_COMPILATION", intention~name, "closed document can hand off"
r = port~execute(session, intention, .nil, "COMPILATION_COORDINATOR")
call assertTrue r~ok, "first handoff created"
h1 = r~value
rev1 = h1~handoffRevision
call assertTrue \h1~stale, "fresh handoff is not stale"
call assertEqual 1, h1~clauses[1]~propositions~items, "handoff contains one active proposition"
call assertEqual 0, h1~clauses[1]~supersededPropositions~items, "no superseded proposition yet"
call assertEqual source, h1~sourceObject, "handoff retains original source object"

/* Reopen an accepted meaning answer. This must invalidate all downstream semantics and h1. */
qExplain = findQuestionByKind(clause, "EXPLAIN_CLAUSE")
call assertTrue qExplain \== .nil, "explain question found"
r = port~execute(session, "REOPEN_QUESTION", "Reviewer found an omitted qualification", "LEGAL_REVIEWER", qExplain~id)
call assertTrue r~ok, "accepted answer reopened"
call assertTrue session~revision > rev1, "reopen advances revision"
call assertEqual "STALE", p1~state, "derived proposition invalidated"
call assertEqual "STALE", t1~result, "derived proposition test invalidated"
call assertTrue h1~stale, "old handoff becomes stale"
call assertTrue \h1~emitWith(.FakeCompileAdapter~new)~ok, "stale handoff cannot emit compile proposal"
call assertEqual "STALE_HANDOFF", h1~emitWith(.FakeCompileAdapter~new)~code, "stale handoff failure is explicit"

/* Re-establish the reopened answer and all derived semantics. */
r = port~discover(session)
call assertEqual "ANSWER_EXPLAIN_CLAUSE", r~value~intentions[1]~name, "reopened question rediscovered"
a = .LegalInterrogationAnswer~new("Restriction on assignment subject to consent and Affiliate exception.", "revised meaning", "ANSWERED", .array~new, "LLM_PROPOSER")
call assertTrue port~execute(session, r~value~intentions[1], a, "LLM_PROPOSER")~ok, "reopened answer proposed"
r = port~discover(session)
call assertEqual "REVIEW_EXPLAIN_CLAUSE", r~value~intentions[1]~name, "reopened answer reviewed"
call assertTrue port~execute(session, r~value~intentions[1], .LegalInterrogationAnswerReview~new("ACCEPT", "qualification captured", "LEGAL_REVIEWER"), "LEGAL_REVIEWER")~ok, "reopened answer accepted"

r = port~discover(session)
call assertEqual "CHALLENGE_PROPOSITION", r~value~intentions[1]~name, "invalidated proposition must be challenged again"
call assertTrue port~execute(session, r~value~intentions[1], .nil, "INTERROGATOR")~ok, "re-challenge seeded"
intention = drainQuestions(port, session)
call assertEqual "RESOLVE_PROPOSITION", intention~name, "re-challenge returns to proposition resolution"
call assertTrue port~execute(session, intention, .LegalInterrogationPropositionResolution~new("SUPPORTED", "re-established after reopened answer"), "LEGAL_REVIEWER")~ok, "proposition re-established"
r = port~discover(session)
call assertEqual "RESOLVE_PROPOSITION_TEST", r~value~intentions[1]~name, "stale proposition test must be rerun"
call assertTrue port~execute(session, r~value~intentions[1], .LegalInterrogationTestResolution~new("CONTRADICTED", "Affiliate exception still controls"), "LEGAL_REVIEWER")~ok, "stale test re-established"
r = port~discover(session)
call assertEqual "HANDOFF_LEGAL_COMPILATION", r~value~intentions[1]~name, "document returns to handoff state"
r = port~execute(session, r~value~intentions[1], .nil, "COMPILATION_COORDINATOR")
call assertTrue r~ok, "second handoff created"
h2 = r~value
call assertTrue h2~handoffRevision > h1~handoffRevision, "new handoff has later revision"

/* Create a replacement proposition and then explicitly supersede p1. */
draft2 = .LegalInterrogationPropositionDraft~new("Customer assignment requires prior written Supplier consent unless the assignee is an Affiliate.", "NORMATIVE", "Customer", "ASSIGN", "Agreement", "PROHIBITION")
draft2~addCondition("assignee is not Affiliate")
draft2~addCondition("no prior written Supplier consent")
r = port~execute(session, "PROPOSE_LEGAL_PROPOSITION", draft2, "LEGAL_REVIEWER", clause~id)
call assertTrue r~ok, "replacement proposition proposed"
p2 = r~value
call assertTrue h2~stale, "new proposition invalidates prior handoff revision"
r = port~execute(session, "CHALLENGE_PROPOSITION", .nil, "INTERROGATOR", p2~id)
call assertTrue r~ok, "replacement challenge seeded"
intention = drainQuestions(port, session)
call assertEqual "RESOLVE_PROPOSITION", intention~name, "replacement proposition reaches resolution"
call assertEqual p2~id, intention~subjectRef, "replacement proposition is resolution target"
call assertTrue port~execute(session, intention, .LegalInterrogationPropositionResolution~new("SUPPORTED", "replacement captures exception in condition"), "LEGAL_REVIEWER")~ok, "replacement proposition resolved"

sup = .LegalInterrogationSupersessionRequest~new(p2~id, "P2 replaces the earlier wording after review")
r = port~execute(session, "SUPERSEDE_LEGAL_PROPOSITION", sup, "LEGAL_REVIEWER", p1~id)
call assertTrue r~ok, "old proposition superseded"
call assertEqual "SUPERSEDED", p1~state, "old proposition marked superseded"
call assertEqual p2~id, p1~supersededBy, "supersession relationship retained"
call assertTrue t1~superseded, "tests attached to superseded proposition retained but retired"
call assertEqual p2~id, t1~supersededByPropositionId, "retired test points at replacement proposition"
call assertTrue \port~director~newPropositionTest(clause, p1, "IMPLICATION", "retired proposition probe")~ok, "cannot create new test against superseded proposition"
call assertTrue \clause~supersedeProposition(p2~id, p2~id, "invalid")~ok, "self-supersession rejected"

r = port~discover(session)
call assertEqual "HANDOFF_LEGAL_COMPILATION", r~value~intentions[1]~name, "supersession leaves one established active proposition"
r = port~execute(session, r~value~intentions[1], .nil, "COMPILATION_COORDINATOR")
call assertTrue r~ok, "post-supersession handoff created"
h3 = r~value
call assertEqual 1, h3~clauses[1]~propositions~items, "compile snapshot contains only active proposition"
call assertEqual p2~id, h3~clauses[1]~propositions[1]~id, "replacement proposition is compile candidate"
call assertEqual 1, h3~clauses[1]~supersededPropositions~items, "superseded proposition retained separately for audit"
call assertEqual p1~id, h3~clauses[1]~supersededPropositions[1]~id, "superseded proposition identity retained"
call assertTrue h3~emitWith(.FakeCompileAdapter~new)~ok, "fresh post-supersession handoff emits"

last = session~negotiationHistory[session~negotiationHistory~items]
call assertEqual session~revision, last~afterRevision, "negotiation record captures resulting revision"

if failures = 0 then do
  say "LEGAL INTERROGATION LIFECYCLE TESTS: PASS"
  exit 0
end
say "LEGAL INTERROGATION LIFECYCLE TESTS: FAIL" failures
exit 1

drainQuestions: procedure
  use arg port, session
  do forever
    d = port~discover(session)
    i = d~value~intentions[1]
    n = i~name
    if n~left(7) == "ANSWER_" then do
      a = .LegalInterrogationAnswer~new("source-supported fixture answer for " || n, "fixture", "ANSWERED", .array~new, "LLM_PROPOSER")
      port~execute(session, i, a, "LLM_PROPOSER")
      iterate
    end
    if n~left(7) == "REVIEW_" then do
      rv = .LegalInterrogationAnswerReview~new("ACCEPT", "fixture review", "LEGAL_REVIEWER")
      port~execute(session, i, rv, "LEGAL_REVIEWER")
      iterate
    end
    return i
  end

findQuestionByKind: procedure
  use arg clause, kind
  do q over clause~questions
    if q~kind == kind then return q
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

::class FakeClauseSourceAdapter public
::attribute source
::method init
  use strict arg source
  self~source = source
::method extractLegalInterrogationClauses
  use strict arg sourceObject, sourceIdentity, sourceLocator
  a = .array~new
  text = "Customer shall not assign this Agreement without Supplier's prior written consent, except to an Affiliate."
  a~append(.LegalInterrogationClause~new("C12", sourceObject, sourceLocator || "#clause-12", text))
  return a

::class FakeCompileAdapter public
::method buildLegalCompileProposal
  use strict arg handoff
  d = .directory~new
  d["sessionId"] = handoff~sessionId
  d["revision"] = handoff~handoffRevision
  d["activePropositions"] = handoff~clauses[1]~propositions~items
  return d

::requires "LegalInterrogationDocumentPort.cls"
