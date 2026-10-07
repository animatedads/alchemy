parse source . . here
base = filespec("L", here)
call value "REXX_PATH", base || "/../src:" || value("REXX_PATH", , "ENVIRONMENT"), "ENVIRONMENT"

/* This is the generic replacement for application-owned post-READY shape gates. */
service = .IntentionService~new
service~registerBucket("CODING", .IntentionBucketPolicy~new("FLEXIBLE", 55, 8, .false, .false))
reg = service~register("read room member", "READ_MEMBER", "CODING")
reg~planBuilder(.KeyedReadPlanBuilder~new)

/* Recognition is certain, but the plan lacks enough evidence to proceed. */
d = service~input("read room member")
call assertEq "CLARIFY", d~status, "missing plan evidence clarifies inside service"
call assertEq "Keyed member access needs observed keyed-access evidence for ROOM.", d~question, "plan-owned clarification question"
call assertEq "INFEASIBLE", d~planAssessment~status, "missing capability infeasible"

/* A high-confidence hint still cannot satisfy an OBSERVED requirement. */
service~addEvidenceFact(.IntentionEvidenceFact~new("ROOM", "CAPABILITY", "KEYED_ACCESS", 100, "USER_HINT", "ADVISORY", "fixture:user"))
d = service~refreshActiveDecision
call assertEq "CLARIFY", d~status, "advisory hint remains insufficient"

/* Runtime/domain observation satisfies the same generic requirement. */
service~addEvidenceFact(.IntentionEvidenceFact~new("ROOM", "SHAPE", "DIRECTORY", 100, "RUNTIME_INTERROGATION", "OBSERVED", "fixture:runtime"))
service~addEvidenceFact(.IntentionEvidenceFact~new("ROOM", "CAPABILITY", "KEYED_ACCESS", 100, "RUNTIME_INTERROGATION", "OBSERVED", "fixture:runtime"))
d = service~refreshActiveDecision
call assertEq "READY", d~status, "observed capability removes service clarification"
call assertEq "FEASIBLE", d~planAssessment~status, "observed capability feasible"
call assertEq .true, d~planExecutable, "evidence-backed plan executable"

say "PASS test_evidence_plan_clarification"
exit 0

assertEq: procedure
  use arg expected, actual, label
  if expected == actual then return
  say "FAIL" label "expected=" expected "actual=" actual
  exit 1

::class KeyedReadPlanBuilder public
::method build
  use arg service, registration, proposal
  plan = .IntentionPlan~new(registration~id, "Read a keyed member")
  plan~sideEffectClass = "READ_ONLY"
  plan~requireEvidence("ROOM", "CAPABILITY", "KEYED_ACCESS", 90, "OBSERVED", -
      "ROOM must have observed keyed-access capability", -
      "Keyed member access needs observed keyed-access evidence for ROOM.")
  plan~addStep("GET_NAMED_MEMBER", "Read member from keyed object", "ROOM")
  return plan

::requires "IntentionService.cls"
::requires "IntentionProviders.cls"
