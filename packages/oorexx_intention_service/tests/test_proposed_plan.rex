parse source . . here
base = filespec("L", here)
call value "REXX_PATH", base || "/../src:" || value("REXX_PATH", , "ENVIRONMENT"), "ENVIRONMENT"

/* Plans attached by competing providers survive N-way clarification. */
service = .IntentionService~new
service~registerBucket("TEST", .IntentionBucketPolicy~new("FLEXIBLE", 50, 10, .false, .false))
service~register("show customer", "SHOW", "TEST")~tag("CLARIFICATION_LABEL", "SHOW CUSTOMER")
service~register("edit customer", "EDIT", "TEST")~tag("CLARIFICATION_LABEL", "EDIT CUSTOMER")
service~registerProvider(.PlanChoiceProvider~new)

d = service~input("customer bob")
call assertEq "CLARIFY", d~status, "plan choices clarify"
call assertEq 2, d~choices~items, "plan choice count"
call assertEq "Read matching customer records", d~choices~at(1)~proposedPlan~summary, "choice one plan"
call assertEq "Modify the selected customer record", d~choices~at(2)~proposedPlan~summary, "choice two plan"
call assertEq "QUERY", d~choices~at(1)~proposedPlan~steps~at(1)~kind, "choice one structured step"
call assertEq "UNKNOWN", d~choices~at(1)~planAssessment~status, "choice one assessment preserved"
call assertEq "UNKNOWN", d~choices~at(2)~planAssessment~status, "choice two assessment preserved"

d = service~input("2")
call assertEq "READY", d~status, "selected planned intention ready"
call assertEq "Modify the selected customer record", d~proposedPlan~summary, "selected plan preserved"
call assertEq "WRITE", d~proposedPlan~sideEffectClass, "selected side effect preserved"
call assertEq "UNKNOWN", d~planAssessment~status, "selected assessment preserved"

/* A registration-owned builder is re-run after canonical slot resolution. */
service2 = .IntentionService~new
service2~registerBucket("TEST", .IntentionBucketPolicy~new("FLEXIBLE", 55, 8, .false, .false))
reg = service2~register("find orders", "ORDERS", "TEST")
reg~requireSlot("CUSTOMER", "Which customer?", .true)
reg~slotType("CUSTOMER", "CUSTOMER_REF")
reg~planBuilder(.OrdersPlanBuilder~new)
service2~registerSlotResolver("CUSTOMER_REF", .CustomerResolver~new)

d = service2~input("find orders")
call assertEq "CLARIFY", d~status, "orders needs customer"
call assertEq "Resolve customer then query orders", d~proposedPlan~summary, "unresolved plan visible"
call assertEq "<unresolved>", d~proposedPlan~steps~at(1)~arguments~at("CUSTOMER"), "unresolved plan placeholder"

d = service2~input("alice")
call assertEq "READY", d~status, "resolved plan ready"
call assertEq "customer_id=1", d~slots~at("CUSTOMER")~value, "canonical customer binding"
call assertEq "customer_id=1", d~proposedPlan~steps~at(1)~arguments~at("CUSTOMER"), "plan refreshed from canonical binding"
call assertEq "READ_ONLY", d~proposedPlan~sideEffectClass, "resolved plan side effect"

say "PASS test_proposed_plan"
exit 0

assertEq: procedure
  use arg expected, actual, label
  if expected == actual then return
  say "FAIL" label "expected=" expected "actual=" actual
  exit 1

::class PlanChoiceProvider public
::method propose
  use arg service, text
  showPlan = .IntentionPlan~new("SHOW_CUSTOMER", "Read matching customer records")
  showPlan~sideEffectClass = "READ_ONLY"
  showPlan~addStep("QUERY", "Find matching customer", "CUSTOMERS")
  showProposal = .IntentionProposal~new("SHOW_CUSTOMER", 90, "PLAN_CHOICE", .false, "read candidate")
  showProposal~proposedPlan(showPlan)

  editPlan = .IntentionPlan~new("EDIT_CUSTOMER", "Modify the selected customer record")
  editPlan~sideEffectClass = "WRITE"
  editPlan~requireAuthority("CUSTOMER_EDIT")
  editPlan~addStep("RESOLVE_ENTITY", "Resolve customer identity", "CUSTOMER")
  editPlan~addStep("UPDATE", "Update selected customer", "CUSTOMERS")
  editProposal = .IntentionProposal~new("EDIT_CUSTOMER", 89, "PLAN_CHOICE", .false, "write candidate")
  editProposal~proposedPlan(editPlan)

  return .Array~of(showProposal, editProposal)

::class OrdersPlanBuilder public
::method build
  use arg service, registration, proposal
  customer = "<unresolved>"
  slot = proposal~slot("CUSTOMER")
  if slot \== .nil then customer = slot~value
  args = .Directory~new
  args~put(customer, "CUSTOMER")
  plan = .IntentionPlan~new(registration~id, "Resolve customer then query orders")
  plan~sideEffectClass = "READ_ONLY"
  plan~requireBinding("CUSTOMER")
  plan~expectOutput("ORDER_RECORDS")
  plan~addStep("DATABASE_QUERY", "Query orders for customer", "ORDERS", args)
  return plan

::class CustomerResolver public
::method resolve
  use arg service, registration, proposal, requirement, answer
  if translate(strip(answer)) \== "ALICE" then return .IntentionSlotResolution~none(requirement~prompt)
  candidate = .IntentionSlotResolutionCandidate~new("CUSTOMER: Alice Morgan (1)", 100, "fixture database authority")
  candidate~putBinding("CUSTOMER", "customer_id=1", .true)
  return .IntentionSlotResolution~one(candidate)

::requires "IntentionService.cls"
::requires "IntentionProviders.cls"
