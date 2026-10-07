service = .IntentionService~new
service~registerBucket("TEST", .IntentionBucketPolicy~new("FLEXIBLE", 55, 8, .false, .false))
reg = service~register("inspect entity", "EVENT", "TEST")
reg~requireSlot("TARGET", "Which entity?", .true)
reg~slotType("TARGET", "ENTITY_REF")
service~registerSlotResolver("ENTITY_REF", .FixtureEntityResolver~new)

/* Unique clarification answer binds canonical identity and completes. */
d = service~input("inspect entity")
call assertEq "CLARIFY", d~status, "unique initial clarify"
d = service~input("alice")
call assertEq "READY", d~status, "unique resolved ready"
call assertEq "customer_id=1", d~slots~at("TARGET")~value, "unique canonical binding"

/* Ambiguous clarification answer reuses the ordinary numbered choice contract. */
service~reset
d = service~input("inspect entity")
call assertEq "CLARIFY", d~status, "ambiguous initial clarify"
d = service~input("smith")
call assertEq "CLARIFY", d~status, "ambiguous stays clarify"
call assertEq 2, d~choices~items, "ambiguous option count"
call assertEq "CUSTOMER: Bob Smith (2)", d~choices~at(1)~label, "choice one label"
call assertEq "CUSTOMER: Jane Smith (7)", d~choices~at(2)~label, "choice two label"
d = service~input("2")
call assertEq "READY", d~status, "number selection ready"
call assertEq "customer_id=7", d~slots~at("TARGET")~value, "selected canonical binding"

/* Unknown clarification does not become raw slot text. */
service~reset
d = service~input("inspect entity")
d = service~input("purple elephant")
call assertEq "CLARIFY", d~status, "unknown remains clarify"
call assertEq "Which entity?", d~question, "unknown retains prompt"

say "PASS generic slot resolution"
exit 0

assertEq: procedure
  use arg expected, actual, label
  if expected == actual then return
  say "FAIL" label "expected=" expected "actual=" actual
  exit 1

::class FixtureEntityResolver public
::method resolve
  use arg service, registration, proposal, requirement, answer
  key = translate(strip(answer))
  if key == "ALICE" then do
    c = .IntentionSlotResolutionCandidate~new("CUSTOMER: Alice Morgan (1)", 100, "fixture unique entity")
    c~putBinding(requirement~name, "customer_id=1", .true)
    return .IntentionSlotResolution~one(c)
  end
  if key == "SMITH" then do
    choices = .Array~new
    c = .IntentionSlotResolutionCandidate~new("CUSTOMER: Bob Smith (2)", 95, "fixture ambiguous entity")
    c~putBinding(requirement~name, "customer_id=2", .true)
    choices~append(c)
    c = .IntentionSlotResolutionCandidate~new("CUSTOMER: Jane Smith (7)", 93, "fixture ambiguous entity")
    c~putBinding(requirement~name, "customer_id=7", .true)
    choices~append(c)
    return .IntentionSlotResolution~many(choices, "Which Smith?")
  end
  return .IntentionSlotResolution~none(requirement~prompt)

::requires "IntentionService.cls"
