MICRO = 1000000
path = "/tmp/wlu_route_decision_policy_test.log"
ignore = RxFuncAdd("SysFileDelete", "rxunixsys", "SysFileDelete")
ignore = SysFileDelete(path)

keys = .WLUFastMacKeyRing~new
keys~addKey("route-decision", "000102030405060708090a0b0c0d0e0f")
journal = .WLUJobRouteFileJournal~new(path, keys)

/* Two evidence-eligible candidates. Grok has the stronger conservative
 * evidence and should therefore be the advisory recommendation. */
call appendStage journal, keys, "GEMMA", "G", 6, 5, 1, 4 * MICRO
call appendStage journal, keys, "GROK", "R", 6, 6, 0, 5 * MICRO

advisor = .WLUJobRouteAdvisor~new(keys)
snapshotResult = advisor~analytics~verifiedSnapshot(journal)
call assertTrue snapshotResult~ok, "verified snapshot"
snapshot = snapshotResult~value
advisoryPolicy = .WLURouteAdvisoryPolicy~new(5, 4000, 6000, 0)
stages = .array~of( -
  .WLUJobStage~new("GEMMA", "SHANNON:GEMMA", 4 * MICRO, 6 * MICRO), -
  .WLUJobStage~new("GROK", "SHANNON:GROK", 5 * MICRO, 7 * MICRO) )
adviceResult = advisor~advise(snapshot, stages, advisoryPolicy)
call assertTrue adviceResult~ok, "advisory succeeds"
advice = adviceResult~value
call assertTrue advice~verify(keys), "advisory authenticated"
call assertEq "GROK", advice~recommendedStageId, "Grok recommendation"
call assertTrue advice~assessmentFor("GEMMA")~decisionEligible, "Gemma remains evidence eligible"

/* Build two reviewed institutional releases. v1 is operative now; v2 is a
 * future policy which disables automated route decisions and is used only as
 * an explicit counterfactual at the historical action time. */
now = .DateTime~new
cut = now + .TimeSpan~new(0,0,30,0,0)
rules1 = .WLURouteDecisionRules~new("RECOMMENDED_ONLY", "EVIDENCE_ELIGIBLE")~seal
rules2 = .WLURouteDecisionRules~new("DENY", "EVIDENCE_ELIGIBLE")~seal
release1 = .InstitutionalPolicyRelease~new("WLU-ROUTE-SELECTION", "1.0", now - .TimeSpan~new(0,1,0,0,0), cut, "SCHEDULER_ENGINEERING", "OPERATIONS_BOARD", "", rules1)~seal
release2 = .InstitutionalPolicyRelease~new("WLU-ROUTE-SELECTION", "2.0", cut, .nil, "SCHEDULER_ENGINEERING", "OPERATIONS_BOARD", "1.0", rules2)~seal

catalog = .InstitutionalPolicyCatalog~new
call assertTrue catalog~publish(release1)~ok, "publish operative decision policy"
call assertTrue catalog~publish(release2)~ok, "publish successor decision policy"

gate = .WLUJobRouteDecisionGate~new(keys)

/* Establish unrelated WLU authority state. Policy evaluation must not move it. */
clock = .WLUTestTimeSource~new(1000000)
authority = .WLUAuthority~new(keys, .WLUMemoryLedger~new, clock)
account = .WLUAccount~new("acct-policy", 100 * MICRO)
authority~addAccount(account)

permittedResult = gate~decide(catalog, "WLU-ROUTE-SELECTION", advice, "GROK", now, "AUTOMATED")
call assertTrue permittedResult~ok, "operative decision evaluated"
permitted = permittedResult~value
call assertTrue permitted~allowed, "recommended route permitted"
call assertEq .WLURouteDecisionStatus~PERMITTED, permitted~status, "permitted status"
call assertEq "RECOMMENDED_STAGE_PERMITTED", permitted~reasonCode, "recommended-only reason"
call assertEq "1.0", permitted~policyVersion, "operative policy version pinned"
call assertEq .InstitutionalPolicyBuild~MODE_OPERATIVE, permitted~evaluationMode, "operative mode labelled"
call assertEq release1~semanticIdentity, permitted~policyIdentity, "exact policy semantic identity pinned"
call assertTrue permitted~publicationRecord \== .nil, "publication evidence retained"
call assertEq release1~semanticIdentity, permitted~publicationRecord~policyIdentity, "publication record binds same release"
call assertTrue permitted~policyRelease == release1, "rich operative policy release retained"
call assertTrue permitted~verify(keys), "decision evidence authenticated"
call assertEq advice~sourceSequence, permitted~advisorySourceSequence, "advisory evidence sequence retained"
call assertEq advice~sourceTag, permitted~advisorySourceTag, "advisory evidence tag retained"

