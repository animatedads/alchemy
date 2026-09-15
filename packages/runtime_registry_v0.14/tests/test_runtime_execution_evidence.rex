parse arg root
if root = "" then root = directory()

say "RUNTIME REGISTRY V0.9 EXECUTION EVIDENCE START"
a = .RuntimeExecutionEvidenceAcceptance~new(root)
exit a~run

::class RuntimeExecutionEvidenceAcceptance
::method init
  expose root assertions
  use arg rootArg
  root = rootArg
  assertions = 0

::method run
  expose root assertions
  verifier = .RuntimePinnedSourceVerifier~new
  kernel = .RuntimeKernel~new(verifier)

  v1Lines = self~readLines(root || "/fixtures/modules/DemoCapability_v1.cls")
  v2Lines = self~readLines(root || "/fixtures/modules/DemoCapability_v2.cls")
  ignored = verifier~pin("fixture:evidence:v1", v1Lines)
  ignored = verifier~pin("fixture:evidence:v2", v2Lines)

  v1 = .RuntimeArtifact~new("evidence.capability", "CAPABILITY", "1.0.0", "fixture:evidence:v1", "DemoCapability", v1Lines, "runtime.module/0.2")
  v2 = .RuntimeArtifact~new("evidence.capability", "CAPABILITY", "2.0.0", "fixture:evidence:v2", "DemoCapability", v2Lines, "runtime.module/0.2")

  staged1 = kernel~stage("prod", v1)
  self~mustOk(staged1, "stage v1")
  gen1 = staged1~value
  self~mustOk(kernel~activate("prod", v1~moduleId, gen1~generationId), "activate v1")
  acquired1 = kernel~acquire("prod", v1~moduleId)
  self~mustOk(acquired1, "acquire v1")
  lease1 = acquired1~value

  activeEvidence = lease1~executionEvidence
  self~assertEqual("runtime.execution/0.1", activeEvidence~evidenceApi, "execution evidence API")
  self~assertEqual("prod", activeEvidence~environment, "evidence environment")
  self~assertEqual(gen1~generationId, activeEvidence~generationId, "evidence generation")
  self~assertEqual(v1~moduleId, activeEvidence~moduleId, "evidence module")
  self~assertEqual(v1~artifactId, activeEvidence~artifactId, "evidence artifact")
  self~assertEqual("ACTIVE", activeEvidence~generationState, "initial active state")
  self~assertTrue(\activeEvidence~hasMethod("BEGINDRAIN"), "evidence has no lifecycle authority")

  payload = .directory~new
  payload["name"] = "evidence-value"
  envelope = lease1~envelope(payload, "fixture://evidence/value")
  self~assertTrue(envelope \== .nil, "runtime envelope produced")
  self~assertTrue(envelope~value == payload, "envelope retains exact rich value identity")
  self~assertEqual("fixture://evidence/value", envelope~locator, "envelope locator")
  self~assertEqual(gen1~generationId, envelope~runtimeEvidence~generationId, "envelope runtime generation")
  self~assertEqual("ACTIVE", envelope~runtimeEvidence~generationState, "envelope snapshots active state")
  self~assertTrue(envelope~isEvidenceBearing, "envelope evidence-bearing marker")

  staged2 = kernel~stage("prod", v2)
  self~mustOk(staged2, "stage v2")
  gen2 = staged2~value
  self~mustOk(kernel~activate("prod", v2~moduleId, gen2~generationId), "activate v2")

  drainingEvidence = lease1~executionEvidence
  self~assertEqual("DRAINING", drainingEvidence~generationState, "old lease observes draining state")
  self~assertEqual("ACTIVE", activeEvidence~generationState, "previous evidence snapshot remains active")
  self~assertEqual("ACTIVE", envelope~runtimeEvidence~generationState, "envelope evidence remains detached snapshot")

  acquired2 = kernel~acquire("prod", v2~moduleId)
  self~mustOk(acquired2, "acquire v2")
  lease2 = acquired2~value
  evidence2 = lease2~executionEvidence
  self~assertEqual("ACTIVE", evidence2~generationState, "new lease evidence active")
  self~assertEqual(gen2~generationId, evidence2~generationId, "new generation evidence")
  self~assertTrue(evidence2~provenance~at("generation_id") = gen2~generationId, "provenance generation id")
  self~assertTrue(evidence2~string~pos(gen2~generationId) > 0, "string includes generation")

  self~mustOk(lease1~release, "release old lease")
  self~mustOk(lease2~release, "release new lease")
  self~assertTrue(lease1~executionEvidence == .nil, "released lease exposes no new evidence")
  self~assertTrue(lease1~envelope(payload, "after-release") == .nil, "released lease cannot mint envelope")
  self~assertEqual(gen1~generationId, envelope~runtimeEvidence~generationId, "captured evidence survives lease release")
  self~assertTrue(envelope~value == payload, "captured rich value survives lease release")

  say "  assertions=" || assertions
  say "  old_generation=" || gen1~generationId
  say "  new_generation=" || gen2~generationId
  say "  locator=" || envelope~locator
  say "RUNTIME REGISTRY V0.9 EXECUTION EVIDENCE: OK"
  return 0

::method readLines private
  use arg path
  loaded = .RuntimeSourceLoader~readFile(path)
  self~mustOk(loaded, "read " || path)
  return loaded~value

::method mustOk private
  use arg object, label
  if \object~ok then raise syntax 88.900 array(label || ": " || object~code || " " || object~detail)
  return object

::method assertTrue private
  expose assertions
  use arg condition, label
  assertions = assertions + 1
  if \condition then raise syntax 88.900 array(label)
  return .true

::method assertEqual private
  expose assertions
  use arg expected, actual, label
  assertions = assertions + 1
  if expected \== actual then raise syntax 88.900 array(label || " expected=" || expected || " actual=" || actual)
  return .true

::requires "src/RuntimeRegistry.cls"
