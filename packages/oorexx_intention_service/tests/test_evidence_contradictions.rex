parse source . . here
base = filespec("L", here)
call value "REXX_PATH", base || "/../src:" || value("REXX_PATH", , "ENVIRONMENT"), "ENVIRONMENT"

service = .IntentionService~new
service~addEvidenceFact(.IntentionEvidenceFact~new("SYSTEM", "STATE", "READY", 100, "PLANE_A", "OBSERVED", "a"))
service~addEvidenceFact(.IntentionEvidenceFact~new("SYSTEM", "STATE", "STOPPED", 100, "PLANE_B", "OBSERVED", "b"))
set = service~evidenceSet("SYSTEM", "STATE")
call assertEq 2, set~all~items, "both facts retained"
call assertEq .true, set~hasContradiction("SYSTEM", "STATE"), "contradiction visible"
call assertEq 1, set~contradictions~items, "one contradiction group"

proposal = .IntentionProposal~new("CHECK_SYSTEM", 90, "FIXTURE", .true, "fixture")
plan = .IntentionPlan~new("CHECK_SYSTEM", "Check system")
plan~requireEvidence("SYSTEM", "STATE", "READY", 90, "OBSERVED", "system must be ready without contradiction", "", "", "NO_CONTRADICTION", 1)
proposal~proposedPlan(plan)
proposal = service~assessProposalPlan(proposal)
call assertEq "INFEASIBLE", proposal~proposedPlan~assessment~status, "no-contradiction requirement blocks"

proposal2 = .IntentionProposal~new("CHECK_SYSTEM", 90, "FIXTURE", .true, "fixture")
plan2 = .IntentionPlan~new("CHECK_SYSTEM", "Check plane A")
plan2~requireEvidence("SYSTEM", "STATE", "READY", 90, "OBSERVED", "plane A says ready", "", "PLANE_A", "ALLOW", 1)
proposal2~proposedPlan(plan2)
proposal2 = service~assessProposalPlan(proposal2)
call assertEq "FEASIBLE", proposal2~proposedPlan~assessment~status, "source-specific evidence can be used deliberately"

proposal3 = .IntentionProposal~new("CHECK_SYSTEM", 90, "FIXTURE", .true, "fixture")
plan3 = .IntentionPlan~new("CHECK_SYSTEM", "Require two agreeing observations")
plan3~requireEvidence("SYSTEM", "STATE", "READY", 90, "OBSERVED", "two planes must agree ready", "", "", "ALLOW", 2)
proposal3~proposedPlan(plan3)
proposal3 = service~assessProposalPlan(proposal3)
call assertEq "INFEASIBLE", proposal3~proposedPlan~assessment~status, "consensus count enforced"

say "PASS test_evidence_contradictions"
exit 0

assertEq: procedure
  use arg expected, actual, label
  if expected == actual then return
  say "FAIL" label "expected=" expected "actual=" actual
  exit 1

::requires "IntentionService.cls"
::requires "IntentionProviders.cls"
