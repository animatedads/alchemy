/* Contract tests for legal.interrogation/0.1 */
failures = 0

call assertTrue .LegalInterrogationResult~success(123)~ok, "result success"

source = .directory~new
source["kind"] = "CONTRACT_FIXTURE"
source["name"] = "assignment clause"
clauseText = "Customer shall not assign this Agreement without Supplier's prior written consent, except to an Affiliate."

session = .LegalInterrogationSession~new("S1", "fixture:assignment:1", source, "CONTRACT")
clause = .LegalInterrogationClause~new("C12", source, "clause 12", clauseText)
call assertTrue session~addClause(clause)~ok, "add clause"

director = .LegalInterrogationDirector~new
call assertTrue director~seedClauseQuestions(clause)~ok, "seed questions"
call assertEqual 12, clause~questions~items, "base question count"
call assertTrue \director~seedClauseQuestions(clause)~ok, "base interrogation cannot be seeded twice"
call assertEqual "INCOMPLETE", clause~closureState, "initial closure"

/* Answer and accept the base interrogatories. */
do q over clause~questions
  select
    when q~kind == "EXPLAIN_CLAUSE" then value = "Anti-assignment clause with consent requirement and Affiliate exception"
    when q~kind == "WHO_AFFECTED" then value = "Customer and Supplier"
    when q~kind == "CAPACITY" then value = "Customer as assigning party; Supplier as consent-giver"
    when q~kind == "CLASSIFY_EFFECT" then value = "PROHIBITION with conditional permission/exception"
    when q~kind == "TRIGGER" then value = "Customer proposes assignment"
    when q~kind == "CONDITIONS" then value = "Supplier has not given prior written consent"
    when q~kind == "EXCEPTIONS" then value = "Assignment to an Affiliate"
    when q~kind == "DEFINITIONS" then value = "Affiliate definition must be checked elsewhere"
    when q~kind == "DEPENDENCIES" then value = "Defined term Affiliate"
    when q~kind == "CONSEQUENCE_COMPLIANCE" then value = "Assignment may proceed if exception/consent route applies"
    when q~kind == "CONSEQUENCE_BREACH" then value = "Breach consequence must be established elsewhere"
    when q~kind == "UNCERTAINTY" then value = "No unresolved semantic uncertainty in this fixture"
    otherwise value = "answered"
  end
  ans = .LegalInterrogationAnswer~new(value, "fixture answer", "ANSWERED", .array~new, "TEST_REVIEWER")
  call assertTrue q~answerQuestion(ans)~ok, "answer " || q~kind
  call assertTrue q~accept~ok, "accept " || q~kind
end

pr = director~newProposition(clause, "If Customer assigns to a non-Affiliate without prior written Supplier consent, the assignment is prohibited by clause 12.", "NORMATIVE", "Customer", "ASSIGN", "Agreement", "PROHIBITION")
call assertTrue pr~ok, "new proposition"
p = pr~value
p~addCondition("no prior written Supplier consent")
p~addException("assignee is Affiliate")
p~addEvidence(.LegalInterrogationEvidenceLink~new("SOURCE_SPAN", source, "clause 12", clauseText))
call assertTrue p~resolve("SUPPORTED", "Directly supported by fixture language")~ok, "resolve proposition"
call assertEqual "INCOMPLETE", clause~closureState, "challenge required before closure"
call assertTrue director~challengeProposition(clause, p)~ok, "seed proposition challenge"
call assertTrue \director~challengeProposition(clause, p)~ok, "proposition challenge cannot be seeded twice"
do q over clause~questions
  if q~subjectRef == p~id, q~state == "OPEN" then do
    ans = .LegalInterrogationAnswer~new("Checked against clause text and captured exception", "fixture challenge", "ANSWERED", .array~new, "TEST_REVIEWER")
    call assertTrue q~answerQuestion(ans)~ok, "answer proposition challenge"
    call assertTrue q~accept~ok, "accept proposition challenge"
  end
end

/* Explicitly test the over-broad implication the user described. */
tr = director~newPropositionTest(clause, p, "IMPLICATION", "assignment(any party) -> supplier consent required")
call assertTrue tr~ok, "new proposition test"
t = tr~value
call assertTrue t~resolve("CONTRADICTED", "Affiliate assignment is an express exception")~ok, "resolve proposition test"
call assertEqual "ESTABLISHED", clause~closureState, "clause established despite a rejected over-broad test"

