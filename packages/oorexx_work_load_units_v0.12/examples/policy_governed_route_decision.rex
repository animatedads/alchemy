/* Policy-governed use of authenticated route advice.
 * The decision gate returns evidence only; admission remains a separate step. */
MICRO = 1000000
path = "/tmp/wlu_policy_governed_route_demo.log"
ignore = RxFuncAdd("SysFileDelete", "rxunixsys", "SysFileDelete")
ignore = SysFileDelete(path)

keys = .WLUFastMacKeyRing~new
keys~addKey("demo", "000102030405060708090a0b0c0d0e0f")
journal = .WLUJobRouteFileJournal~new(path, keys)

call history journal, keys, "GEMMA", "G", 5, 4, 4 * MICRO
call history journal, keys, "GROK", "R", 5, 5, 5 * MICRO

advisor = .WLUJobRouteAdvisor~new(keys)
snapshot = advisor~analytics~verifiedSnapshot(journal)~value
policy = .WLURouteAdvisoryPolicy~new(5, 4000, 6000, 0)
stages = .array~of( -
  .WLUJobStage~new("GEMMA", "SHANNON:GEMMA", 4 * MICRO, 6 * MICRO), -
  .WLUJobStage~new("GROK", "SHANNON:GROK", 5 * MICRO, 7 * MICRO) )
advice = advisor~advise(snapshot, stages, policy)~value

now = .DateTime~new
rules = .WLURouteDecisionRules~new("RECOMMENDED_ONLY", "EVIDENCE_ELIGIBLE")~seal
release = .InstitutionalPolicyRelease~new("WLU-ROUTE-SELECTION", "1.0", now - .TimeSpan~new(0,1,0,0,0), .nil, "SCHEDULER_ENGINEERING", "OPERATIONS_BOARD", "", rules)~seal
catalog = .InstitutionalPolicyCatalog~new
ignore = catalog~publish(release)

gate = .WLUJobRouteDecisionGate~new(keys)
decision = gate~decide(catalog, "WLU-ROUTE-SELECTION", advice, advice~recommendedStageId, now, "AUTOMATED")~value

say "advisory recommendation:" advice~recommendedStageId
say "advisory proof key:" advice~proof~keyId
say "advisory evidence sequence:" advice~sourceSequence
say "decision status:" decision~status
say "decision reason:" decision~reasonCode
say "policy:" decision~policyId || "@" || decision~policyVersion
say "policy execution model:" decision~policyRelease~executionModel
say "evaluation mode:" decision~evaluationMode
say "authored by:" decision~publicationRecord~authoredBy
say "approved by:" decision~publicationRecord~approvedBy
say "decision proof valid:" decision~verify(keys)
say "decision reserves/spends WLU: NO"
say "scheduler must still perform ordinary WLU admission: YES"

call SysFileDelete path
exit 0

history: procedure
  use strict arg journal, keys, stageId, prefix, samples, successes, actual
  do i = 1 to samples
    if i <= successes then outcome = "SUCCESS"
    else outcome = "PROVIDER_FAILURE"
    event = .WLUJobRouteEvidence~new(prefix || "-" || i, 1, i, .WLUJobRouteEventType~STAGE_SETTLED, stageId, "", "r-" || prefix || i, actual, 0, .true, actual, actual + 2000000, 1, "WITHIN_BUDGET", "", outcome, "outcome:" || prefix || i, "ai-common", "2026-08")
    event = event~withProof(keys~sign(event~canonicalText))
    ignore = journal~appendEvent(event)
  end
  return

::requires "WLURouteDecisionPolicy.cls"