rejectedResult = gate~decide(catalog, "WLU-ROUTE-SELECTION", advice, "GEMMA", now, "AUTOMATED")
call assertTrue rejectedResult~ok, "non-recommended route still yields decision evidence"
rejected = rejectedResult~value
call assertTrue \rejected~allowed, "automated non-recommended route rejected"
call assertEq "PROPOSED_STAGE_NOT_RECOMMENDED", rejected~reasonCode, "explicit rejection reason"

operatorResult = gate~decide(catalog, "WLU-ROUTE-SELECTION", advice, "GEMMA", now, "OPERATOR")
call assertTrue operatorResult~ok, "operator policy evaluated"
call assertTrue operatorResult~value~allowed, "operator may choose another evidence-eligible candidate under published policy"
call assertEq "EVIDENCE_ELIGIBLE_PERMITTED", operatorResult~value~reasonCode, "operator rule explicit"

/* An advisory object changed after proof issuance must not become policy input. */
forged = .WLURouteAdvisoryResult~new(advice~status, "GEMMA", advice~assessmentFor("GEMMA"), advice~assessments, advice~sourceSequence, advice~sourceTag, advice~policy, advice~proof)
call assertTrue \forged~verify(keys), "changed advisory invalidates proof"
forgedDecision = gate~decide(catalog, "WLU-ROUTE-SELECTION", forged, "GEMMA", now, "AUTOMATED")
call assertTrue \forgedDecision~ok, "policy gate rejects forged advisory"
call assertEq "WLU_ROUTE_DECISION_ADVISORY_PROOF_INVALID", forgedDecision~code, "forged advisory rejection code"

/* Explicit counterfactual uses the future fixed policy without pretending it
 * was operative at the historical action time. */
counterResult = gate~counterfactual(release2, advice, "GROK", now, "AUTOMATED")
call assertTrue counterResult~ok, "counterfactual policy evaluation succeeds"
counter = counterResult~value
call assertTrue \counter~allowed, "future policy would deny automated choice"
call assertEq .InstitutionalPolicyBuild~MODE_COUNTERFACTUAL, counter~evaluationMode, "counterfactual labelled"
call assertEq "2.0", counter~policyVersion, "counterfactual policy version pinned"
call assertTrue counter~publicationRecord == .nil, "counterfactual does not fabricate operative publication evidence"
call assertTrue counter~verify(keys), "counterfactual evidence authenticated"
comparison = gate~compare(permitted, counter)
call assertTrue comparison~outcomeChanged, "policy change alters business outcome"
call assertTrue comparison~traceChanged, "policy trace identity changes"

/* Decision policy is evidence/governance only. */
call assertEq 0, account~reservedMicroWlu, "policy decision reserves zero WLU"
call assertEq 0, account~spentMicroWlu, "policy decision spends zero WLU"

say "PASS test_route_decision_policy"
call SysFileDelete path
exit 0

appendStage: procedure
  use strict arg journal, keys, stageId, prefix, sampleCount, successCount, overCount, baseActual
  do i = 1 to sampleCount
    jobId = prefix || "-" || i
    if i <= successCount then outcome = "SUCCESS"
    else outcome = "PROVIDER_FAILURE"
    actual = baseActual
    expected = baseActual
    if i <= overCount then actual += 1000000
    e = .WLUJobRouteEvidence~new(jobId, 1, i, .WLUJobRouteEventType~STAGE_SETTLED, stageId, "", "r-" || jobId, actual, 0, .true, expected, expected + 2000000, 1, "WITHIN_BUDGET", "", outcome, "outcome:" || jobId, "ai-common", "2026-08")
    e = e~withProof(keys~sign(e~canonicalText))
    appendResult = journal~appendEvent(e)
    if \appendResult~ok then raise syntax 88.900 array("route decision fixture append failed: " || appendResult~code)
  end
  return

assertEq: procedure
  use arg expected, actual, label
  if expected \== actual then do
    say "FAIL" label "expected="expected "actual="actual
    exit 1
  end
  return
assertTrue: procedure
  use arg condition, label
  if \condition then do
    say "FAIL" label
    exit 1
  end
  return

::requires "WLURouteDecisionPolicy.cls"
