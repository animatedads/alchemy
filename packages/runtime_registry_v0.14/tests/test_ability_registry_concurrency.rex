parse arg root
if root = "" then root = directory()

say "ABILITY REGISTRY V0.1 CONCURRENCY START"

verifier = .RuntimePinnedSourceVerifier~new
kernel = .RuntimeKernel~new(verifier)

cap1Result = .RuntimeArtifactFactory~fromFile("stress.data", "CAPABILITY", "1.0.0", "ability:stress:data:1", "DemoCapability", root || "/fixtures/modules/DemoCapability_v1.cls")
cap2Result = .RuntimeArtifactFactory~fromFile("stress.data", "CAPABILITY", "2.0.0", "ability:stress:data:2", "DemoCapability", root || "/fixtures/modules/DemoCapability_v2.cls")
call assert cap1Result~ok, "load data v1"
call assert cap2Result~ok, "load data v2"
cap1Artifact = cap1Result~value
cap2Artifact = cap2Result~value
call assert verifier~pin(cap1Artifact~artifactId, cap1Artifact~sourceLines)~ok, "pin data v1"
call assert verifier~pin(cap2Artifact~artifactId, cap2Artifact~sourceLines)~ok, "pin data v2"

cap1Stage = kernel~stage("stress", cap1Artifact)
call assert cap1Stage~ok, "stage data v1"
cap1 = cap1Stage~value
call assert kernel~activate("stress", "stress.data", cap1~generationId)~ok, "activate data v1"

abilityRegistry = .AbilityRegistry~new(kernel)
p1 = makeProfile("1", "ability:stress:data:1")
a1Stage = abilityRegistry~stage("stress", p1)
call assert a1Stage~ok, "stage P1"
a1 = a1Stage~value
call assert abilityRegistry~activate("stress", "client-stress", a1~generationId)~ok, "activate P1"

/* Publish runtime v2 and stage P2 while P1 keeps v1 pinned. */
cap2Stage = kernel~stage("stress", cap2Artifact)
call assert cap2Stage~ok, "stage data v2"
cap2 = cap2Stage~value
call assert kernel~activate("stress", "stress.data", cap2~generationId)~ok, "activate data v2"
p2 = makeProfile("2", "ability:stress:data:2")
a2Stage = abilityRegistry~stage("stress", p2)
call assert a2Stage~ok, "stage P2"
a2 = a2Stage~value

gate = .AbilityStartGate~new
messages = .array~new
do workerNo = 1 to 8
  worker = .AbilitySessionWorker~new(abilityRegistry, "stress", "client-stress", 500, gate)
  msg = .Message~new(worker, "RUN")
  msg~start
  messages~append(msg)
end

readyResult = gate~awaitReady(8)
call assert (a1~leaseCount = 8), "all workers hold P1 sessions"
call assert abilityRegistry~activate("stress", "client-stress", a2~generationId)~ok, "publish P2 with eight in-flight P1 sessions"
call assert (a1~state = "DRAINING"), "P1 drains after P2 publication"
call assert (a1~leaseCount = 8), "P1 held sessions remain intact"
openResult = gate~open

heldOneCount = 0
oneCount = 0
twoCount = 0
errorCount = 0
do msg over messages
  msg~wait
  call assert (msg~errorCondition == .nil), "ability worker completes without condition"
  resultRow = msg~result
  heldOneCount = heldOneCount + resultRow["HELD_ONE"]
  oneCount = oneCount + resultRow["ONE"]
  twoCount = twoCount + resultRow["TWO"]
  errorCount = errorCount + resultRow["ERROR"]
end

call assert (heldOneCount = 8), "every held P1 session continued to see v1"
call assert (oneCount + twoCount = 4000), "all post-publication sessions resolved"
call assert (oneCount = 0), "no new session saw P1 after publication"
call assert (twoCount = 4000), "all new sessions saw P2"
call assert (errorCount = 0), "no ability acquisition/release errors"
call assert (abilityRegistry~activeGenerationId("stress", "client-stress") = a2~generationId), "P2 remains active"
collectResult = abilityRegistry~collectRetired
call assert (a1~state = "RETIRED"), "P1 retires after held sessions release"

say "  held_p1_sessions=" || heldOneCount
say "  post_publish_p1=" || oneCount
say "  post_publish_p2=" || twoCount
say "  errors=" || errorCount
say "ABILITY REGISTRY V0.1 CONCURRENCY: OK"
exit 0

makeProfile: procedure
  use arg revision, artifactId
  runtimeBindings = .array~of(.AbilityRuntimeBinding~new("data", "stress.data", artifactId))
  abilities = .array~of(.AbilityDescriptor~new("query", "QUERY", .array~of("data"), .true, "stress query"))
  return .AbilityProfileRevision~new("stress-profile", revision, "client-stress", runtimeBindings, abilities)

assert: procedure
  use arg condition, label
  if \condition then do
    say "ASSERTION FAILED:" label
    exit 1
  end
return

::class AbilityStartGate
::method init
  expose ready isOpen
  ready = 0
  isOpen = .false

::method held
  expose ready
  guard on
  ready = ready + 1
  return ready

::method awaitReady
  expose ready
  use arg required
  guard on when ready >= required
  return ready

::method awaitOpen
  expose isOpen
  guard on when isOpen
  return .true

::method open
  expose isOpen
  guard on
  isOpen = .true
  return .true

::class AbilitySessionWorker
::method init
  expose registry environment clientId loops gate
  use arg registry, environment, clientId, loops, gate

::method run
  expose registry environment clientId loops gate
  counts = .directory~new
  counts["HELD_ONE"] = 0
  counts["ONE"] = 0
  counts["TWO"] = 0
  counts["ERROR"] = 0

  heldResult = registry~acquire(environment, clientId)
  if \heldResult~ok then do
    counts["ERROR"] = counts["ERROR"] + 1
    return counts
  end
  heldSession = heldResult~value
  ready = gate~held
  gateResult = gate~awaitOpen
  if heldSession~module("data")~version = "ONE" then counts["HELD_ONE"] = 1
  else counts["ERROR"] = counts["ERROR"] + 1
  releaseResult = heldSession~release
  if \releaseResult~ok then counts["ERROR"] = counts["ERROR"] + 1

  do i = 1 to loops
    acquireResult = registry~acquire(environment, clientId)
    if \acquireResult~ok then do
      counts["ERROR"] = counts["ERROR"] + 1
      iterate
    end
    session = acquireResult~value
    module = session~module("data")
    if module == .nil then counts["ERROR"] = counts["ERROR"] + 1
    else do
      version = module~version
      if version = "ONE" then counts["ONE"] = counts["ONE"] + 1
      else if version = "TWO" then counts["TWO"] = counts["TWO"] + 1
      else counts["ERROR"] = counts["ERROR"] + 1
    end
    releaseResult = session~release
    if \releaseResult~ok then counts["ERROR"] = counts["ERROR"] + 1
  end

  return counts

::requires "AbilityRegistry.cls"
