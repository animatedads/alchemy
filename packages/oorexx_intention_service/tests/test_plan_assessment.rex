parse source . . here
base = filespec("L", here)
call value "REXX_PATH", base || "/../src:" || value("REXX_PATH", , "ENVIRONMENT"), "ENVIRONMENT"

/* Missing structural bindings are infeasible before domain assessment can help. */
service = .IntentionService~new
service~registerBucket("TEST", .IntentionBucketPolicy~new("FLEXIBLE", 55, 8, .false, .false))
reg = service~register("open document", "OPEN", "TEST")
reg~requireSlot("DOCUMENT_ID", "Which document?", .true)
reg~slotType("DOCUMENT_ID", "DOCUMENT_REF")
reg~planBuilder(.DocumentPlanBuilder~new)
reg~planAssessor(.DocumentPlanAssessor~new(.true, .true))
service~registerSlotResolver("DOCUMENT_REF", .DocumentResolver~new)

d = service~input("open document")
call assertEq "CLARIFY", d~status, "missing document clarifies"
call assertEq "INFEASIBLE", d~planAssessment~status, "missing binding assessment"
call assertEq 1, d~planAssessment~missingBindings~items, "one missing binding"
call assertEq "DOCUMENT_ID", d~planAssessment~missingBindings~at(1), "missing document binding"
call assertEq .false, d~planExecutable, "missing binding not executable"

d = service~input("alpha")
call assertEq "READY", d~status, "resolved document ready"
call assertEq "doc-1", d~slots~at("DOCUMENT_ID")~value, "canonical document binding"
call assertEq "FEASIBLE", d~planAssessment~status, "resolved plan feasible"
call assertEq .true, d~planExecutable, "resolved plan executable"
call assertEq 1, d~planAssessment~evidence~items, "feasibility evidence retained"

/* Meaning READY and plan feasibility remain independent axes. */
blocked = .IntentionService~new
blocked~registerBucket("TEST", .IntentionBucketPolicy~new("FLEXIBLE", 55, 8, .false, .false))
reg2 = blocked~register("inspect document", "INSPECT", "TEST")
reg2~planBuilder(.BoundDocumentPlanBuilder~new)
reg2~planAssessor(.DocumentPlanAssessor~new(.false, .false))

d = blocked~input("inspect document")
call assertEq "READY", d~status, "meaning can be ready while plan blocked"
call assertEq "INFEASIBLE", d~planAssessment~status, "blocked plan infeasible"
call assertEq 1, d~planAssessment~unavailableResources~items, "resource blocker surfaced"
call assertEq 1, d~planAssessment~missingAuthority~items, "authority blocker surfaced"
call assertEq .false, d~planExecutable, "blocked plan not executable"

/* Provider identity does not change a registration-owned plan or assessment. */
providerNeutral = .IntentionService~new
providerNeutral~registerBucket("TEST", .IntentionBucketPolicy~new("FLEXIBLE", 55, 8, .false, .false))
reg3 = providerNeutral~register("review document", "REVIEW", "TEST")
reg3~planBuilder(.BoundDocumentPlanBuilder~new)
reg3~planAssessor(.DocumentPlanAssessor~new(.true, .true))

p1 = .IntentionProposal~new("REVIEW_DOCUMENT", 90, "DETERMINISTIC", .true, "deterministic recognition")
p2 = .IntentionProposal~new("REVIEW_DOCUMENT", 90, "LLM_FIXTURE", .true, "LLM-shaped recognition")
p1 = providerNeutral~materializeProposalPlan(p1)
p2 = providerNeutral~materializeProposalPlan(p2)
call assertEq p1~proposedPlan~summary, p2~proposedPlan~summary, "provider-neutral plan summary"
call assertEq p1~proposedPlan~steps~at(1)~kind, p2~proposedPlan~steps~at(1)~kind, "provider-neutral plan step"
call assertEq "FEASIBLE", p1~proposedPlan~assessment~status, "deterministic assessment"
call assertEq p1~proposedPlan~assessment~status, p2~proposedPlan~assessment~status, "provider-neutral assessment"

say "PASS test_plan_assessment"
exit 0

assertEq: procedure
  use arg expected, actual, label
  if expected == actual then return
  say "FAIL" label "expected=" expected "actual=" actual
  exit 1

::class DocumentPlanBuilder public
::method build
  use arg service, registration, proposal
  plan = .IntentionPlan~new(registration~id, "Open one authoritative document")
  plan~sideEffectClass = "READ_ONLY"
  plan~requireBinding("DOCUMENT_ID")
  plan~requireAuthority("DOCUMENT_READ")
  plan~addStep("RESOLVE_DOCUMENT", "Resolve canonical document identity", "DOCUMENT")
  plan~addStep("READ_DOCUMENT", "Read the authoritative document", "DOCUMENT")
  plan~expectOutput("DOCUMENT")
  return plan

::class BoundDocumentPlanBuilder public
::method build
  use arg service, registration, proposal
  plan = .IntentionPlan~new(registration~id, "Inspect the authoritative document")
  plan~sideEffectClass = "READ_ONLY"
  plan~requireAuthority("DOCUMENT_READ")
  plan~addStep("READ_DOCUMENT", "Read the authoritative document", "DOCUMENT")
  plan~expectOutput("DOCUMENT")
  return plan

::class DocumentPlanAssessor public
::method init
  expose resourceAvailable authorityAvailable
  use arg resourceAvailable, authorityAvailable
::method assess
  expose resourceAvailable authorityAvailable
  use arg service, registration, proposal, plan, assessment
  if resourceAvailable == .false then assessment~addUnavailableResource("DOCUMENT_STORE")
  if authorityAvailable == .false then assessment~addMissingAuthority("DOCUMENT_READ")
  if assessment~blockerCount = 0 then do
    assessment~markFeasible("Authoritative document state and required authority are available.")
    assessment~addEvidence("fixture authoritative application state")
  end
  return assessment

::class DocumentResolver public
::method resolve
  use arg service, registration, proposal, requirement, answer
  if translate(strip(answer)) \== "ALPHA" then return .IntentionSlotResolution~none(requirement~prompt)
  candidate = .IntentionSlotResolutionCandidate~new("DOCUMENT: Alpha (doc-1)", 100, "fixture document authority")
  candidate~putBinding("DOCUMENT_ID", "doc-1", .true)
  return .IntentionSlotResolution~one(candidate)

::requires "IntentionService.cls"
::requires "IntentionProviders.cls"