/* Document reconciliation is mandatory before handoff. */
call assertTrue director~seedDocumentReconciliation(session)~ok, "seed reconciliation"
call assertTrue \director~seedDocumentReconciliation(session)~ok, "reconciliation cannot be seeded twice"
call assertEqual "INCOMPLETE", session~closureState, "document incomplete pending reconciliation"
do q over session~crossClauseQuestions
  ans = .LegalInterrogationAnswer~new("Checked; no change in this single-clause fixture", "fixture reconciliation", "ANSWERED", .array~new, "TEST_REVIEWER")
  call assertTrue q~answerQuestion(ans)~ok, "answer reconciliation"
  call assertTrue q~accept~ok, "accept reconciliation"
end
call assertEqual "ESTABLISHED", session~closureState, "document established"
call assertTrue session~eligibleForCompilation, "eligible for compilation"

handoffResult = director~makeHandoff(session)
call assertTrue handoffResult~ok, "handoff ready"
handoff = handoffResult~value
call assertTrue \handoff~authoritative, "handoff is non-authoritative"
source["identity_probe"] = "still-the-original-object"
call assertEqual "still-the-original-object", handoff~sourceObject["identity_probe"], "source object retained rather than flattened"
adapter = .FakeCompileAdapter~new
emitResult = handoff~emitWith(adapter)
call assertTrue emitResult~ok, "host compile adapter called"
call assertEqual "fake-proposal:S1", emitResult~value, "adapter result returned"

/* Semantic ambiguity blocks compilation. */
source2 = .directory~new
source2["kind"] = "CONSTITUTION_FIXTURE"
source2["name"] = "Second Amendment text fixture"
text2 = "A well regulated Militia, being necessary to the security of a free State, the right of the people to keep and bear Arms, shall not be infringed."
s2 = .LegalInterrogationSession~new("S2", "fixture:constitutional:2a", source2, "CONSTITUTION")
c2 = .LegalInterrogationClause~new("A2", source2, "Amendment II", text2)
s2~addClause(c2)
d2 = .LegalInterrogationDirector~new
d2~seedClauseQuestions(c2)

do q over c2~questions
  disposition = "ANSWERED"
  value = "fixture answer"
  if q~kind == "UNCERTAINTY" then do
    disposition = "REQUIRES_LEGAL_REVIEW"
    value = "Relationship between prefatory militia proposition and operative right remains a legal interpretation question"
  end
  ans = .LegalInterrogationAnswer~new(value, "fixture answer", disposition, .array~new, "TEST_PROPOSER")
  q~answerQuestion(ans)
  if disposition == "ANSWERED" then q~accept
end
p2r = d2~newProposition(c2, "The prefatory militia proposition limits the operative right to active militia participation.", "INTERPRETIVE", "militia proposition", "LIMITS", "operative right", "")
p2 = p2r~value
p2~resolve("REQUIRES_LEGAL_REVIEW", "This is contested legal interpretation and cannot be admitted as source truth merely because a proposer asserted it")
d2~challengeProposition(c2, p2)
call assertEqual "REVIEW_REQUIRED", c2~closureState, "semantic review required"
call assertTrue \s2~eligibleForCompilation, "ambiguous session cannot compile"
call assertTrue \d2~makeHandoff(s2)~ok, "handoff blocked"

/* Dynamic intention provider should expose the next unresolved work, not a fixed catalogue. */
provider = .LegalInterrogationIntentionProvider~new
ints = provider~discover(s2)
call assertTrue ints~items > 0, "intentions discovered"
call assertEqual "REFER_LEGAL_REVIEW", ints[1]~name, "next intention follows live session state"

if failures = 0 then do
  say "LEGAL INTERROGATION TESTS: PASS"
  exit 0
end
say "LEGAL INTERROGATION TESTS: FAIL" failures
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

::class FakeCompileAdapter public
::method buildLegalCompileProposal
  use strict arg handoff
  return "fake-proposal:" || handoff~session~id

::requires "LegalInterrogation.cls"
