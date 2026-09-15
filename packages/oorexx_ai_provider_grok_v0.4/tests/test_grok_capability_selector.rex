/* Deterministic tests for GrokCapabilitySelector */
root = arg(1)
if root = "" then root = "."
call main root
exit 0

main:
  procedure
  use arg root
  say "GROK CAPABILITY SELECTOR V0.4 START"
  sel = .GrokCapabilitySelector~new

  /* 1. Low-tier, batch-ok, high volume -> cheapest ECONOMY + batch */
  p1 = .GrokWorkloadProfile~new("ECONOMY", "ANY", .true, 500000, 20000)
  plan1 = sel~selectModel(p1)
  call eq "grok-code-fast-1", plan1~modelId, "low-tier batch prefers code-fast"
  call yes plan1~useBatch, "batch-ok workload routes to batch"
  call eq "ECONOMY", plan1~tier, "tier ECONOMY"
  say "  PASS low-tier batch ->" plan1~modelId "batch=" plan1~useBatch "est=" plan1~estimatedMicroUsd

  /* 2. FRONTIER floor must escalate, not stay on economy */
  p2 = .GrokWorkloadProfile~new("FRONTIER", "ANY", .false, 5000, 1000)
  plan2 = sel~selectModel(p2)
  call yes plan2~tier = "FRONTIER", "frontier floor stays frontier"
  call no plan2~useBatch, "batchOk=false stays real-time"
  say "  PASS frontier real-time ->" plan2~modelId "tier=" plan2~tier "est=" plan2~estimatedMicroUsd

  /* 3. STANDARD floor, batch ok -> cheapest STANDARD that is batchEligible */
  p3 = .GrokWorkloadProfile~new("STANDARD", "ANY", .true, 10000, 500)
  plan3 = sel~selectModel(p3)
  call yes plan3~tier = "STANDARD" | plan3~tier = "FRONTIER", "at least STANDARD"
  /* ECONOMY is below floor so must not appear */
  call no plan3~modelId = "grok-code-fast-1", "must not drop below STANDARD floor"
  call yes plan3~useBatch, "batch preferred when allowed"
  say "  PASS standard batch ->" plan3~modelId "tier=" plan3~tier

  /* 4. Cost ceiling that only economy can meet */
  p4 = .GrokWorkloadProfile~new("ECONOMY", "ANY", .false, 1000, 100, 300)
  plan4 = sel~selectModel(p4)
  call eq "grok-code-fast-1", plan4~modelId, "tight ceiling picks economy"
  say "  PASS cost ceiling ->" plan4~modelId "est=" plan4~estimatedMicroUsd

  /* 5. Impossible: FRONTIER + absurdly low ceiling must raise */
  signal on syntax name expectedRaise
  p5 = .GrokWorkloadProfile~new("FRONTIER", "ANY", .false, 100000, 50000, 1)
  plan5 = sel~selectModel(p5)
  say "FAILED: expected raise on impossible ceiling"
  exit 71
expectedRaise:
  signal off syntax
  say "  PASS impossible ceiling raises"

  /* 6. estimateCost helper */
  cost = sel~estimateCost("grok-4.6", 1000000, 1000000, .false)
  call yes cost > 0, "estimateCost positive"
  costB = sel~estimateCost("grok-4.6", 1000000, 1000000, .true)
  call yes costB < cost, "batch discount reduces cost"
  say "  PASS estimateCost real-time=" cost "batch=" costB

  say "GROK CAPABILITY SELECTOR V0.4: OK"
  return

eq:
  procedure
  use arg expected, actual, label
  if expected \== actual then do
    say "FAILED:" label
    say " expected=" expected
    say " actual=" actual
    exit 71
  end
  return

yes:
  procedure
  use arg value, label
  if \value then do; say "FAILED:" label; exit 73; end
  return

no:
  procedure
  use arg value, label
  if value then do; say "FAILED:" label; exit 74; end
  return

::requires "GrokCapability.cls"
