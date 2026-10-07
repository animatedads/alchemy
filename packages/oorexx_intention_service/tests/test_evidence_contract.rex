parse source . . here
base = filespec("L", here)
call value "REXX_PATH", base || "/../src:" || value("REXX_PATH", , "ENVIRONMENT"), "ENVIRONMENT"

/* Shared evidence ledger distinguishes confidence from evidential authority. */
service = .IntentionService~new
hintFact = .IntentionEvidenceFact~new("room", "CAPABILITY", "OPEN", 100, "USER_HINT", "ADVISORY", "fixture:user")
service~addEvidenceFact(hintFact)
call assertEq 1, service~evidenceFacts("ROOM", "CAPABILITY")~items, "shared evidence indexed"
call assertEq 10, hintFact~authorityRank, "advisory authority rank"
call assertEq "USER_HINT", hintFact~source, "source retained"
call assertEq "fixture:user", hintFact~provenance, "provenance retained"

service~registerBucket("TEST", .IntentionBucketPolicy~new("FLEXIBLE", 55, 8, .false, .false))
reg = service~register("open room", "OPEN", "TEST")
reg~planBuilder(.EvidencePlanBuilder~new)

d = service~input("open room")
call assertEq "READY", d~status, "meaning understood despite weak evidence"
call assertEq "INFEASIBLE", d~planAssessment~status, "advisory evidence does not satisfy observed requirement"
call assertEq 1, d~planAssessment~violatedPreconditions~items, "evidence blocker surfaced"
call assertEq .false, d~planExecutable, "weak evidence plan not executable"

/* Runtime observation satisfies the same plan without changing recognition. */
observed = .IntentionEvidenceFact~new("room", "CAPABILITY", "OPEN", 95, "RUNTIME_INTERROGATION", "OBSERVED", "fixture:runtime")
service~addEvidenceFact(observed)
best = service~bestEvidence("ROOM", "CAPABILITY", "OPEN")
call assertEq "RUNTIME_INTERROGATION", best~source, "stronger observed evidence wins lookup"
call assertEq "OBSERVED", best~authority, "best evidence authority"
d = service~input("open room")
call assertEq "READY", d~status, "meaning remains ready"
call assertEq "FEASIBLE", d~planAssessment~status, "observed evidence satisfies requirement"
call assertEq .true, d~planExecutable, "observed evidence executable"

/* Proposal-local evidence and plan-local evidence use the same contract. */
proposal = .IntentionProposal~new("OPEN_ROOM", 90, "FIXTURE", .true, "fixture")
proposalFact = .IntentionEvidenceFact~new("door", "STATE", "CLOSED", 90, "SENSOR", "OBSERVED", "fixture:sensor")
proposal~addEvidenceFact(proposalFact)
plan = .IntentionPlan~new("OPEN_ROOM", "Open the door")
plan~requireEvidence("door", "STATE", "CLOSED", 80, "OBSERVED", "door must be observed closed")
proposal~proposedPlan(plan)
proposal = service~assessProposalPlan(proposal)
call assertEq "FEASIBLE", proposal~proposedPlan~assessment~status, "proposal evidence satisfies plan"
call assertEq 1, proposal~evidenceFacts~items, "proposal evidence retained"

/* Contract evidence can satisfy a contract-level requirement but advisory cannot. */
contractPlan = .IntentionPlan~new("CALL_METHOD", "Call known method")
contractPlan~requireEvidence("DIRECTORY", "METHOD", "ITEMS", 90, "CONTRACT", "language contract must establish Directory.items")
contractPlan~addEvidenceFact(.IntentionEvidenceFact~new("Directory", "METHOD", "ITEMS", 95, "LANGUAGE_CATALOGUE", "CONTRACT", "fixture:catalogue"))
proposal2 = .IntentionProposal~new("CALL_METHOD", 90, "FIXTURE", .true, "fixture")
proposal2~proposedPlan(contractPlan)
proposal2 = service~assessProposalPlan(proposal2)
call assertEq "FEASIBLE", proposal2~proposedPlan~assessment~status, "contract evidence satisfies contract requirement"

/* Copy paths preserve structured facts and requirements. */
copy = proposal2~copy
call assertEq 1, copy~proposedPlan~evidenceFacts~items, "plan evidence copied"
call assertEq 1, copy~proposedPlan~evidenceRequirements~items, "requirements copied"
call assertEq "LANGUAGE_CATALOGUE", copy~proposedPlan~evidenceFacts~at(1)~source, "copied source"

say "PASS test_evidence_contract"
exit 0

assertEq: procedure
  use arg expected, actual, label
  if expected == actual then return
  say "FAIL" label "expected=" expected "actual=" actual
  exit 1

::class EvidencePlanBuilder public
::method build
  use arg service, registration, proposal
  plan = .IntentionPlan~new(registration~id, "Open room if runtime evidence permits")
  plan~sideEffectClass = "STATE_CHANGE"
  plan~requireEvidence("room", "CAPABILITY", "OPEN", 90, "OBSERVED", "room must have observed OPEN capability")
  plan~addStep("OPEN", "Open room", "ROOM")
  return plan

::requires "IntentionService.cls"
::requires "IntentionProviders.cls"
